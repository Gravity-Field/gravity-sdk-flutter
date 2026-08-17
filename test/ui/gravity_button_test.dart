import 'package:flutter/material.dart' hide Action, Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';
import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_button.dart';

Element _button({Color? outlineColor}) => Element(
  type: ElementType.button,
  text: 'Не сейчас',
  style: Style(
    backgroundColor: const Color(0xFFFFFFFF),
    outlineColor: outlineColor,
    cornerRadius: 48,
  ),
  onClick: OnClick(action: Action.close),
);

Widget _subject(Element element, {bool enabled = true}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: GravityButton(
        element: element,
        enabled: enabled,
        onClickCallback: (_) {},
      ),
    ),
  ),
);

OutlinedBorder _resolvedShape(
  WidgetTester tester, {
  Set<WidgetState> states = const {},
}) {
  final button = tester.widget<FilledButton>(find.byType(FilledButton));
  return button.style!.shape!.resolve(states)!;
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
  });

  testWidgets('clips the press ripple to the rounded shape', (tester) async {
    await tester.pumpWidget(_subject(_button()));

    // Без клипа Material рисует всплеск прямоугольником поверх скруглённой
    // кнопки — на закрывающейся шторке это выглядит как рывок цвета.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).clipBehavior,
      Clip.antiAlias,
    );
  });

  testWidgets('outlineColor renders as a border around the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(_button(outlineColor: const Color(0xFFD9D9D9))),
    );

    final shape = _resolvedShape(tester) as RoundedRectangleBorder;
    expect(shape.side.color, const Color(0xFFD9D9D9));
    expect(shape.side.width, 1);
    expect(shape.side.style, BorderStyle.solid);
    expect(shape.borderRadius, BorderRadius.circular(48));
  });

  testWidgets('no outlineColor keeps the borderless shape', (tester) async {
    await tester.pumpWidget(_subject(_button()));

    final shape = _resolvedShape(tester) as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
  });

  testWidgets('disabled button dims its outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(_button(outlineColor: const Color(0xFFD9D9D9)), enabled: false),
    );

    final shape =
        _resolvedShape(tester, states: {WidgetState.disabled})
            as RoundedRectangleBorder;
    expect(
      shape.side.color,
      const Color(0xFFD9D9D9).withValues(alpha: 0.4),
    );
  });
}
