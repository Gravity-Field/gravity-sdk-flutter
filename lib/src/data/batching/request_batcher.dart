import 'dart:async';

/// Combines multiple requests into one batch call.
/// Requests are grouped together within [batchDelay].
class RequestBatcher<T> {
  final Future<List<T>> Function(List<Map<String, dynamic>>) _batchExecutor;
  final Duration _batchDelay;

  RequestBatcher({
    required Future<List<T>> Function(List<Map<String, dynamic>>) batchExecutor,
    Duration batchDelay = const Duration(milliseconds: 10),
  })  : _batchExecutor = batchExecutor,
        _batchDelay = batchDelay;

  final List<BatchRequest<T>> _pendingRequests = [];

  Timer? _batchTimer;

  bool _isExecuting = false;

  int get pendingCount => _pendingRequests.length;

  bool get isActive => _batchTimer != null || _isExecuting;

  Future<T> schedule(Map<String, dynamic> requestData) {
    final completer = Completer<T>();
    final request = BatchRequest<T>(data: requestData, completer: completer);

    _pendingRequests.add(request);

    if (_batchTimer == null && !_isExecuting) {
      _scheduleBatchExecution();
    }

    return completer.future;
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
    } finally {
      _isExecuting = false;

      if (_pendingRequests.isNotEmpty) {
        _scheduleBatchExecution();
      }
    }
  }

  void clear() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _pendingRequests.clear();
    _isExecuting = false;
  }
}

class BatchRequest<T> {
  final Map<String, dynamic> data;
  final Completer<T> completer;

  BatchRequest({required this.data, required this.completer});
}
