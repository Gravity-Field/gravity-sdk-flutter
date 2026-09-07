/// Settings of the on-disk delivery queue that keeps `/event` requests when
/// the network is unavailable and re-sends them once it is back.
class OfflineQueueSettings {
  const OfflineQueueSettings({
    this.enabled = true,
    this.maxEntries = 500,
    this.maxAge = const Duration(days: 7),
  }) : assert(maxEntries > 0, 'maxEntries must be positive');

  /// When false nothing is queued and nothing is sent from the queue.
  /// Entries already on disk are kept and delivered once re-enabled.
  final bool enabled;

  /// Maximum number of queued requests; the oldest is dropped on overflow.
  final int maxEntries;

  /// Queued requests older than this are dropped instead of being sent.
  final Duration maxAge;
}
