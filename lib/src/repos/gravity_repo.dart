import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';

import '../data/api/api.dart';
import '../data/api/content_ids_response.dart';
import '../data/api/content_response.dart';
import '../data/prefs/prefs.dart';
import '../models/external/content_settings.dart';
import '../models/external/options.dart';
import '../models/external/user.dart';

class GravityRepo {
  GravityRepo._();

  static final GravityRepo instance = GravityRepo._();

  final _api = Api();

  String? userIdCache;
  String? sessionIdCache;

  Future<CampaignIdsResponse> event({
    required List<TriggerEvent> events,
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.event(events, finalUser, pageContext, options);
    await _saveUserIfNeeded(customUser, response.user);
    return response;
  }

  Future<CampaignIdsResponse> visit({
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.visit(finalUser, pageContext, options);
    await _saveUserIfNeeded(customUser, response.user);
    return response;
  }

  Future<ContentResponse> getContentByCampaignId({
    required String campaignId,
    User? customUser,
    PageContext? pageContext,
    required Options options,
    required ContentSettings contentSetting,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.chooseByCampaignId(
      campaignId: campaignId,
      user: finalUser,
      context: pageContext,
      options: options,
      contentSettings: contentSetting,
    );
    await _saveUserIfNeeded(customUser, response.user);
    return response;
  }

  Future<ContentResponse> getContentBySelector({
    required String selector,
    User? customUser,
    PageContext? pageContext,
    required Options options,
    required ContentSettings contentSetting,
  }) async {
    final finalUser = await _determineUser(customUser);
    final response = await _api.chooseBySelector(
      selector: selector,
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
        //TODO: add logger
      }
    }
  }

  Future<User?> _determineUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    } else if (userIdCache != null && sessionIdCache != null) {
      return User(uid: userIdCache, ses: sessionIdCache);
    } else if (userIdCache == null && sessionIdCache != null) {
      final userIdFromPrefs = await Prefs.instance.getUserId();
      return User(uid: userIdFromPrefs, ses: sessionIdCache);
    } else {
      final userIdFromPrefs = await Prefs.instance.getUserId();
      return User(uid: userIdFromPrefs, ses: null);
    }
  }

  Future<void> _saveUserIfNeeded(User? customUser, User? contentResponseUser) async {
    if (customUser != null) {
      return;
    }

    final uid = contentResponseUser?.uid;
    final sec = contentResponseUser?.ses;

    if (uid != null) {
      await Prefs.instance.setUserId(uid);
      userIdCache = uid;
    }

    if (sec != null) {
      sessionIdCache = sec;
    }
  }
}
