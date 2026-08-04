import 'package:flutter/material.dart' hide Action, Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/models/internal/campaign_variation.dart';
import 'package:gravity_sdk/src/models/internal/condition.dart';
import 'package:gravity_sdk/src/models/internal/delivery_type.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';
import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:gravity_sdk/src/models/internal/variables.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_option_select.dart';
import 'package:gravity_sdk/src/ui/widgets/gravity_elements_column.dart';

const _columnKey = Key('gravity-elements-column');

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'elements-column-test',
);

CampaignContent _content(List<Element> elements) => CampaignContent(
  contentId: 'content-1',
  templateSystemName: null,
  deliveryMethod: DeliveryMethod.modal,
  contentType: 'native',
  variables: Variables(elements: elements),
  products: null,
  events: null,
);

Campaign _campaign(CampaignContent content) => Campaign(
  selector: null,
  payload: [
    CampaignVariation(
      campaignId: 'campaign-1',
      experienceId: 'experience-1',
      variationId: 'variation-1',
      decisionId: 'decision-1',
      contents: [content],
    ),
  ],
);

FormSession _session() => FormSession(
  pageContext: _pageContext,
  hasFormElements: true,
);

List<Element> _elements() => [
  Element(
    type: ElementType.text,
    text: 'Always visible',
    style: Style(),
  ),
  Element(
    type: ElementType.text,
    text: 'Visible after rating',
    style: Style(),
    visibleWhen: Condition.tryParse({
      'attributeName': 'rating',
      'operator': 'is_not_empty',
    }),
  ),
  Element(
    type: ElementType.optionSelect,
    style: Style(),
    attributeName: 'rating',
    optionValues: const [1, 2, 3, 4, 5],
  ),
];

Widget _subject({
  required CampaignContent content,
  required Campaign campaign,
  required FormSession? session,
  required bool formsEnabled,
  List<Element>? elements,
  void Function(Element element, OnClick onClick)? onClickCallback,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GravityElementsColumn(
        key: _columnKey,
        content: content,
        campaign: campaign,
        session: session,
        formsEnabled: formsEnabled,
        elements: elements,
        mainAxisAlignment: mainAxisAlignment,
        onClickCallback: onClickCallback ?? (_, _) {},
      ),
    ),
  );
}

