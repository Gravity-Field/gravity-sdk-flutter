import 'dart:async';
import 'dart:io';

import 'loopback_http_overrides.dart';

/// Real loopback HTTP with a completion signal for widget-test teardown.
/// Server receipt/response.close does not mean Dio has consumed the response.
class DrainingHttpOverrides extends LoopbackHttpOverrides {
  final _pending = <Completer<void>, Uri>{};
  final completed = <Uri>[];

  List<Uri> get pending => List.unmodifiable(_pending.values);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _Client(super.createHttpClient(context), this);
}

// Only the HttpClient surface used by Dio is forwarded; unexpected operations
// fail instead of silently replacing real transport with a mock response.
class _Client implements HttpClient {
  _Client(this.delegate, this.tracker);
  final HttpClient delegate;
  final DrainingHttpOverrides tracker;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final finished = Completer<void>();
    tracker._pending[finished] = url;
    void complete() {
      if (finished.isCompleted) return;
      tracker._pending.remove(finished);
      tracker.completed.add(url);
      finished.complete();
    }

    try {
      return _Request(await delegate.openUrl(method, url), complete);
    } catch (_) {
      complete();
      rethrow;
    }
  }

  @override
  Duration? get connectionTimeout => delegate.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => delegate.connectionTimeout = value;
  @override
  set idleTimeout(Duration value) => delegate.idleTimeout = value;
  @override
  void close({bool force = false}) => delegate.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.delegate, this.complete);
  final HttpClientRequest delegate;
  final void Function() complete;

  @override
  HttpHeaders get headers => delegate.headers;
  @override
  set followRedirects(bool value) => delegate.followRedirects = value;
  @override
  set maxRedirects(int value) => delegate.maxRedirects = value;
  @override
  set persistentConnection(bool value) => delegate.persistentConnection = value;
  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      delegate.addStream(stream);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    delegate.abort(exception, stackTrace);
    complete();
  }

  @override
  Future<HttpClientResponse> close() async {
    try {
      return _Response(await delegate.close(), complete);
    } catch (_) {
      complete();
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.delegate, this.complete);
  final HttpClientResponse delegate;
  final void Function() complete;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => delegate.listen(
    onData,
    onError: onError,
    onDone: () {
      onDone?.call();
      complete();
    },
    cancelOnError: cancelOnError,
  );
  @override
  HttpHeaders get headers => delegate.headers;
  @override
  int get statusCode => delegate.statusCode;
  @override
  String get reasonPhrase => delegate.reasonPhrase;
  @override
  bool get isRedirect => delegate.isRedirect;
  @override
  List<RedirectInfo> get redirects => delegate.redirects;
  @override
  X509Certificate? get certificate => delegate.certificate;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
