import 'package:flutter/material.dart' hide Action, Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';
import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_button.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_text_input.dart';

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'gravity-text-input-test',
);

FormSession _session() => FormSession(
  pageContext: _pageContext,
  hasFormElements: true,
);

Element _textInputElement({int? maxLength, int? minLength, double? height}) => Element(
  type: ElementType.textInput,
  style: Style(
    backgroundColor: const Color(0xFFEFF1F3),
    cornerRadius: 12,
    size: GravitySize(width: 280, height: height),
    padding: GravityPadding(left: 10, right: 11, top: 12, bottom: 13),
    textStyle: GravityTextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF102030),
    ),
  ),
  attributeName: 'feedback',
  maxLength: maxLength,
  minLength: minLength,
  placeholder: 'Ваш комментарий',
);

Widget _textInputSubject(Element element, FormSession session) => MaterialApp(
  home: Scaffold(
    body: GravityTextInput(element: element, session: session),
  ),
);

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
  });

  testWidgets('restores its initial text from the form session', (
    tester,
  ) async {
    final session = _session()..setValue('feedback', 'Сохранённый текст');

    await tester.pumpWidget(
      _textInputSubject(_textInputElement(), session),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Сохранённый текст',
    );
  });

  testWidgets('writes raw input into the form session', (tester) async {
    final session = _session();

    await tester.pumpWidget(
      _textInputSubject(_textInputElement(), session),
    );
    await tester.enterText(find.byType(TextField), '  raw feedback  ');

    expect(session.valueOf('feedback'), '  raw feedback  ');
  });

  testWidgets('limits text by grapheme clusters and shows the counter', (
    tester,
  ) async {
    final session = _session();

    await tester.pumpWidget(
      _textInputSubject(_textInputElement(maxLength: 5), session),
    );
    await tester.enterText(find.byType(TextField), '😀😀😀😀😀😀');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '😀😀😀😀😀',
    );
    expect(session.valueOf('feedback'), '😀😀😀😀😀');
    expect(find.text('5/5'), findsOneWidget);
  });

  testWidgets('shows the minimum length hint under the field', (tester) async {
    final session = _session();

    await tester.pumpWidget(
      _textInputSubject(_textInputElement(minLength: 10), session),
    );

    expect(find.text('Минимум 10 символов'), findsOneWidget);
  });

  testWidgets('shows no hint without minLength', (tester) async {
    final session = _session();

    await tester.pumpWidget(_textInputSubject(_textInputElement(), session));

    expect(find.textContaining('Минимум'), findsNothing);
  });

  group('minLengthHint pluralizes the character count', () {
    const cases = {
      1: 'Минимум 1 символ',
      21: 'Минимум 21 символ',
      2: 'Минимум 2 символа',
      34: 'Минимум 34 символа',
      5: 'Минимум 5 символов',
      11: 'Минимум 11 символов',
      114: 'Минимум 114 символов',
    };
    cases.forEach((count, expected) {
      test('$count -> $expected', () => expect(minLengthHint(count), expected));
    });
  });

  testWidgets('uses the configured multiline field style', (tester) async {
    final session = _session();

    await tester.pumpWidget(
      _textInputSubject(_textInputElement(height: 160), session),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    final border = decoration.border! as OutlineInputBorder;

    expect(field.keyboardType, TextInputType.multiline);
    expect(field.maxLines, isNull);
    expect(field.expands, isTrue);
    expect(field.maxLength, isNull);
    expect(decoration.hintText, 'Ваш комментарий');
    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, const Color(0xFFEFF1F3));
    expect(
      decoration.contentPadding,
      const EdgeInsets.fromLTRB(10, 12, 11, 13),
    );
    expect(border.borderRadius, BorderRadius.circular(12));
    expect(field.style?.color, const Color(0xFF102030));
    expect(field.style?.fontSize, 17);
    expect(field.style?.fontWeight, FontWeight.w600);
    expect(tester.getSize(find.byType(TextField)).height, 160);
  });

  testWidgets('disabled GravityButton falls back to Material default colors', (
    tester,
  ) async {
    const background = Color(0xFF224466);
    const foreground = Color(0xFFAACCEE);
    final element = Element(
      type: ElementType.button,
      text: 'Отправить',
      style: Style(
        backgroundColor: background,
        textStyle: GravityTextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
      onClick: OnClick(action: Action.submitForm),
    );
    var clicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GravityButton(
          element: element,
          enabled: false,
          onClickCallback: (_) => clicked = true,
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    expect(button.style?.backgroundColor?.resolve({}), background);
    expect(button.style?.foregroundColor?.resolve({}), foreground);
    expect(button.style?.backgroundColor?.resolve({WidgetState.disabled}), isNull);
    expect(button.style?.foregroundColor?.resolve({WidgetState.disabled}), isNull);

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    final onSurface = Theme.of(
      tester.element(find.byType(FilledButton)),
    ).colorScheme.onSurface;
    // Дефолт M3 — onSurface с альфой 12%; точное значение квантуется до
    // 8 бит внутри Flutter, поэтому сравниваем с допуском.
    expect(material.color!.a, closeTo(0.12, 0.005));
    expect(material.color!.r, onSurface.r);
    expect(material.color!.g, onSurface.g);
    expect(material.color!.b, onSurface.b);

    await tester.tap(find.byType(FilledButton));
    expect(clicked, isFalse);
  });
}
