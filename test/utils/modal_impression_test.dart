import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/utils/modal_impression.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'duplicate visibility, closes and step callbacks share one logical event',
    () {
      var events = 0;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
      );
      opening.explicitClose();
      expect(events, 0);
      opening.appeared();
      opening.explicitClose();
      opening.beginStep();
      opening.closed();
      opening.attach();
      opening.appeared();
      opening.explicitClose();
      opening.closed();
      expect(events, 1);
    },
  );
  test(
    'navigation or cancellation before appearance releases without WRIMP',
    () {
      var events = 0;
      var releases = 0;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
        onUnshownClose: () => releases++,
      );
      opening.closed();
      opening.appeared();
      opening.explicitClose();
      opening.closed();
      expect(events, 0);
      expect(releases, 1);
    },
  );
  test(
    'late disposal of the previous step cannot cancel the new unshown step',
    () {
      var events = 0;
      var releases = 0;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
        onUnshownClose: () => releases++,
      );
      final first = opening.attach();
      opening.beginStep();
      final second = opening.attach();
      opening.closed(attachment: first);
      opening.appeared();
      opening.closed(attachment: second);
      expect(events, 1);
      expect(releases, 0);
    },
  );
  test('background never confirms appearance', () async {
    var events = 0;
    final opening = ModalImpression(
      onVisible: () async {
        events++;
      },
    );
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    opening.appeared();
    opening.explicitClose();
    expect(events, 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
