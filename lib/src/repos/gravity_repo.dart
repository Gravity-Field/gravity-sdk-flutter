import '../data/api/api.dart';
import '../data/content_response.dart';

class GravityRepo {

  final _api = Api();

  Future<void> sendEvent() {
    return Future.delayed(const Duration(seconds: 0));
  }

  Future<ContentResponse> getContent(String templateId) async {
    return _api.choose(templateId);
  }
}
