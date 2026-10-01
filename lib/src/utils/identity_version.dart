/// Counts changes of the user the SDK acts for: a new custom user, a reset,
/// a restored uid. Content loaded for one user must not be shown to the next,
/// so whoever loads it notes [current] before the request and compares after.
class IdentityVersion {
  IdentityVersion._();

  static int _current = 0;

  static int get current => _current;

  static void bump() => _current++;
}
