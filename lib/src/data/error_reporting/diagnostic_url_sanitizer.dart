/// URL redaction for diagnostic text. Tokens are scanned in disjoint ranges;
/// no match can consume arbitrary prose to find a later credential delimiter.
class DiagnosticUrlSanitizer {
  DiagnosticUrlSanitizer._();

  // Match fixed delimiters, then walk back over a disjoint scheme run.
  // A greedy scheme regex retried at every character can be quadratic.
  static final _markers = RegExp(
    r':(?://|(?:\\{1,2}/){2})|%(?:25){0,2}3a%(?:25){0,2}2f%(?:25){0,2}2f|(?:file|package|dart|content|data):(?!//|(?:\\{1,2}/){2}|%(?:25){0,2}2f)|(?:\\{1,2}/){2}|%(?:25){0,2}2f%(?:25){0,2}2f|(?<!:)//(?!/)',
    caseSensitive: false,
  );
  static final _rawMarkers = RegExp(r'://|(?<!:)//(?!/)');
  static final _encodedBoundary = RegExp(
    r'%(?:25){0,2}(?:2f|3a|3f|23|20|5c)',
    caseSensitive: false,
  );
  static final _authorization = RegExp(
    r'''(?<![a-z0-9_./+-])((?:proxy-|x-)?authorization)(?:["'])?[ \t]*[:=][^\r\n]*''',
    caseSensitive: false,
  );

  static Iterable<_UrlStart> _urlStarts(
    String text, {
    bool networkOnly = false,
  }) sync* {
    for (final marker in (networkOnly ? _rawMarkers : _markers).allMatches(
      text,
    )) {
      final prefix = marker[0]!;
      var begin = marker.start;
      if (prefix.startsWith(':') || prefix.toLowerCase().contains('3a')) {
        while (begin > 0 && _schemeCharacter(text.codeUnitAt(begin - 1))) {
          begin--;
        }
        if (begin > 0 && text.codeUnitAt(begin - 1) == 37) {
          final boundary = _encodedBoundary.matchAsPrefix(text, begin - 1);
          if (boundary != null && boundary.end <= marker.start) {
            begin = boundary.end;
          }
        }
        while (begin < marker.start && !_letter(text.codeUnitAt(begin))) {
          begin++;
        }
        if (begin == marker.start) continue;
      }
      yield _UrlStart(begin, marker.end, text.substring(begin, marker.end));
    }
  }

  static _UrlStart? _urlStartAt(String text, int offset) {
    if (offset >= text.length) return null;
    final direct = _markers.matchAsPrefix(text, offset);
    if (direct != null && !direct[0]!.startsWith(':')) {
      return _UrlStart(offset, direct.end, direct[0]!);
    }
    if (!_letter(text.codeUnitAt(offset))) return null;
    var end = offset;
    while (end < text.length && _schemeCharacter(text.codeUnitAt(end))) {
      end++;
    }
    final marker = _markers.matchAsPrefix(text, end);
    if (marker == null ||
        !(marker[0]!.startsWith(':') ||
            marker[0]!.toLowerCase().contains('3a'))) {
      return null;
    }
    return _UrlStart(offset, marker.end, text.substring(offset, marker.end));
  }

