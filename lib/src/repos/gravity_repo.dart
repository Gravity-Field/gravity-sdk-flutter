import 'package:gravity_sdk/src/models/external/page_context.dart';

import '../data/api/api.dart';
import '../data/content_response.dart';
import '../models/external/user.dart';

class GravityRepo {
  GravityRepo._();

  static final GravityRepo instance = GravityRepo._();

  final _api = Api();

  Future<void> event(String event, User? user, PageContext pageContext) async {
    return _api.event(user, pageContext);
  }

  Future<void> visit(User? user, PageContext pageContext) async {
    return _api.visit(user, pageContext);
  }

  Future<ContentResponse> getContent(String templateId) async {
    return _api.choose(templateId);
  }

  Future<void> triggerEventUrls(List<String> urls) async {
    for (final url in urls) {
      try {
        _api.triggerEventUrl(url);
      } catch (e) {
        print(e);
      }
    }
  }
}
