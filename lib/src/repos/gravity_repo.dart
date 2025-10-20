import 'dart:async';
import 'dart:io';

import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/api/api.dart';
import '../data/api/content_ids_response.dart';
import '../data/api/content_response.dart';
import '../models/external/content_settings.dart';
import '../models/external/options.dart';
import '../models/external/user.dart';
import '../version.dart';

class GravityRepo {
  GravityRepo._();

  static final GravityRepo instance = GravityRepo._();

  final _api = Api();
  final _sessionManager = SessionManager.instance;

  Future<CampaignIdsResponse> event({
    required List<TriggerEvent> events,
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    try {
      final user = await _getUserForRequest(customUser, sessionCompleter);
      final context = await _mixPageContextAttributes(pageContext);
      final response = await _api.event(events, user, context, options);

      await _finalizeSession(customUser, response.user, sessionCompleter);
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      rethrow;
    }
  }

  Future<CampaignIdsResponse> visit({
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    try {
      final user = await _getUserForRequest(customUser, sessionCompleter);
      final context = await _mixPageContextAttributes(pageContext);
      final response = await _api.visit(user, context, options);

      await _finalizeSession(customUser, response.user, sessionCompleter);
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      rethrow;
    }
  }

  Future<ContentResponse> getContentByCampaignId({
    required String campaignId,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
  }) async {
    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    try {
      final user = await _getUserForRequest(customUser, sessionCompleter);
      final context = await _mixPageContextAttributes(pageContext);

      final response = await _api.chooseByCampaignId(
        campaignId: campaignId,
        user: user,
        context: context,
        options: options,
        contentSettings: contentSetting,
      );

      await _finalizeSession(customUser, response.user, sessionCompleter);
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      rethrow;
    }
  }

  Future<ContentResponse> getContentBySelector({
    required String selector,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
  }) async {
    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    try {
      final user = await _getUserForRequest(customUser, sessionCompleter);
      final context = await _mixPageContextAttributes(pageContext);

      final response = await _api.chooseBySelector(
        selector: selector,
        user: user,
        context: context,
        options: options,
        contentSettings: contentSetting,
      );

      await _finalizeSession(customUser, response.user, sessionCompleter);
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      rethrow;
    }
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

  Future<PageContext> _mixPageContextAttributes(PageContext pageContext) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    final attributes = Map<String, Object>.from(pageContext.attributes);

    attributes['app_version'] = '$version+$buildNumber';
    attributes['sdk_version'] = packageVersion;
    attributes['app_platform'] = Platform.operatingSystem;

    return pageContext.copyWith(attributes: attributes);
  }

  Completer<void>? _startSessionInitializationIfFirst(User? customUser) {
    final isFirstRequest = customUser == null && !_sessionManager.hasSession && !_sessionManager.isInitializing;
    if (isFirstRequest) {
      return _sessionManager.beginSessionInitialization();
    }
    return null;
  }

  Future<User?> _getUserForRequest(User? customUser, Completer<void>? sessionCompleter) async {
    if (sessionCompleter != null) {
      return customUser ?? _sessionManager.getCachedUser();
    } else {
      return await _ensureUser(customUser);
    }
  }

  Future<void> _finalizeSession(User? customUser, User? serverUser, Completer<void>? sessionCompleter) async {
    await _sessionManager.saveUser(customUser, serverUser);

    if (sessionCompleter != null) {
      _sessionManager.completeSessionInitialization(sessionCompleter);
    }
  }

  void _handleSessionFailure(Completer<void>? sessionCompleter, Object error, StackTrace stackTrace) {
    if (sessionCompleter != null) {
      _sessionManager.failSessionInitialization(sessionCompleter, error, stackTrace);
    }
  }

  Future<User?> _ensureUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    }

    final user = await _sessionManager.getUser(null);
    return user;
  }
}
