import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

void main() {
  final sdk = GravitySDK.instance;

  setUp(() {
    sdk.setPresentationLockListener(null);
    sdk.unlockPresentation();
  });

  // The unlocked-by-default contract is asserted in
  // gravity_sdk_presentation_lock_default_test.dart: here setUp() resets the
  // singleton, so a default-state test would be vacuous.
  group('presentation lock state', () {
    test('lockPresentation locks, unlockPresentation unlocks', () {
      sdk.lockPresentation();
      expect(sdk.isPresentationLocked, isTrue);

      sdk.unlockPresentation();
      expect(sdk.isPresentationLocked, isFalse);
    });

    test('repeated lock and unlock calls are idempotent', () {
      sdk.lockPresentation();
      sdk.lockPresentation();
      expect(sdk.isPresentationLocked, isTrue);

      sdk.unlockPresentation();
      sdk.unlockPresentation();
      expect(sdk.isPresentationLocked, isFalse);
    });

    test('does not require initialize() to be called first', () {
      // GravitySDK.instance is not initialized in this test suite: the logger
      // is not configured, so lock/unlock must not touch it unguarded.
      expect(sdk.lockPresentation, returnsNormally);
      expect(sdk.unlockPresentation, returnsNormally);
    });
  });

  group('presentation lock listener', () {
    test('receives true on lock and false on unlock', () {
      final events = <bool>[];
      sdk.setPresentationLockListener(events.add);

      sdk.lockPresentation();
      sdk.unlockPresentation();

      expect(events, [true, false]);
    });

    test('is invoked on every call, including redundant ones', () {
      final events = <bool>[];
      sdk.setPresentationLockListener(events.add);

      sdk.lockPresentation();
      sdk.lockPresentation();
      sdk.unlockPresentation();
      sdk.unlockPresentation();

      expect(events, [true, true, false, false]);
    });

    test('setting a new listener replaces the previous one', () {
      final first = <bool>[];
      final second = <bool>[];

      sdk.setPresentationLockListener(first.add);
      sdk.setPresentationLockListener(second.add);
      sdk.lockPresentation();

      expect(first, isEmpty);
      expect(second, [true]);
    });

    test('setting a null listener clears the subscription', () {
      final events = <bool>[];
      sdk.setPresentationLockListener(events.add);
      sdk.setPresentationLockListener(null);

      sdk.lockPresentation();

      expect(events, isEmpty);
    });
  });
}
