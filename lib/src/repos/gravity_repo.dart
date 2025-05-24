import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';

import '../data/api/api.dart';
import '../data/api/content_response.dart';
import '../data/prefs/prefs.dart';
import '../models/external/content_settings.dart';
import '../models/external/options.dart';
import '../models/external/user.dart';

class GravityRepo {
  GravityRepo._();

  static final GravityRepo instance = GravityRepo._();

  final _api = Api();
  final _prefs = Prefs();

  String? userIdCache;
  String? sessionIdCache;

  Future<void> event({
    required List<TriggerEvent> events,
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.event(events, finalUser, pageContext, options);
    await _saveUserIfNeeded(customUser, response.user);
  }

  Future<void> visit({
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.visit(finalUser, pageContext, options);
    await _saveUserIfNeeded(customUser, response.user);
  }

  Future<ContentResponse> getContent({
    String? templateId,
    User? customUser,
    PageContext? pageContext,
    required Options options,
    required ContentSettings contentSetting,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.choose(
      templateId: templateId,
      user: finalUser,
      context: pageContext,
      options: options,
      contentSettings: contentSetting,
    );
    await _saveUserIfNeeded(customUser, response.user);
    return response;
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

  Future<User?> _determineUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    } else if (userIdCache != null && sessionIdCache != null) {
      return User(uid: userIdCache, ses: sessionIdCache);
    } else {
      final userIdFromPrefs = await _prefs.getUserId();
      return User(uid: userIdFromPrefs, ses: null);
    }
  }

  Future<void> _saveUserIfNeeded(User? customUser, User? contentResponseUser) async {
    if (customUser != null) {
      return;
    }

    if (contentResponseUser != null) {
      await _prefs.setUserId(contentResponseUser.uid!);
      userIdCache = contentResponseUser.uid;
      sessionIdCache = contentResponseUser.ses;
    }
  }
}