  static bool _letter(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  static bool _schemeCharacter(int c) =>
      _letter(c) || (c >= 48 && c <= 57) || c == 43 || c == 45 || c == 46;
  static final _nonNetwork = RegExp(
    r'^(?:file|package|dart|content|data):',
    caseSensitive: false,
  );

  /// Sanitize before the caller applies its output-length limit. A token
  /// crossing [inputBound] is omitted whole; scanning resumes after it so
  /// unrelated following text is not lost with an oversized URL.
  /// [onAuthorityScan] observes examined ranges for deterministic complexity
  /// checks; it does not change redaction or impose a wall-clock deadline.
  static String sanitize(
    String text, {
    int? inputBound,
    void Function(int)? onAuthorityScan,
  }) {
    final out = StringBuffer();
    var cursor = 0;
    for (final start in _urlStarts(text)) {
      if (start.start < cursor) continue;
      out.write(text.substring(cursor, start.start));
      final prefix = start.prefix;
      final nonNetwork = _nonNetwork.hasMatch(prefix);
      final escaped = prefix.contains(r'\/') || prefix.contains('%');
      var rawSpaceAt = -1;

      // Prefix-only schemes must not hide the URL immediately after them.
      // Advance once rather than recursively rescanning nested prefixes.
      if (nonNetwork &&
          prefix.endsWith(':') &&
          _urlStartAt(text, start.end) != null) {
        out.write(prefix);
        cursor = start.end;
        continue;
      }

      var end = _tokenEnd(text, start.end);
      if (!nonNetwork && !escaped) {
        final authorityEnd = _authorityEnd(text, start.end, end);
        final authority = text.substring(start.end, authorityEnd);
        // Only the immediately following word may finish malformed userinfo.
        // A path/query already ended the authority, or an ordinary endpoint
        // followed by prose, must never trigger this extension.
        if (authorityEnd == end &&
            end < text.length &&
            _credentialCandidate(authority)) {
          var next = end;
          while (next < text.length && _boundary(text.codeUnitAt(next))) {
            next++;
          }
          if (next < text.length && _urlStartAt(text, next) == null) {
            final nextEnd = _tokenEnd(text, next);
            final at = _findAt(text, next, nextEnd, onAuthorityScan);
            if (at >= next && at < nextEnd) {
              rawSpaceAt = at;
              end = nextEnd;
            }
          }
        }
      }

      if (inputBound == null ||
          start.start >= inputBound ||
          end <= inputBound) {
        final token = text.substring(start.start, end);
        if (rawSpaceAt >= 0) {
          out.write('$prefix[redacted]');
          out.write(_cutQuery(text.substring(rawSpaceAt + 1, end)));
        } else {
          out.write(_networkToken(token, onAuthorityScan));
        }
      }
      cursor = end;
    }
    out.write(text.substring(cursor));
    return out.toString().replaceAllMapped(
      _authorization,
      (match) => '${match[1]}: [redacted]',
    );
  }

  static String _networkToken(
    String token,
    void Function(int)? onAuthorityScan,
  ) {
    // At most three encoding layers are in contract. A later pass can find
    // a nested URL whose boundary was encoded by its enclosing URL.
    for (var i = 0; i < 3; i++) {
      final decoded = _normalizeEscapes(token);
      if (decoded == token) break;
      token = decoded;
    }
    final starts = _urlStarts(token, networkOnly: true).toList();
    if (starts.isEmpty) return _cutQuery(token);
    final leading = token.substring(0, starts.first.start);
    // A nested scheme inside a prefix's query/fragment is still secret data,
    // not a new endpoint. Do not emit the prefix values or the nested token.
    if (_queryIndex(leading) >= 0) return _cutQuery(leading);
    final out = StringBuffer()..write(leading);
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = i + 1 < starts.length ? starts[i + 1].start : token.length;
      final prefix = start.prefix;
      final authorityEnd = _authorityEnd(token, start.end, end);
      final authority = token.substring(start.end, authorityEnd);
      final at = authority.lastIndexOf('@');
      if (at < 0 && _credentialCandidate(authority)) {
        final laterAt = _findAt(token, authorityEnd, end, onAuthorityScan);
        if (laterAt >= 0 && laterAt < end) {
          out.write('$prefix[redacted]');
          break;
        }
        if (_hasPasswordPort(authority)) {
          out.write('$prefix[redacted]');
          continue;
        }
      }
      final host = authority.substring(at + 1);
      if (host.isEmpty && _nonNetwork.hasMatch(prefix)) {
        final path = token.substring(authorityEnd, end);
        out.write('$prefix${_cutQuery(path)}');
        if (_queryIndex(path) >= 0) break;
        continue;
      }
      if (host.isEmpty && prefix == '//' && start.end == end) {
        out.write(prefix);
        continue;
      }
      if (host.isEmpty) {
        out.write('$prefix[redacted]');
        continue;
      }
      final path = token.substring(authorityEnd, end);
      final query = _queryIndex(path);
      out.write('$prefix$host');
      out.write(query < 0 ? path : path.substring(0, query));
      // Query commas and embedded URLs are still query values, not tokens.
      if (query >= 0) break;
    }
    return out.toString();
  }

