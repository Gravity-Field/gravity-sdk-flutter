/// Settings of the on-disk delivery queue that keeps `/event` requests when
/// the network is unavailable and re-sends them once it is back.
class OfflineQueueSettings {
  const OfflineQueueSettings({
    this.enabled = true,
    this.maxEntries = 500,
    this.maxAge = const Duration(days: 7),
  }) : assert(maxEntries > 0, 'maxEntries must be positive');

  /// When false optional offline events are neither queued nor drained.
  /// Their existing entries are kept until re-enabled. Modal WRIMP tracking
  /// always uses the durable engagement queue to protect frequency caps.
  final bool enabled;

  /// Maximum number of queued requests; the oldest is dropped on overflow.
  final int maxEntries;

  /// Optional queued requests older than this are dropped instead of sent.
  /// Mandatory modal WRIMP uses the cross-platform delivery TTL of seven days.
  final Duration maxAge;
}
