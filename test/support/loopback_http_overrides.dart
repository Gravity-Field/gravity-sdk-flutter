import 'dart:io';

class LoopbackHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) {
      if (const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
        return 'DIRECT';
      }
      throw StateError('Unit tests allow only loopback HTTP fixtures');
    };
    return client;
  }
}
