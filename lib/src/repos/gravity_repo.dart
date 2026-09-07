import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/gravity_sdk.dart' show GravitySDK;
import 'package:gravity_sdk/src/data/api/retry_class.dart';
import 'package:gravity_sdk/src/data/batching/request_batcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/repos/choose_batch_keys.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/gravity_data_response.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/rt_rule.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

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
  GravityRepo._() {
    Api.onRequestSucceeded = () => outbox.onRequestSucceeded();
  }

  static final GravityRepo instance = GravityRepo._();

  final _api = Api();
  final _sessionManager = SessionManager.instance;

  /// Deferred delivery of requests that failed for network reasons.
  late final OutboxDispatcher outbox = OutboxDispatcher(
    store: OutboxStore(),
    sender: sendOutboxEntry,
    settings: () => GravitySDK.instance.offlineQueue,
  );

  /// Sends one persisted entry. Responses are used only as a success signal:
  /// campaigns are ignored.
  Future<void> sendOutboxEntry(OutboxEntry entry) async {
    switch (entry.kind) {
      case OutboxKind.event:
        await _sendDeferredEvent(entry.body!);
      case OutboxKind.engagement:
        await _api.triggerEventUrl(entry.url!, deferred: true);
      case OutboxKind.visit:
        throw UnsupportedError('visit entries are not delivered by this version');
    }
  }

  /// Delivers a frozen `/event` body.
  ///
  /// A body without identity was queued before any session existed. It takes
  /// the same session path as an online request: it waits for an
  /// initialisation already in flight, or performs it itself and keeps the
  /// uid the server assigns. Sending it anonymously instead would make the
  /// server mint a throwaway user for the event, while the app's next request
  /// would be given another one.
  Future<void> _sendDeferredEvent(Map<String, dynamic> body) async {
    if (_hasIdentity(body['user'])) {
      await _api.postEventBody(body, deferred: true);
      return;
    }

    final sessionCompleter = _startSessionInitializationIfFirst(null);
    var capturedGen = _sessionManager.generation;
    try {
      var user = await _getUserForRequest(null, sessionCompleter);
      while (capturedGen != _sessionManager.generation) {
        capturedGen = _sessionManager.generation;
        user = await _sessionManager.getUser(null);
      }
      final response = await _api.postEventBody(_withIdentity(body, user), deferred: true);
      await _finalizeSession(null, response.user, sessionCompleter, capturedGen);
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);
      rethrow;
    }
  }

  static bool _hasIdentity(Object? user) => user is Map && (user['uid'] != null || user['custom'] != null);

  static Map<String, dynamic> _withIdentity(Map<String, dynamic> body, User? user) {
    final uid = user?.uid;
    if (uid == null) return body;
    final existing = body['user'];
    final ses = user?.ses;
    return {
      ...body,
      'user': {
        ...(existing is Map<String, dynamic> ? existing : const <String, dynamic>{}),
        'uid': uid,
        if (ses != null) 'ses': ses,
      },
    };
  }

  static OutboxEntry _eventEntry(Map<String, dynamic> body, DateTime raisedAt) => OutboxEntry(
    id: const Uuid().v4(),
    kind: OutboxKind.event,
    createdAt: raisedAt.toUtc(),
    body: body,
  );

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

    // The event happened now; everything below may wait for the session.
    final raisedAt = Clock.now();
    final sessionCompleter = _startSessionInitializationIfFirst(customUser);

    // Generation before the user snapshot: if a reset lands between the two,
    // the stale user must carry a stale generation so saveUser skips it.
    var capturedGen = _sessionManager.generation;

    Map<String, dynamic>? frozen;
    OutboxEntry? reserved;
    // Until our own request is on the wire, any failure is someone else's
    // (the session request we waited for, storage) and says nothing about
    // this event: it must stay queued rather than be dropped as rejected.
    var sent = false;
    // Queue generation this call belongs to; a clearQueue() bumps it.
    final epoch = outbox.epoch;
    try {
      // Everything the body needs, with the identity known right now, then
      // disk first: a process killed while this call waits for a session
      // another request is creating, or while its own request hangs, must
      // not lose the event. The drain steps over the entry until we let go.
      final known = customUser ?? _sessionManager.getCachedUser();
      final context = await _mixPageContextAttributes(pageContext);
      frozen = await _api.buildEventBody(events, known, context, options, now: raisedAt);
      final entry = _eventEntry(frozen, raisedAt);
      if (await outbox.reserve(entry)) reserved = entry;

      var user = await _getUserForRequest(customUser, sessionCompleter);
      // A reset while we awaited leaves both snapshots stale: re-snapshot,
      // generation first. The gated getUser is required — a direct Prefs
      // read could race the reset's queued uid removal — and safe: after a
      // reset the stored gate is no longer ours.
      while (customUser == null && capturedGen != _sessionManager.generation) {
        capturedGen = _sessionManager.generation;
        user = await _sessionManager.getUser(null);
      }
      // clearQueue() ran after this call began: the event was part of what
      // the caller asked to drop, whether its write landed before the clear
      // (already gone) or after it (must go now, or the drain would send it).
      if (reserved != null && outbox.epoch != epoch) {
        await outbox.discard(reserved.id);
        return const CampaignIdsResponse(user: User());
      }

      final body = _withUser(frozen, user);
      // The event belongs to the user it was raised for: freeze that identity
      // before sending, or a replay after a logout would attribute it to
      // whoever is signed in by then.
      if (reserved != null && !_sameIdentity(known, user)) {
        reserved = reserved.copyWith(body: body);
        await outbox.update(reserved);
      }

      sent = true;
      final response = await _api.postEventBody(body);

      await _finalizeSession(
        customUser,
        response.user,
        sessionCompleter,
        capturedGen,
      );
      if (reserved != null) await outbox.complete(reserved.id);
      return response;
    } catch (error, stackTrace) {
      _handleSessionFailure(sessionCompleter, error, stackTrace);

      // A queue cleared meanwhile takes this event with it: nothing that
      // began before the clear may put itself back.
      final cleared = outbox.epoch != epoch;
      final keep = !cleared && (!sent || classifyError(error) != RetryClass.permanent);
      var queued = false;
      if (keep && reserved != null) {
        // Already on disk: it stays there even if the queue was switched off
        // meanwhile (disabled only stops sending, it never drops entries).
        outbox.release(reserved.id);
        queued = true;
      } else if (keep && frozen != null && GravitySDK.instance.offlineQueue.enabled) {
        // Built but never reserved (storage refused, or the queue was off at
        // the time): one more try to get it on disk.
        queued = outbox.epoch == epoch && await outbox.enqueue(_eventEntry(frozen, raisedAt));
      } else if (reserved != null) {
        await outbox.discard(reserved.id);
      }

      // 'queued' is reported only once the entry is actually on disk, so it
      // never claims a delivery that was never scheduled.
      ErrorReporter.instance.report(
        message: error.toString(),
        level: queued ? 'warning' : errorLevel(error),
        section: 'GravityRepo.event',
        stacktrace: stackTrace.toString(),
        tags: {
          'category': categorizeError(error),
          'endpoint': 'event',
          'outcome': queued ? 'queued' : 'failed',
        },
      );
      if (!queued) rethrow;
      return const CampaignIdsResponse(user: User());
    }
  }

  /// The frozen body with the session identity resolved for this send.
  static Map<String, dynamic> _withUser(Map<String, dynamic> frozen, User? user) => {
    ...frozen,
    'user': user?.toJson() ?? <String, dynamic>{},
  };

  static bool _sameIdentity(User? a, User? b) =>
      a?.uid == b?.uid && a?.ses == b?.ses && a?.custom == b?.custom;

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
    attributes['app_platform'] = Platform.isIOS ? 'iOS' : Platform.operatingSystem;

    return pageContext.copyWith(attributes: attributes);
  }

  Completer<void>? _startSessionInitializationIfFirst(User? customUser) {
    final isFirstRequest = customUser == null && !_sessionManager.hasSession && !_sessionManager.isInitializing;
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
      while (_sessionManager.sessionId == null && _sessionManager.isInitializing) {
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
    final capturedGen = requests.map((r) => r['gen'] as int).reduce((a, b) => a > b ? a : b);
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
            if (userOverride == null) requests[i] else {...requests[i], 'user': userOverride},
        ];
        final waveResponses = waveRequests.length == 1
            ? [await _executeSingleChoose(waveRequests.first)]
            : await _executeBatchedChoose(waveRequests);
        for (var k = 0; k < indices.length; k++) {
          results[indices[k]] = waveResponses[k];
        }
      }

      if (waves.length > 1 && isSessionUser && _sessionManager.sessionId == null) {
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
          for (final indices in waves.skip(1)) runWave(indices, userOverride: sessionUser),
        ]);
      } else {
        await Future.wait([
          for (final indices in waves) runWave(indices, userOverride: adoptedUser),
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
          ? campaignsByCampaignId[campaignId] ?? fallbackByCampaignId[campaignId]
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

  Future<GravityDataResponse<ContentResponse>> getContentByCampaignIdWithDetails({
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
