import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/data/batching/request_batcher.dart';
import 'package:gravity_sdk/src/repos/choose_batch_keys.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/gravity_data_response.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/rt_rule.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/api/api.dart';
import '../data/error_reporting/error_helpers.dart';
import '../data/error_reporting/error_reporter.dart';
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

  /// Baked into [_chooseBatcher] on first use; override in tests before the
  /// first getContent* call to widen the merge window.
  @visibleForTesting
  static Duration chooseBatchDelay = const Duration(milliseconds: 10);

  /// Observes tracking batches without replacing the production transport.
  @visibleForTesting
  static void Function(List<String> urls)? triggerEventUrlsObserver;

  /// Replaces the whole [event] pipeline in tests. Invoked synchronously so
  /// side effects scheduled by the caller during a fire-and-forget dispatch
  /// happen inside that dispatch (the double-tap tests depend on this).
  @visibleForTesting
  static Future<CampaignIdsResponse> Function(
    List<TriggerEvent> events,
    PageContext pageContext,
  )?
  eventOverride;

  late final _chooseBatcher = RequestBatcher<ContentResponse>(
    batchExecutor: _executeChooseBatch,
    batchDelay: chooseBatchDelay,
    dedupKeyGenerator: chooseDedupKey,
    groupKeyGenerator: chooseGroupKey,
  );

  /// Choose requests currently waiting in the batch window.
  @visibleForTesting
  int get debugPendingChooseRequests => _chooseBatcher.pendingCount;

  Future<CampaignIdsResponse> event({
    required List<TriggerEvent> events,
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final override = eventOverride;
    if (override != null) return override(events, pageContext);

    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    var capturedGen = _sessionManager.generation;

    try {
      var user = await _getUserForRequest(customUser, sessionCompleter);
      // A reset while we awaited leaves both snapshots stale: re-snapshot,
      // generation first. The gated getUser is required — a direct Prefs
      // read could race the reset's queued uid removal — and safe: after a
      // reset the stored gate is no longer ours.
      while (customUser == null && capturedGen != _sessionManager.generation) {
        capturedGen = _sessionManager.generation;
        user = await _sessionManager.getUser(null);
      }
      final context = await _mixPageContextAttributes(pageContext);
      final response = await _api.event(events, user, context, options);

      await _finalizeSession(
        customUser,
        response.user,
        sessionCompleter,
        capturedGen,
      );
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      ErrorReporter.instance.report(
        message: error.toString(),
        level: errorLevel(error),
        section: 'GravityRepo.event',
        stacktrace: stackTrace.toString(),
        tags: {'category': categorizeError(error), 'endpoint': 'event'},
      );
      rethrow;
    }
  }

  Future<CampaignIdsResponse> visit({
    User? customUser,
    required PageContext pageContext,
    required Options options,
  }) async {
    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    var capturedGen = _sessionManager.generation;

    try {
      var user = await _getUserForRequest(customUser, sessionCompleter);
      // A reset while we awaited leaves both snapshots stale: re-snapshot,
      // generation first. The gated getUser is required — a direct Prefs
      // read could race the reset's queued uid removal — and safe: after a
      // reset the stored gate is no longer ours.
      while (customUser == null && capturedGen != _sessionManager.generation) {
        capturedGen = _sessionManager.generation;
        user = await _sessionManager.getUser(null);
      }
      final context = await _mixPageContextAttributes(pageContext);
      final response = await _api.visit(user, context, options);

      await _finalizeSession(
        customUser,
        response.user,
        sessionCompleter,
        capturedGen,
      );
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      ErrorReporter.instance.report(
        message: error.toString(),
        level: errorLevel(error),
        section: 'GravityRepo.visit',
        stacktrace: stackTrace.toString(),
        tags: {'category': categorizeError(error), 'endpoint': 'visit'},
      );
      rethrow;
    }
  }

  Future<ContentResponse> getContentByCampaignId({
    required String campaignId,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
    List<RtRule>? rules,
  }) async {
    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    final capturedGen = _sessionManager.generation;
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final requestData = {
      'campaignId': campaignId,
      'user': finalUser,
      'isSessionUser': customUser == null,
      'gen': capturedGen,
      'context': finalPageContext,
      'options': options,
      'contentSettings': contentSetting,
      if (rules != null) 'rules': rules,
    };

    final response = await _chooseBatcher.schedule(requestData);

    await _sessionManager.saveUser(customUser, response.user, capturedGen);
    return response;
  }

  Future<ContentResponse> getContentBySelector({
    required String selector,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
    List<RtRule>? rules,
  }) async {
    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    final capturedGen = _sessionManager.generation;
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final requestData = {
      'selector': selector,
      'user': finalUser,
      'isSessionUser': customUser == null,
      'gen': capturedGen,
      'context': finalPageContext,
      'options': options,
      'contentSettings': contentSetting,
      if (rules != null) 'rules': rules,
    };

    final response = await _chooseBatcher.schedule(requestData);

    await _sessionManager.saveUser(customUser, response.user, capturedGen);
    return response;
  }

  Future<ContentResponse> getContentByGroup({
    required String group,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
    List<RtRule>? rules,
  }) async {
    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    final capturedGen = _sessionManager.generation;
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final response = await _api.chooseByGroup(
      group: group,
      user: finalUser,
      context: finalPageContext,
      options: options,
      contentSettings: contentSetting,
      rules: rules,
    );

    await _sessionManager.saveUser(customUser, response.user, capturedGen);
    return response;
  }

  Future<void> triggerEventUrls(List<String> urls) async {
    triggerEventUrlsObserver?.call(List.unmodifiable(urls));

    for (final url in urls) {
      try {
        await _api.triggerEventUrl(url);
      } catch (e, stackTrace) {
        ErrorReporter.instance.report(
          message: e.toString(),
          level: 'warning',
          section: 'GravityRepo.triggerEventUrls',
          stacktrace: stackTrace.toString(),
          extra: {'url': url},
          tags: {'category': 'tracking'},
        );
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
    final isFirstRequest =
        customUser == null &&
        !_sessionManager.hasSession &&
        !_sessionManager.isInitializing;
    if (isFirstRequest) {
      return _sessionManager.beginSessionInitialization();
    }
    return null;
  }

  Future<User?> _getUserForRequest(
    User? customUser,
    Completer<void>? sessionCompleter,
  ) async {
    if (sessionCompleter != null) {
      if (customUser != null) {
        return customUser;
      }

      final cachedUid = _sessionManager.userId;
      final cachedSes = _sessionManager.sessionId;
      if (cachedUid != null && cachedSes != null) {
        return User(uid: cachedUid, ses: cachedSes);
      }

      final userIdFromPrefs = await Prefs.instance.getUserId();
      return User(uid: userIdFromPrefs, ses: cachedSes);
    } else {
      return await _ensureUser(customUser);
    }
  }

  Future<void> _finalizeSession(
    User? customUser,
    User? serverUser,
    Completer<void>? sessionCompleter,
    int capturedGeneration,
  ) async {
    await _sessionManager.saveUser(customUser, serverUser, capturedGeneration);

    if (sessionCompleter != null) {
      _sessionManager.completeSessionInitialization(sessionCompleter);
    }
  }

  void _handleSessionFailure(
    Completer<void>? sessionCompleter,
    Object error,
    StackTrace stackTrace,
  ) {
    if (sessionCompleter != null) {
      _sessionManager.failSessionInitialization(
        sessionCompleter,
        error,
        stackTrace,
      );
    }
  }

  Future<User?> _ensureUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    }

    return await _sessionManager.getUser(null);
  }

  Future<List<ContentResponse>> _executeChooseBatch(
    List<Map<String, dynamic>> requests,
  ) async {
    if (requests.isEmpty) {
      return [];
    }

    final isSessionUser = requests.any((r) => r['isSessionUser'] == true);

    // Park behind any in-flight session initialization instead of racing it
    // with another anonymous call; re-check after every wake-up — a failed
    // owner may have been replaced.
    User? adoptedUser;
    if (isSessionUser) {
      while (_sessionManager.sessionId == null &&
          _sessionManager.isInitializing) {
        try {
          await _sessionManager.getUser(null);
        } catch (_) {
          // Failed initializer: loop to park behind its successor, if any.
        }
      }
      adoptedUser = _sessionManager.getCachedUser();
    }

    // Each request's generation was captured with its user snapshot: a reset
    // inside the batch window must void the saves below. max() is safe — a
    // mixed-generation group implies an anonymous shared user, so what gets
    // adopted is a fresh identity, never a resurrected one. Computed before
    // the gate: a throw here must not leave the gate pending forever.
    final capturedGen = requests
        .map((r) => r['gen'] as int)
        .reduce((a, b) => a > b ? a : b);
    // Only a cold session-user batch owns the gate: warm and custom-user
    // batches must not stall or poison unrelated waiters.
    final completer = isSessionUser && _sessionManager.sessionId == null
        ? _sessionManager.beginSessionInitialization()
        : null;

    try {
      // The response echoes only selector/campaignId per campaign, so equal
      // identifiers cannot be demuxed from one call: the k-th occurrence of
      // an identifier goes to wave k, each wave being its own HTTP call.
      final seen = <String, int>{};
      final waves = <List<int>>[];
      for (var i = 0; i < requests.length; i++) {
        final id = chooseTypedIdentifier(requests[i]);
        final wave = seen[id] ?? 0;
        seen[id] = wave + 1;
        if (wave == waves.length) {
          waves.add(<int>[]);
        }
        waves[wave].add(i);
      }

      final results = List<ContentResponse?>.filled(requests.length, null);

      Future<void> runWave(List<int> indices, {User? userOverride}) async {
        final waveRequests = <Map<String, dynamic>>[
          for (final i in indices)
            if (userOverride == null)
              requests[i]
            else
              {...requests[i], 'user': userOverride},
        ];
        final waveResponses = waveRequests.length == 1
            ? [await _executeSingleChoose(waveRequests.first)]
            : await _executeBatchedChoose(waveRequests);
        for (var k = 0; k < indices.length; k++) {
          results[indices[k]] = waveResponses[k];
        }
      }

      if (waves.length > 1 &&
          isSessionUser &&
          _sessionManager.sessionId == null) {
        // Cold start: run wave 0 alone and adopt its session, so the other
        // waves don't each open their own.
        await runWave(waves.first, userOverride: adoptedUser);
        await _sessionManager.saveUser(
          null,
          results[waves.first.first]!.user,
          capturedGen,
        );
        if (completer != null) {
          // The session is usable now; don't hold parked waiters through the
          // remaining waves.
          _sessionManager.completeSessionInitialization(completer);
        }
        final sessionUser = _sessionManager.getCachedUser() ?? adoptedUser;
        await Future.wait([
          for (final indices in waves.skip(1))
            runWave(indices, userOverride: sessionUser),
        ]);
      } else {
        await Future.wait([
          for (final indices in waves)
            runWave(indices, userOverride: adoptedUser),
        ]);
      }

      if (isSessionUser) {
        // Adopt before releasing the gate, or a woken waiter would still see
        // no session and fire another anonymous call.
        await _sessionManager.saveUser(null, results.first!.user, capturedGen);
      }
      if (completer != null) {
        _sessionManager.completeSessionInitialization(completer);
      }
      return [for (final result in results) result!];
    } catch (error, stackTrace) {
      if (completer != null) {
        _sessionManager.failSessionInitialization(completer, error, stackTrace);
      }
      ErrorReporter.instance.report(
        message: error.toString(),
        level: errorLevel(error),
        section: 'GravityRepo._executeChooseBatch',
        stacktrace: stackTrace.toString(),
        tags: {'category': categorizeError(error), 'endpoint': 'choose'},
      );
      rethrow;
    }
  }

  Future<ContentResponse> _executeSingleChoose(Map<String, dynamic> req) async {
    final user = req['user'] as User?;
    final context = req['context'] as PageContext;
    final options = req['options'] as Options;
    final contentSettings = req['contentSettings'] as ContentSettings;
    final rules = req['rules'] as List<RtRule>?;

    if (req.containsKey('selector')) {
      return await _api.chooseBySelector(
        selector: req['selector'] as String,
        user: user,
        context: context,
        options: options,
        contentSettings: contentSettings,
        rules: rules,
      );
    } else {
      return await _api.chooseByCampaignId(
        campaignId: req['campaignId'] as String,
        user: user,
        context: context,
        options: options,
        contentSettings: contentSettings,
        rules: rules,
      );
    }
  }

  Future<List<ContentResponse>> _executeBatchedChoose(
    List<Map<String, dynamic>> requests,
  ) async {
    final firstReq = requests.first;
    assert(
      requests.every((r) => chooseGroupKey(r) == chooseGroupKey(firstReq)),
      'Merged /choose requests must share one envelope (user, ctx, options)',
    );
    final user = firstReq['user'] as User?;
    final options = firstReq['options'] as Options;
    final context = firstReq['context'] as PageContext;

    final dataArray = requests.map((req) {
      final data = <String, dynamic>{
        'option': (req['contentSettings'] as ContentSettings).toJson(),
      };

      if (req.containsKey('selector')) {
        data['selector'] = req['selector'];
      } else {
        data['campaignId'] = req['campaignId'];
      }

      final rules = req['rules'] as List<RtRule>?;
      if (rules != null) {
        data['rules'] = rules.map((r) => r.toJson()).toList();
      }

      return data;
    }).toList();

    final batchResponse = await _api.chooseBatch(
      dataArray: dataArray,
      user: user,
      context: context,
      options: options,
    );

    final campaignsBySelector = <String, dynamic>{};
    // For campaignId demux, direct answers (no selector echoed) take
    // precedence; selector-echoed campaigns are only a fallback. Every
    // payload entry is indexed — the requested id is not necessarily first.
    final campaignsByCampaignId = <String, dynamic>{};
    final fallbackByCampaignId = <String, dynamic>{};

    for (final campaign in batchResponse.data) {
      if (campaign.selector != null) {
        campaignsBySelector.putIfAbsent(campaign.selector!, () => campaign);
        for (final variation in campaign.payload) {
          fallbackByCampaignId.putIfAbsent(
            variation.campaignId,
            () => campaign,
          );
        }
      } else {
        for (final variation in campaign.payload) {
          campaignsByCampaignId.putIfAbsent(
            variation.campaignId,
            () => campaign,
          );
        }
      }
    }

    final results = <ContentResponse>[];
    for (final req in requests) {
      final selector = req['selector'] as String?;
      final campaignId = req['campaignId'] as String?;

      final matchingCampaign = selector != null
          ? campaignsBySelector[selector]
          : campaignId != null
          ? campaignsByCampaignId[campaignId] ??
                fallbackByCampaignId[campaignId]
          : null;

      if (matchingCampaign != null) {
        results.add(
          ContentResponse(user: batchResponse.user, data: [matchingCampaign]),
        );
      } else {
        results.add(ContentResponse(user: batchResponse.user, data: const []));
      }
    }

    return results;
  }

  Future<GravityDataResponse<ContentResponse>> getContentBySelectorWithDetails({
    required String selector,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
    List<RtRule>? rules,
  }) async {
    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    final capturedGen = _sessionManager.generation;
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final (content, json) = await _api.chooseBySelectorWithDetails(
      selector: selector,
      user: finalUser,
      context: finalPageContext,
      options: options,
      contentSettings: contentSetting,
      rules: rules,
    );

    await _sessionManager.saveUser(customUser, content.user, capturedGen);

    return GravityDataResponse(data: content, json: json);
  }

  Future<GravityDataResponse<ContentResponse>>
  getContentByCampaignIdWithDetails({
    required String campaignId,
    User? customUser,
    required PageContext pageContext,
    required Options options,
    required ContentSettings contentSetting,
    List<RtRule>? rules,
  }) async {
    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    final capturedGen = _sessionManager.generation;
    final finalUser = await _ensureUser(customUser);
    final finalPageContext = await _mixPageContextAttributes(pageContext);

    final (content, json) = await _api.chooseByCampaignIdWithDetails(
      campaignId: campaignId,
      user: finalUser,
      context: finalPageContext,
      options: options,
      contentSettings: contentSetting,
      rules: rules,
    );

    await _sessionManager.saveUser(customUser, content.user, capturedGen);

    return GravityDataResponse(data: content, json: json);
  }
}
