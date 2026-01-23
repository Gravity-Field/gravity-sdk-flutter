import 'dart:async';

typedef BatchGroupKeyGenerator = String Function(Map<String, dynamic> data);

/// Combines multiple requests into one batch call.
/// Requests are grouped together within [batchDelay] and deduplicated.
/// When [groupKeyGenerator] is provided, requests are grouped by compatibility -
/// requests with different group keys are executed in parallel batches.
class RequestBatcher<T> {
  final Future<List<T>> Function(List<Map<String, dynamic>>) _batchExecutor;
  final Duration _batchDelay;
  final BatchGroupKeyGenerator? _groupKeyGenerator;

  RequestBatcher({
    required Future<List<T>> Function(List<Map<String, dynamic>>) batchExecutor,
    Duration batchDelay = const Duration(milliseconds: 10),
    BatchGroupKeyGenerator? groupKeyGenerator,
  }) : _batchExecutor = batchExecutor,
       _batchDelay = batchDelay,
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
    final keyGenerator = _groupKeyGenerator;
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
      final groupKey = _groupKeyGenerator!(request.data);
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
    _pendingRequests.clear();
    _pendingRequestsMap.clear();
    _isExecuting = false;
  }
}

class BatchRequest<T> {
  final Map<String, dynamic> data;
  final Completer<T> completer;

  BatchRequest({required this.data, required this.completer});
}
