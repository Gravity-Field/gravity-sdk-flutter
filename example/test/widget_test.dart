import 'package:example/src/core/widgets/event_props_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

void main() {
  testWidgets(
    'Headless example builds its controls without SDK initialization',
    (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventPropsButton(
              pageContext: PageContext(
                type: ContextType.homepage,
                data: [],
                location: 'homepage',
              ),
            ),
          ),
        ),
      );

      expect(
        find.widgetWithText(OutlinedButton, 'Запросить кампанию просмотра'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Отправить события с customProps'),
        findsOneWidget,
      );
      expect(find.text('Кампания ещё не запрошена'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