  static String _normalizeEscapes(String token) {
    final starts = _urlStarts(token).toList();
    if (!starts.any(
      (start) => start.prefix.contains(r'\/') || start.prefix.contains('%'),
    )) {
      return token;
    }
    final out = StringBuffer();
    var cursor = 0;
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = i + 1 < starts.length ? starts[i + 1].start : token.length;
      out.write(token.substring(cursor, start.start));
      final segment = token.substring(start.start, end);
      try {
        if (start.prefix.contains('%')) {
          var prefix = start.prefix;
          var decoded = segment;
          for (var level = 0; level < 3 && prefix.contains('%'); level++) {
            prefix = Uri.decodeComponent(prefix);
            decoded = Uri.decodeComponent(decoded);
          }
          out.write(decoded);
        } else {
          out.write(segment.replaceAll(RegExp(r'\\{1,2}/'), '/'));
        }
      } on FormatException {
        out.write('[redacted]');
      } on ArgumentError {
        // FormatException.toString can itself truncate an encoded URL.
        out.write('[redacted]');
      }
      cursor = end;
    }
    out.write(token.substring(cursor));
    return out.toString();
  }

  static bool _credentialCandidate(String authority) {
    if (!authority.contains(':') || authority.contains('@')) return false;
    // Numeric passwords and numeric ports are indistinguishable when @
    // follows later in the same token. Only a valid bracketed IPv6 host is
    // exempt from conservative credential redaction (contract R4a).
    if (!authority.startsWith('[')) return true;
    final uri = Uri.tryParse('http://$authority');
    return uri == null || !uri.hasAuthority || uri.host.isEmpty;
  }

  // A non-empty, non-numeric port without @ is userinfo under R10.
  // A trailing diagnostic colon after a numeric port stays (V24/V34).
  static bool _hasPasswordPort(String authority) {
    final end = authority.endsWith(':')
        ? authority.length - 1
        : authority.length;
    final hostEnd = authority.startsWith('[') ? authority.indexOf(']') + 1 : 0;
    final colon = authority.indexOf(':', hostEnd);
    if (colon < 0 || colon + 1 >= end) return false;
    for (var i = colon + 1; i < end; i++) {
      final c = authority.codeUnitAt(i);
      if (c < 48 || c > 57) return true;
    }
    return false;
  }

  static int _findAt(
    String text,
    int start,
    int end,
    void Function(int)? observer,
  ) {
    observer?.call(end - start);
    final relative = text.substring(start, end).indexOf('@');
    return relative < 0 ? -1 : start + relative;
  }

  static int _authorityEnd(String text, int start, int end) {
    var i = start;
    while (i < end) {
      final c = text.codeUnitAt(i);
      if (c == 47 || c == 63 || c == 35 || _boundary(c)) break;
      i++;
    }
    return i;
  }

  static int _tokenEnd(String text, int start) {
    var i = start;
    while (i < text.length && !_boundary(text.codeUnitAt(i))) {
      i++;
    }
    return i;
  }

  static int _queryIndex(String text) {
    final question = text.indexOf('?');
    final fragment = text.indexOf('#');
    if (question < 0) return fragment;
    if (fragment < 0) return question;
    return question < fragment ? question : fragment;
  }

  static String _cutQuery(String token) {
    final index = _queryIndex(token);
    return index < 0 ? token : token.substring(0, index);
  }

  static bool _boundary(int c) =>
      c == 34 ||
      c == 39 ||
      c == 60 ||
      c == 62 ||
      c <= 32 ||
      c == 0xa0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200a) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x202f ||
      c == 0x205f ||
      c == 0x3000 ||
      c == 0xfeff;
}

class _UrlStart {
  const _UrlStart(this.start, this.end, this.prefix);
  final int start;
  final int end;
  final String prefix;
}
