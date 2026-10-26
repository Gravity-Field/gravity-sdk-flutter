import 'package:gravity_sdk/src/utils/clock.dart';

class PresentationRequest {
  const PresentationRequest(this.sequence, this.generation, this.screen);
  final int sequence;
  final int generation;
  final int screen;
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
  final DateTime expiresAt;
}

/// The bridge from /choose to durable WRIMP delivery. It is not a frequency cap.
/// All decisions happen synchronously on Flutter's UI isolate.
class InAppPresentationGate {
  InAppPresentationGate({DateTime Function()? now})
    : _now = now ?? (() => Clock.now());
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
    if (_generation != generation) {
      _generation = generation;
      _pending.removeWhere((_, reservation) => !_visible.contains(reservation));
      // Keep visible reservations across user switches while their durable
      // append waits for storage; scope keys isolate them from the new user.
      _location = null;
    }
    if (newScreen || location != _location) {
      _screen++;
      _location = location;
      // Visible deliveries are protected by the outbox, independent of UI.
      _pending.removeWhere((_, reservation) => !_visible.contains(reservation));
    }
    return PresentationRequest(++_sequence, generation, _screen);
  }

  bool isCurrent(PresentationRequest request) =>
      request.generation == _generation && request.screen == _screen;

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
      _screen,
      scope,
      campaignId,
      _now().add(const Duration(seconds: 60)),
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

  void visible(PresentationReservation reservation) =>
      _visible.add(reservation);

  void cancel(PresentationReservation reservation) {
    _visible.remove(reservation);
    final key = (reservation.scope, reservation.campaignId);
    if (identical(_pending[key], reservation)) _pending.remove(key);
  }

  void acknowledged(String scope, String campaignId) {
    final key = (scope, campaignId);
    _confirmedThrough[key] = _sequence;
    _visible.remove(_pending.remove(key));
    if (_confirmedThrough.length > 512) {
      _confirmedThrough.remove(_confirmedThrough.keys.first);
    }
  }
}
