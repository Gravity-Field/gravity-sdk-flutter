import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';
import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_option_select.dart';

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'gravity-option-select-test',
);

FormSession _session() => FormSession(
  pageContext: _pageContext,
  hasFormElements: true,
);

Element _ratingElement() => Element(
  type: ElementType.optionSelect,
  style: Style(
    rating: RatingStyle(
      selectedColor: const Color(0xFF112233),
      unselectedColor: const Color(0xFFCCDDEE),
      itemSize: 24,
      itemSpacing: 6,
    ),
  ),
  attributeName: 'rating',
  optionValues: const [1, 2, 3, 4, 5],
  isRequired: true,
);

Widget _subject(Element element, FormSession session) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: GravityOptionSelect(element: element, session: session),
    ),
  ),
);

Finder _semanticsWith({required String label, required bool selected}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.label == label &&
        widget.properties.button == true &&
        widget.properties.selected == selected,
  );
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
  });

  testWidgets('renders five styled and spaced rating stars', (tester) async {
    final session = _session();

    await tester.pumpWidget(_subject(_ratingElement(), session));

    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(
      tester.widgetList<Icon>(find.byIcon(Icons.star)).map((icon) => icon.size),
      everyElement(24),
    );
    expect(
      tester
          .widgetList<Icon>(find.byIcon(Icons.star))
          .map((icon) => icon.color),
      everyElement(const Color(0xFFCCDDEE)),
    );

    final firstCenter = tester.getCenter(find.byIcon(Icons.star).at(0));
    final secondCenter = tester.getCenter(find.byIcon(Icons.star).at(1));
    expect(secondCenter.dx - firstCenter.dx, 30);
    expect(tester.widget<Row>(find.byType(Row)).mainAxisSize, MainAxisSize.min);
  });

  testWidgets('selects a rating without toggling it off on a repeated tap', (
    tester,
  ) async {
    final session = _session();

    await tester.pumpWidget(_subject(_ratingElement(), session));
    await tester.tap(find.byIcon(Icons.star).at(3));
    await tester.pump();

    expect(session.valueOf('rating'), isA<num>());
    expect(session.valueOf('rating'), 4);
    expect(
      tester
          .widgetList<Icon>(find.byIcon(Icons.star))
          .map((icon) => icon.color)
          .toList(),
      const [
        Color(0xFF112233),
        Color(0xFF112233),
        Color(0xFF112233),
        Color(0xFF112233),
        Color(0xFFCCDDEE),
      ],
    );

    await tester.tap(find.byIcon(Icons.star).at(3));
    await tester.pump();

    expect(session.valueOf('rating'), 4);
  });

  testWidgets('applies the element margin around the star row', (
    tester,
  ) async {
    final session = _session();
    final element = Element(
      type: ElementType.optionSelect,
      style: Style(
        margin: GravityMargin(left: 2, right: 3, top: 4, bottom: 24),
        rating: RatingStyle(
          selectedColor: const Color(0xFF112233),
          unselectedColor: const Color(0xFFCCDDEE),
          itemSize: 24,
          itemSpacing: 6,
        ),
      ),
      attributeName: 'rating',
      optionValues: const [1, 2, 3, 4, 5],
    );

    await tester.pumpWidget(_subject(element, session));

    final margin = tester.widget<Padding>(
      find
          .ancestor(of: find.byType(Row), matching: find.byType(Padding))
          .first,
    );
    expect(
      margin.padding,
      const EdgeInsets.only(left: 2, right: 3, top: 4, bottom: 24),
    );
  });

  testWidgets('exposes a labelled selected state for every star', (
    tester,
  ) async {
    final session = _session()..setValue('rating', 2);

    await tester.pumpWidget(_subject(_ratingElement(), session));

    for (var index = 1; index <= 5; index++) {
      expect(
        _semanticsWith(
          label: 'Оценка $index из 5',
          selected: index <= 2,
        ),
        findsOneWidget,
      );
    }
  });
}
