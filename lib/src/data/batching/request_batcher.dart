import 'dart:async';

typedef BatchGroupKeyGenerator = String Function(Map<String, dynamic> data);

/// Combines multiple requests into one batch call.
/// Requests are grouped together within [batchDelay] and deduplicated.
/// [dedupKeyGenerator] defines full request identity: requests with an equal
/// dedup key share one pending request and one result. [groupKeyGenerator]
/// defines batch compatibility: pending requests with an equal group key are
/// handed to [batchExecutor] as one batch; different group keys are executed
/// in parallel batches. The dedup key must be at least as specific as the
/// group key, otherwise two deduped-together requests could belong to
/// different batches.
class RequestBatcher<T> {
  final Future<List<T>> Function(List<Map<String, dynamic>>) _batchExecutor;
  final Duration _batchDelay;
  final BatchGroupKeyGenerator? _dedupKeyGenerator;
  final BatchGroupKeyGenerator? _groupKeyGenerator;

  RequestBatcher({
    required Future<List<T>> Function(List<Map<String, dynamic>>) batchExecutor,
    Duration batchDelay = const Duration(milliseconds: 10),
    BatchGroupKeyGenerator? dedupKeyGenerator,
    BatchGroupKeyGenerator? groupKeyGenerator,
  }) : _batchExecutor = batchExecutor,
       _batchDelay = batchDelay,
       _dedupKeyGenerator = dedupKeyGenerator,
       _groupKeyGenerator = groupKeyGenerator;

  final List<BatchRequest<T>> _pendingRequests = [];
  final Map<String, BatchRequest<T>> _pendingRequestsMap = {};

  Timer? _batchTimer;

  bool _isExecuting = false;

  int get pendingCount => _pendingRequests.length;

  bool get isActive => _batchTimer != null || _isExecuting;

  Future<T> schedule(Map<String, dynamic> requestData) {
    final requestKey = _generateRequestKey(requestData);
    final existingRequest = _pendingRequestsMap[requestKey];

    if (existingRequest != null) {
      return existingRequest.completer.future;
    }

    final completer = Completer<T>();
    final request = BatchRequest<T>(data: requestData, completer: completer);

    _pendingRequests.add(request);
    _pendingRequestsMap[requestKey] = request;

    if (_batchTimer == null && !_isExecuting) {
      _scheduleBatchExecution();
    }

    return completer.future;
  }

  String _generateRequestKey(Map<String, dynamic> data) {
    final keyGenerator = _dedupKeyGenerator ?? _groupKeyGenerator;
    if (keyGenerator != null) {
      return keyGenerator(data);
    }

    final sortedKeys = data.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write('$key:${data[key]}|');
    }
    return buffer.toString();
  }

  void _scheduleBatchExecution() {
    _batchTimer = Timer(_batchDelay, () async {
      await _executeBatch();
    });
  }

  Future<void> _executeBatch() async {
    if (_isExecuting || _pendingRequests.isEmpty) {
      return;
    }

    _isExecuting = true;
    _batchTimer = null;

    final batch = List<BatchRequest<T>>.from(_pendingRequests);
    _pendingRequests.clear();
    _pendingRequestsMap.clear();

    try {
      if (_groupKeyGenerator != null) {
        await _executeGroupedBatch(batch);
      } else {
        await _executeFlatBatch(batch);
      }
    } finally {
      _isExecuting = false;

      if (_pendingRequests.isNotEmpty) {
        _scheduleBatchExecution();
      }
    }
  }

  Future<void> _executeGroupedBatch(List<BatchRequest<T>> batch) async {
    final groups = <String, List<BatchRequest<T>>>{};

    for (final request in batch) {
      final String groupKey;
      try {
        groupKey = _groupKeyGenerator!(request.data);
      } catch (error, stackTrace) {
        // A throwing key generator must fail only this caller, not the flush.
        if (!request.completer.isCompleted) {
          request.completer.completeError(error, stackTrace);
        }
        continue;
      }
      groups.putIfAbsent(groupKey, () => []).add(request);
    }

    await Future.wait(groups.values.map(_executeGroup));
  }

  Future<void> _executeGroup(List<BatchRequest<T>> groupRequests) async {
    try {
      final requestsData = groupRequests.map((r) => r.data).toList();
      final results = await _batchExecutor(requestsData);

      if (results.length == groupRequests.length) {
        for (var i = 0; i < groupRequests.length; i++) {
          if (!groupRequests[i].completer.isCompleted) {
            groupRequests[i].completer.complete(results[i]);
          }
        }
      } else {
        final error = Exception(
          'Batch response mismatch: sent ${groupRequests.length} requests, got ${results.length} responses',
        );
        for (final request in groupRequests) {
          if (!request.completer.isCompleted) {
            request.completer.completeError(error);
          }
        }
      }
    } catch (error, stackTrace) {
      for (final request in groupRequests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(error, stackTrace);
        }
      }
    }
  }

  Future<void> _executeFlatBatch(List<BatchRequest<T>> batch) async {
    try {
      final requestsData = batch.map((r) => r.data).toList();
      final results = await _batchExecutor(requestsData);

      if (results.length == batch.length) {
        for (var i = 0; i < batch.length; i++) {
          if (!batch[i].completer.isCompleted) {
            batch[i].completer.complete(results[i]);
          }
        }
      } else {
        final error = Exception(
          'Batch response mismatch: sent ${batch.length} requests, got ${results.length} responses',
        );
        for (final request in batch) {
          if (!request.completer.isCompleted) {
            request.completer.completeError(error);
          }
        }
      }
    } catch (error, stackTrace) {
      for (final request in batch) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(error, stackTrace);
        }
      }
    }
  }

  void clear() {
    _batchTimer?.cancel();
    _batchTimer = null;
    final aborted = List<BatchRequest<T>>.from(_pendingRequests);
    _pendingRequests.clear();
    _pendingRequestsMap.clear();
    final error = StateError('RequestBatcher was cleared before the request completed');
    for (final request in aborted) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(error);
      }
    }
    // _isExecuting stays set: the in-flight flush owns its snapshot, and
    // resetting the flag would let schedule() start a second flush over it.
  }
}

class BatchRequest<T> {
  final Map<String, dynamic> data;
  final Completer<T> completer;

  BatchRequest({required this.data, required this.completer});
}
