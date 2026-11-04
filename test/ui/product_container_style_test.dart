import 'dart:convert';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/internal/product_container_type.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_products_container.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _ProductBuilder extends ProductWidgetBuilder {
  @override
  Widget build({
    required BuildContext context,
    required Slot product,
    required CampaignContent content,
    required Campaign campaign,
  }) => const SizedBox(key: ValueKey('product'), width: 60, height: 60);
}

void main() {
  late Campaign campaign;
  setUp(() {
    campaign = Campaign.fromJson(
      jsonDecode(
            jsonEncode({
              'payload': [
                {
                  'campaignId': 'c',
                  'experienceId': 'e',
                  'variationId': 'v',
                  'decisionId': 'd',
                  'contents': [
                    {
                      'contentId': 'products',
                      'deliveryMethod': 'inline',
                      'contentType': 'native',
                      'variables': {},
                    },
                  ],
                },
              ],
            }),
          )
          as Map<String, dynamic>,
    );
    GravitySDK.instance.productWidgetBuilder = _ProductBuilder();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    GravitySDK.instance.productWidgetBuilder = null;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  Future<void> pump(WidgetTester tester, Style style) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GravityProductsContainer(
                  element: Element(
                    type: ElementType.productsContainer,
                    style: style,
                  ),
                  products: Products(
                    strategyId: 'strategy',
                    fallback: false,
                    slots: [
                      Slot(item: {}, fallback: false, strId: 1, slotId: 'slot'),
                    ],
                  ),
                  campaign: campaign,
                  content: campaign.payload.first.contents.first,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  for (final layout in [ProductContainerType.row]) {
    testWidgets(
      '$layout applies margin outside background and keeps padding inside',
      (tester) async {
        await pump(
          tester,
          Style(
            productContainerType: layout,
            size: GravitySize(width: 100, height: 100),
            margin: GravityMargin(left: 16, right: 22, top: 12, bottom: 18),
            padding: GravityPadding(left: 5, right: 9, top: 7, bottom: 11),
            backgroundColor: const Color(0xFF123456),
          ),
        );
        final bounds = tester.getRect(find.byType(GravityProductsContainer));
        final product = tester.getRect(find.byKey(const ValueKey('product')));
        expect(product.left - bounds.left, 21);
        expect(product.top - bounds.top, 19);
        final background = find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == const Color(0xFF123456),
        );
        expect(background, findsOneWidget);
        final painted = tester.getRect(background);
        expect(painted.left - bounds.left, 16);
        expect(bounds.right - painted.right, 22);
        expect(painted.top - bounds.top, 12);
        expect(bounds.bottom - painted.bottom, 18);
        expect(painted.width, 282);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$layout without margin keeps the existing default padding', (
      tester,
    ) async {
      await pump(
        tester,
        Style(
          productContainerType: layout,
          size: GravitySize(width: 100, height: 100),
        ),
      );
      final bounds = tester.getRect(find.byType(GravityProductsContainer));
      final product = tester.getRect(find.byKey(const ValueKey('product')));
      expect(
        product.left - bounds.left,
        layout == ProductContainerType.row ? 16 : 0,
      );
      expect(product.top - bounds.top, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('grid honors padding but ignores margin background and size', (
    tester,
  ) async {
    await pump(
      tester,
      Style(
        productContainerType: ProductContainerType.grid,
        size: GravitySize(width: 100, height: 20),
        margin: GravityMargin(left: 16, right: 22, top: 12, bottom: 18),
        padding: GravityPadding(left: 5, right: 9, top: 7, bottom: 11),
        backgroundColor: const Color(0xFF123456),
      ),
    );
    final bounds = tester.getRect(find.byType(GravityProductsContainer));
    final product = tester.getRect(find.byKey(const ValueKey('product')));
    expect(product.left - bounds.left, 5);
    expect(product.top - bounds.top, 7);
    expect(product.width, 149);
    expect(product.height, product.width);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF123456),
      ),
      findsNothing,
    );
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.crossAxisSpacing, 8);
    expect(delegate.mainAxisSpacing, 8);
    expect(tester.takeException(), isNull);
  });
}
