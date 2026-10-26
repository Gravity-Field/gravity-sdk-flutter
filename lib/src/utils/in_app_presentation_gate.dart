import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:uuid/uuid.dart';

class PresentationRequest {
  const PresentationRequest(this.sequence, this.generation, this.screen);
  final int sequence;
  final int generation;
  /// Null for anchors, whose relevance comes from their host route.
  final int? screen;
}

class PresentationReservation extends PresentationRequest {
  PresentationReservation(
    super.sequence,
    super.generation,
    super.screen,
    this.scope,
    this.campaignId,
    this.expiresAt,
  );
  final String scope;
  final String campaignId;
  DateTime expiresAt;
  final String token = const Uuid().v4();
}

/// The bridge from /choose to durable WRIMP delivery. It is not a frequency cap.
/// All decisions happen synchronously on Flutter's UI isolate.
class InAppPresentationGate {
  static final instance = InAppPresentationGate();

  /// Emergency in-memory bridge for an unpersisted/missing event.
  static const protectionTimeout = Duration(seconds: 60);

  /// Product policy shared across SDKs; the outbox timestamp survives restart.
  static const pendingDeliveryProtection = Duration(hours: 24);

  /// Anchors use route relevance instead of the automatic screen counter.
  /// They neither advance that counter nor become stale when it advances.
  PresentationRequest currentRequest(int generation) {
    _updateGeneration(generation);
    return PresentationRequest(++_sequence, generation, null);
  }

  void _updateGeneration(int generation) {
    if (_generation == generation) return;
    _generation = generation;
    _pending.removeWhere((_, reservation) => !_visible.contains(reservation));
    _location = null;
  }

  InAppPresentationGate({DateTime Function()? now}) : _now = now ?? (() => Clock.now());
  final DateTime Function() _now;
  int _sequence = 0;
  int _generation = -1;
  int _screen = 0;
  String? _location;
  final _pending = <(String, String), PresentationReservation>{};
  final _visible = <PresentationReservation>{};
  final _confirmedThrough = <(String, String), int>{};

  PresentationRequest beginRequest(
    String location,
    int generation, {
    bool newScreen = false,
  }) {
    _updateGeneration(generation);
    if (newScreen || location != _location) {
      _screen++;
      _location = location;
      // Visible deliveries are protected by the outbox, independent of UI.
      _pending.removeWhere(
        (_, reservation) =>
            reservation.screen != null && !_visible.contains(reservation),
      );
    }
    return PresentationRequest(++_sequence, generation, _screen);
  }

  bool isCurrent(PresentationRequest request) =>
      request.generation == _generation &&
      (request.screen == null || request.screen == _screen);

  PresentationReservation? reserve(
    String scope,
    String campaignId,
    PresentationRequest request, {
    bool deliveryPending = false,
  }) {
    _pending.removeWhere((_, value) => !value.expiresAt.isAfter(_now()));
    _visible.removeWhere((value) => !_pending.containsValue(value));
    final key = (scope, campaignId);
    if (!isCurrent(request) ||
        deliveryPending ||
        _pending.containsKey(key) ||
        request.sequence <= (_confirmedThrough[key] ?? 0)) {
      return null;
    }
    final reservation = PresentationReservation(
      ++_sequence,
      _generation,
      request.screen,
      scope,
      campaignId,
      _now().add(protectionTimeout),
    );
    _pending[key] = reservation;
    return reservation;
  }

  bool owns(PresentationReservation reservation) =>
      isCurrent(reservation) &&
      identical(
        _pending[(reservation.scope, reservation.campaignId)],
        reservation,
      );

  void visible(PresentationReservation reservation) {
    reservation.expiresAt = _now().add(protectionTimeout);
    _visible.add(reservation);
  }

  void rejected(String scope, String campaignId, String? token) {
    final reservation = _pending[(scope, campaignId)];
    if (reservation != null && reservation.token == token) cancel(reservation);
  }

  void cancel(PresentationReservation reservation) {
    _visible.remove(reservation);
    final key = (reservation.scope, reservation.campaignId);
    if (identical(_pending[key], reservation)) _pending.remove(key);
  }

  void acknowledged(String scope, String campaignId, {String? token}) {
    final key = (scope, campaignId);
    _confirmedThrough[key] = _sequence;
    // An older delivery must not release an already visible newer opening.
    // Unshown work started before this ack is stale, even after bridge expiry.
    if (token == null || _pending[key]?.token == token || !_visible.contains(_pending[key])) {
      _visible.remove(_pending.remove(key));
    }
    if (_confirmedThrough.length > 512) {
      _confirmedThrough.remove(_confirmedThrough.entries.reduce((a, b) => a.value <= b.value ? a : b).key);
    }
  }
}
