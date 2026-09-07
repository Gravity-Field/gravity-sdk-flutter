/// Single time source for the SDK. Tests override [now] to control time.
class Clock {
  Clock._();

  static DateTime Function() now = DateTime.now;
}
