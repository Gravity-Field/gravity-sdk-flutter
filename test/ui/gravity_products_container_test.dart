import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/internal/product_container_type.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_products_container.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _ProductBuilder extends ProductWidgetBuilder {
  const _ProductBuilder();

  @override
  Widget build({
    required BuildContext context,
    required Slot product,
    required CampaignContent content,
    required Campaign campaign,
  }) =>
      SizedBox(key: ValueKey('card-${product.slotId}'), width: 64, height: 40);
}

Widget _subject({
  required GravitySize? size,
  double width = 320,
  GridSettings? settings,
  ProductContainerType type = ProductContainerType.grid,
}) {
  final products = Products(
    strategyId: 'strategy',
    fallback: false,
    slots: List.generate(
      4,
      (index) => Slot(
        item: const {},
        fallback: false,
        strId: index,
        slotId: '$index',
      ),
    ),
  );
  final content = CampaignContent(
    contentId: 'grid-content',
    templateSystemName: null,
    deliveryMethod: DeliveryMethod.inline,
    contentType: 'native',
    variables: Variables(),
    products: products,
    events: null,
  );
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: GravityProductsContainer(
            element: Element(
              type: ElementType.productsContainer,
              style: Style(
                size: size,
                productContainerType: type,
                gridSettings: settings,
              ),
            ),
            products: products,
            campaign: Campaign(selector: null, payload: []),
            content: content,
          ),
        ),
      ),
    ),
  );
}

void main() {
  ProductWidgetBuilder? originalBuilder;
  late Duration originalInterval;

  setUp(() {
    originalBuilder = GravitySDK.instance.productWidgetBuilder;
    GravitySDK.instance.productWidgetBuilder = const _ProductBuilder();
    originalInterval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    GravitySDK.instance.productWidgetBuilder = originalBuilder;
    VisibilityDetectorController.instance.updateInterval = originalInterval;
  });

  for (final (name, size) in <(String, GravitySize?)>[
    ('both width and height', GravitySize(width: 240, height: 80)),
    ('only height', GravitySize(width: null, height: 80)),
    ('only width', GravitySize(width: 240, height: null)),
    ('no dimensions', null),
  ]) {
    testWidgets(
      'grid cards are square with $name on normal and narrow screens',
      (tester) async {
        for (final width in [320.0, 180.0]) {
          await tester.pumpWidget(_subject(size: size, width: width));
          expect(tester.takeException(), isNull);
          for (var index = 0; index < 4; index++) {
            final card = tester.getSize(find.byKey(ValueKey('card-$index')));
            expect(card.width, closeTo((width - 8) / 2, 0.001));
            expect(card.height, closeTo(card.width, 0.001));
          }
        }
      },
    );
  }

  testWidgets('row still uses the configured container height', (tester) async {
    await tester.pumpWidget(
      _subject(
        size: GravitySize(width: 240, height: 72),
        type: ProductContainerType.row,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('card-0'))).height, 72);
  });

  for (final (horizontal, vertical) in [
    (-4.0, 12.0),
    (12.0, -4.0),
    (-4.0, -4.0),
    (0.0, 0.0),
  ]) {
    testWidgets('grid renders safe gaps for spacing ($horizontal, $vertical)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(
          size: null,
          settings: GridSettings(
            horizontalSpacing: horizontal,
            verticalSpacing: vertical,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.byKey(const ValueKey('card-0')));
      final second = tester.getRect(find.byKey(const ValueKey('card-1')));
      final third = tester.getRect(find.byKey(const ValueKey('card-2')));
      expect(
        second.left - first.right,
        closeTo(horizontal < 0 ? 8 : horizontal, 0.001),
      );
      expect(
        third.top - first.bottom,
        closeTo(vertical < 0 ? 8 : vertical, 0.001),
      );
    });
  }
}