Finder get _renderedColumn => find.descendant(
  of: find.byKey(_columnKey),
  matching: find.byType(Column),
);

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
  });

  testWidgets('rebuilds visible elements when session state changes', (
    tester,
  ) async {
    final content = _content(_elements());
    final campaign = _campaign(content);
    final session = _session();

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: campaign,
        session: session,
        formsEnabled: true,
      ),
    );

    expect(find.text('Always visible'), findsOneWidget);
    expect(find.text('Visible after rating'), findsNothing);
    expect(find.byType(GravityOptionSelect), findsOneWidget);

    session.setValue('rating', 4);
    await tester.pumpAndSettle();

    expect(find.text('Visible after rating'), findsOneWidget);
  });

  testWidgets('conditional elements animate in and out smoothly', (
    tester,
  ) async {
    final content = _content(_elements());
    final campaign = _campaign(content);
    final session = _session();

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: campaign,
        session: session,
        formsEnabled: true,
      ),
    );

    session.setValue('rating', 4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-animation: the element is already mounted but still growing.
    expect(find.text('Visible after rating'), findsOneWidget);
    final growing = tester.widget<SizeTransition>(
      find
          .ancestor(
            of: find.text('Visible after rating'),
            matching: find.byType(SizeTransition),
          )
          .first,
    );
    expect(growing.sizeFactor.value, greaterThan(0.0));
    expect(growing.sizeFactor.value, lessThan(1.0));

    await tester.pumpAndSettle();
    expect(find.text('Visible after rating'), findsOneWidget);

    session.setValue('rating', null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-animation: still mounted while shrinking away.
    expect(find.text('Visible after rating'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Visible after rating'), findsNothing);
  });

  testWidgets('conditional buttons swap instantly without animation', (
    tester,
  ) async {
    final elements = [
      Element(
        type: ElementType.button,
        text: 'Не сейчас',
        style: Style(),
        onClick: OnClick(action: Action.close),
        visibleWhen: Condition.tryParse({
          'attributeName': 'rating',
          'operator': 'is_empty',
        }),
      ),
      Element(
        type: ElementType.button,
        text: 'Отправить',
        style: Style(),
        onClick: OnClick(action: Action.submitForm),
        visibleWhen: Condition.tryParse({
          'attributeName': 'rating',
          'operator': 'is_not_empty',
        }),
      ),
    ];
    final content = _content(elements);
    final session = _session();

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: _campaign(content),
        session: session,
        formsEnabled: true,
      ),
    );

    expect(find.text('Не сейчас'), findsOneWidget);
    expect(find.text('Отправить'), findsNothing);

    session.setValue('rating', 4);
    await tester.pump();

    // One frame later the buttons have swapped in place — no grow/shrink.
    expect(find.text('Не сейчас'), findsNothing);
    expect(find.text('Отправить'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Отправить'),
        matching: find.byType(SizeTransition),
      ),
      findsNothing,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('removes form inputs when forms are disabled', (tester) async {
    final content = _content(_elements());

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: _campaign(content),
        session: _session(),
        formsEnabled: false,
      ),
    );

    // The conditional text keeps a collapsed animation slot; the form input
    // must not get even that.
    expect(tester.widget<Column>(_renderedColumn).children, hasLength(2));
    expect(find.text('Always visible'), findsOneWidget);
    expect(find.text('Visible after rating'), findsNothing);
    expect(find.byType(GravityOptionSelect), findsNothing);
  });

  testWidgets('renders an explicitly supplied element subset', (tester) async {
    final elements = _elements();
    final content = _content(elements);

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: _campaign(content),
        session: null,
        formsEnabled: false,
        elements: [elements.first],
      ),
    );

    expect(find.text('Always visible'), findsOneWidget);
    expect(find.text('Visible after rating'), findsNothing);
    expect(tester.widget<Column>(_renderedColumn).children, hasLength(1));
  });

  testWidgets('passes the clicked element together with its action', (
    tester,
  ) async {
    final onClick = OnClick(action: Action.close);
    final element = Element(
      type: ElementType.text,
      text: 'Tap me',
      style: Style(),
      onClick: onClick,
    );
    final content = _content([element]);
    Element? clickedElement;
    OnClick? clickedAction;

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: _campaign(content),
        session: _session(),
        formsEnabled: true,
        onClickCallback: (element, onClick) {
          clickedElement = element;
          clickedAction = onClick;
        },
      ),
    );

    await tester.tap(find.text('Tap me'));

    expect(clickedElement, same(element));
    expect(clickedAction, same(onClick));
  });

  testWidgets('keeps submit-form buttons inert when forms are disabled', (
    tester,
  ) async {
    final element = Element(
      type: ElementType.button,
      text: 'Submit',
      style: Style(),
      onClick: OnClick(action: Action.submitForm),
    );
    final content = _content([element]);
    var callbackCalled = false;

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: _campaign(content),
        session: null,
        formsEnabled: false,
        onClickCallback: (_, _) => callbackCalled = true,
      ),
    );

    await tester.tap(find.text('Submit'));

    expect(callbackCalled, isFalse);
  });

  testWidgets(
    'enables submit only when visible required inputs are non-empty',
    (
      tester,
    ) async {
      final requiredFeedback = Element(
        type: ElementType.textInput,
        style: Style(),
        attributeName: 'feedback',
        isRequired: true,
        visibleWhen: Condition.tryParse({
          'attributeName': 'showFeedback',
          'operator': 'is_not_empty',
        }),
      );
      final submit = Element(
        type: ElementType.button,
        text: 'Submit required form',
        style: Style(),
        onClick: OnClick(action: Action.submitForm),
      );
      final content = _content([requiredFeedback, submit]);
      final session = _session();

      await tester.pumpWidget(
        _subject(
          content: content,
          campaign: _campaign(content),
          session: session,
          formsEnabled: true,
        ),
      );

      FilledButton submitButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit required form'),
      );

      expect(submitButton().onPressed, isNotNull);

      session.setValue('showFeedback', 'show');
      await tester.pump();
      expect(submitButton().onPressed, isNull);

      session.setValue('feedback', '   ');
      await tester.pump();
      expect(submitButton().onPressed, isNull);

      session.setValue('feedback', 'Ready');
      await tester.pump();
      expect(submitButton().onPressed, isNotNull);
    },
  );

  testWidgets(
    'keeps submit disabled while a visible input is below minLength',
    (
      tester,
    ) async {
      final feedback = Element(
        type: ElementType.textInput,
        style: Style(),
        attributeName: 'feedback',
        minLength: 3,
      );
      final submit = Element(
        type: ElementType.button,
        text: 'Submit short form',
        style: Style(),
        onClick: OnClick(action: Action.submitForm),
      );
      final content = _content([feedback, submit]);
      final session = _session();

      await tester.pumpWidget(
        _subject(
          content: content,
          campaign: _campaign(content),
          session: session,
          formsEnabled: true,
        ),
      );

      FilledButton submitButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit short form'),
      );

      // minLength implies the field must be filled — the button is disabled
      // from the very first frame, not only after the user starts typing.
      expect(submitButton().onPressed, isNull);

      session.setValue('feedback', 'ab');
      await tester.pump();
      expect(submitButton().onPressed, isNull);

      session.setValue('feedback', 'abc');
      await tester.pump();
      expect(submitButton().onPressed, isNotNull);

      session.setValue('feedback', '');
      await tester.pump();
      expect(submitButton().onPressed, isNull);
    },
  );

  testWidgets('forwards main-axis alignment to the rendered column', (
    tester,
  ) async {
    final content = _content(const []);

    await tester.pumpWidget(
      _subject(
        content: content,
        campaign: _campaign(content),
        session: null,
        formsEnabled: false,
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );

    expect(
      tester.widget<Column>(_renderedColumn).mainAxisAlignment,
      MainAxisAlignment.center,
    );
  });

  group('shouldAutoPopOnClick', () {
    final button = Element(type: ElementType.button, style: null);

    test('returns true for a close button with closeOnClick', () {
      expect(
        shouldAutoPopOnClick(button, OnClick(action: Action.close)),
        isTrue,
      );
    });

    test('returns false for submit-form, unknown, and open-step actions', () {
      for (final action in [
        Action.submitForm,
        Action.unknown,
        Action.openStep,
      ]) {
        expect(
          shouldAutoPopOnClick(button, OnClick(action: action)),
          isFalse,
          reason: '$action must not close the current route automatically',
        );
      }
    });

    test('returns false when closeOnClick is disabled', () {
      expect(
        shouldAutoPopOnClick(
          button,
          OnClick(action: Action.close, closeOnClick: false),
        ),
        isFalse,
      );
    });

    test('returns false for non-button elements', () {
      final text = Element(type: ElementType.text, style: Style());

      expect(
        shouldAutoPopOnClick(text, OnClick(action: Action.close)),
        isFalse,
      );
    });
  });
}
