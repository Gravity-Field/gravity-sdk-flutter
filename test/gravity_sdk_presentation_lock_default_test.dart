import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

// Kept in its own file: the suite runs in a fresh isolate, so this is the
// first observation of the GravitySDK singleton and genuinely asserts the
// declared default, not the effect of a setUp reset.
void main() {
  test('presentation is unlocked by default', () {
    expect(GravitySDK.instance.isPresentationLocked, isFalse);
  });
}
