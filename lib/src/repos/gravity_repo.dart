import '../data/api/api.dart';
import '../data/content_response.dart';

class GravityRepo {
  GravityRepo._();

  static final GravityRepo instance = GravityRepo._();

  final _api = Api();

  Future<void> sendEvent() {
    return Future.delayed(const Duration(seconds: 0));
  }

  Future<ContentResponse> getContent(String templateId) async {
    return _api.choose(templateId);
  }

  Future<void> triggerEventUrls(List<String> urls) async {
    for (final url in urls) {
      try {
        await _api.triggerEventUrl(url);
      } catch (e) {
        print(e);
      }
    }
  }
}
