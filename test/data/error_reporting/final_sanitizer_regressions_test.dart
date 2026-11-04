import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/diagnostic_url_sanitizer.dart';

void main() {
  test(
    'flu-41 authority searches stay linear through one megabyte of host-port prose',
    () {
      const chunk = 'https://a:1 b ';
      for (final size in [16384, 1024 * 1024]) {
        final input = chunk * (size ~/ chunk.length);
        var scanned = 0;
        final output = DiagnosticUrlSanitizer.sanitize(
          input,
          inputBound: 10000,
          onAuthorityScan: (range) => scanned += range,
        );
        expect(
          scanned,
          lessThanOrEqualTo(input.length * 2),
          reason: 'count examined authority-search ranges, not machine time',
        );
        expect(
          output.length,
          inInclusiveRange(input.length - chunk.length, input.length),
        );
        expect(output, startsWith(chunk));
        expect(output, endsWith(chunk));
      }
    },
  );
  test('flu-41 long scheme-like prose and nested prefixes remain intact', () {
    final prose = 'a1' * (512 * 1024);
    expect(DiagnosticUrlSanitizer.sanitize(prose), prose);
    final prefixes = 'content:' * 16384;
    expect(
      DiagnosticUrlSanitizer.sanitize('${prefixes}https://u:SECRET@host/p'),
      '${prefixes}https://host/p',
    );
  });
  for (final prefix in ['.', '-', '+', '1', 'status=503']) {
    test('flu-40 keeps endpoint after $prefix and removes credentials', () {
      final output = DiagnosticUrlSanitizer.sanitize(
        '${prefix}https://user:SECRET@host/p',
      );
      expect(output, '${prefix}https://host/p');
      expect(output, isNot(contains('SECRET')));
    });
  }
  for (final input in [
    'text // comment with : colon',
    'bare //',
    '// next words',
  ]) {
    test('flu-46 preserves a bare prose slash token: $input', () {
      expect(DiagnosticUrlSanitizer.sanitize(input), input);
    });
  }
  for (final input in [
    'Authorization: Bearer ABC123',
    'authorization=bearer ABC123',
    'AUTHORIZATION: Basic ABC123',
    'before Authorization: Bearer ABC123 after',
  ]) {
    test('V37 removes free-text Authorization credentials: $input', () {
      final output = DiagnosticUrlSanitizer.sanitize(input);
      expect(output, isNot(contains('ABC123')));
      final name = RegExp(
        'authorization',
        caseSensitive: false,
      ).firstMatch(input)![0]!;
      expect(output, contains('$name: [redacted]'));
      expect(
        DiagnosticUrlSanitizer.sanitize(output),
        output,
        reason: 'idempotent redaction',
      );
    });
  }
}
