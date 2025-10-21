import 'dart:async';
import 'dart:io';

import 'package:gravity_sdk/src/data/batching/request_batcher.dart';
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

  late final _chooseBatcher = RequestBatcher<ContentResponse>(
    batchExecutor: _executeChooseBatch,
  );

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
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final requestData = {
      'campaignId': campaignId,
      'user': finalUser,
      'context': finalPageContext,
      'options': options,
      'contentSettings': contentSetting,
    };

    final response = await _chooseBatcher.schedule(requestData);

    await _sessionManager.saveUser(customUser, response.user);
    return response;
  }

  Future<ContentResponse> getContentBySelector({
    required String selector,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
  }) async {
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final requestData = {
      'selector': selector,
      'user': finalUser,
      'context': finalPageContext,
      'options': options,
      'contentSettings': contentSetting,
    };

    final response = await _chooseBatcher.schedule(requestData);

    await _sessionManager.saveUser(customUser, response.user);
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

    return await _sessionManager.getUser(null);
  }

  Future<List<ContentResponse>> _executeChooseBatch(List<Map<String, dynamic>> requests) async {
    if (requests.isEmpty) {
      return [];
    }

    final completer = _sessionManager.beginSessionInitialization();

    try {
      final responses = requests.length == 1
          ? [await _executeSingleChoose(requests.first)]
          : await _executeBatchedChoose(requests);

      _sessionManager.completeSessionInitialization(completer);
      return responses;
    } catch (error, stackTrace) {
      _sessionManager.failSessionInitialization(completer, error, stackTrace);
      rethrow;
    }
  }

  Future<ContentResponse> _executeSingleChoose(Map<String, dynamic> req) async {
    final user = req['user'] as User?;
    final context = req['context'] as PageContext;
    final options = req['options'] as Options;
    final contentSettings = req['contentSettings'] as ContentSettings;

    if (req.containsKey('selector')) {
      return await _api.chooseBySelector(
        selector: req['selector'] as String,
        user: user,
        context: context,
        options: options,
        contentSettings: contentSettings,
      );
    } else {
      return await _api.chooseByCampaignId(
        campaignId: req['campaignId'] as String,
        user: user,
        context: context,
        options: options,
        contentSettings: contentSettings,
      );
    }
  }

  Future<List<ContentResponse>> _executeBatchedChoose(List<Map<String, dynamic>> requests) async {
    final firstReq = requests.first;
    final user = firstReq['user'] as User?;
    final context = firstReq['context'] as PageContext;
    final options = firstReq['options'] as Options;

    final dataArray = requests.map((req) {
      final data = <String, dynamic>{
        'option': (req['contentSettings'] as ContentSettings).toJson(),
      };

      if (req.containsKey('selector')) {
        data['selector'] = req['selector'];
      } else {
        data['campaignId'] = req['campaignId'];
      }

      return data;
    }).toList();

    final batchResponse = await _api.chooseBatch(
      dataArray: dataArray,
      user: user,
      context: context,
      options: options,
    );

    return batchResponse.data.map((campaign) {
      return ContentResponse(
        user: batchResponse.user,
        data: [campaign],
      );
    }).toList();
  }
}
