import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

/// Manual QA for offline delivery: shows how many requests wait in the
/// outbox, sends a test event and forces a flush.
class OfflineQueuePanel extends StatefulWidget {
  const OfflineQueuePanel({super.key, required this.pageContext});

  final PageContext pageContext;

  @override
  State<OfflineQueuePanel> createState() => _OfflineQueuePanelState();
}

class _OfflineQueuePanelState extends State<OfflineQueuePanel> {
  int _pending = 0;
  int _sent = 0;
  String _status = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final pending = await GravitySDK.instance.pendingDeliveries;
    if (!mounted || pending == _pending) return;
    setState(() => _pending = pending);
  }

  Future<void> _sendEvent() async {
    _sent++;
    final startedAt = DateTime.now();
    setState(() => _status = 'событие #$_sent: отправка…');
    await GravitySDK.instance.triggerEventNoShow(
      pageContext: widget.pageContext,
      events: [
        CustomEvent(
          type: 'offline-qa-v1',
          name: 'Offline QA',
          customProps: {'n': '$_sent'},
        ),
      ],
    );
    await _refresh();
    if (!mounted) return;
    final took = DateTime.now().difference(startedAt).inMilliseconds;
    setState(
      () => _status = 'событие #$_sent: вызов завершён за $took мс, в очереди $_pending',
    );
  }

  Future<void> _flush() async {
    setState(() => _status = 'flushQueue()…');
    final startedAt = DateTime.now();
    await GravitySDK.instance.flushQueue();
    await _refresh();
    if (!mounted) return;
    final took = DateTime.now().difference(startedAt).inMilliseconds;
    setState(() => _status = 'flushQueue() завершён за $took мс, в очереди $_pending');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Офлайн-очередь: $_pending', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: _sendEvent, child: const Text('Событие')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: _flush, child: const Text('flushQueue()')),
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
