import 'dart:convert';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/internal/product_container_type.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_products_container.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_element.dart';
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

  for (final dimension in <Object>[
    'Infinity',
    '-Infinity',
    'NaN',
    '1e400',
    'Infinitypx',
    double.infinity,
    double.negativeInfinity,
    double.nan,
    '84',
    '84px',
    84,
    84.0,
  ]) {
    testWidgets(
      'grid without products parses height $dimension (${dimension.runtimeType}) and takes no space',
      (tester) async {
        final style = Style.fromJson({
          'productContainerType': 'grid',
          'size': {'height': dimension},
        });
        final child = GravityElement(
          content: campaign.payload.first.contents.first,
          campaign: campaign,
          element: Element(type: ElementType.productsContainer, style: style),
          products: null,
          onClickCallback: (_) {},
        ).getWidget();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey('dimension-probe'),
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [child],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final valid = dimension.toString().startsWith('84');
        expect(style.size?.height, valid ? 84 : isNull);
        expect(
          tester.getSize(find.byKey(const ValueKey('dimension-probe'))).height,
          0,
        );
      },
    );
  }

  for (final (state, products, rowHeight, gridHeight)
      in <(String, Products?, double, double)>[
        ('products null', null, 0, 0),
        (
          'slots null',
          Products(strategyId: 'strategy', fallback: false, slots: null),
          0,
          0,
        ),
        (
          'slots empty',
          Products(strategyId: 'strategy', fallback: false, slots: []),
          0,
          0,
        ),
      ]) {
    for (final type in [ProductContainerType.row, ProductContainerType.grid]) {
      testWidgets('$state $type reports its height including padding', (
        tester,
      ) async {
        final child = GravityElement(
          content: campaign.payload.first.contents.first,
          campaign: campaign,
          element: Element(
            type: ElementType.productsContainer,
            style: Style(
              productContainerType: type,
              size: GravitySize(width: null, height: 84),
              padding: GravityPadding(left: 5, right: 9, top: 7, bottom: 11),
            ),
          ),
          products: products,
          onClickCallback: (_) {},
        ).getWidget();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey('height-probe'),
                  width: 320,
                  child: child,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const ValueKey('height-probe'))).height,
          type == ProductContainerType.row ? rowHeight : gridHeight,
        );
      });
    }
  }

  for (final (state, products) in <(String, Products?)>[
    ('products null', null),
    (
      'slots null',
      Products(strategyId: 'strategy', fallback: false, slots: null),
    ),
    (
      'slots missing',
      Products.fromJson({'strategyId': 'strategy', 'fallback': false}),
    ),
    (
      'slots empty',
      Products(strategyId: 'strategy', fallback: false, slots: []),
    ),
  ]) {
    for (final type in <ProductContainerType?>[
      ProductContainerType.row,
      null,
      ProductContainerType.grid,
    ]) {
      testWidgets(
        'empty container ($state, type $type) collapses margin padding and background',
        (tester) async {
          final child = GravityElement(
            content: campaign.payload.first.contents.first,
            campaign: campaign,
            element: Element(
              type: ElementType.productsContainer,
              style: Style(
                productContainerType: type,
                size: GravitySize(width: null, height: 84),
                margin: GravityMargin(left: 16, right: 22, top: 12, bottom: 18),
                padding: GravityPadding(left: 5, right: 9, top: 7, bottom: 11),
                backgroundColor: const Color(0xFF123456),
              ),
            ),
            products: products,
            onClickCallback: (_) {},
          ).getWidget();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    key: const ValueKey('empty-row-probe'),
                    width: 320,
                    child: child,
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('empty-row-probe')))
                .height,
            0,
          );
          expect(find.byType(ListView), findsNothing);
          expect(find.byType(GridView), findsNothing);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  (w is Container && w.color == const Color(0xFF123456)) ||
                  (w is ColoredBox && w.color == const Color(0xFF123456)),
            ),
            findsNothing,
          );
        },
      );
    }
  }

  for (final absentProducts in [true, false]) {
    testWidgets(
      'grid takes no space with configured height and products absent=$absentProducts',
      (tester) async {
        final widget = GravityElement(
          content: campaign.payload.first.contents.first,
          campaign: campaign,
          element: Element(
            type: ElementType.productsContainer,
            style: Style(
              productContainerType: ProductContainerType.grid,
              size: GravitySize(width: null, height: 84),
            ),
          ),
          products: absentProducts
              ? null
              : Products(strategyId: 'strategy', fallback: false, slots: null),
          onClickCallback: (_) {},
        ).getWidget();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey('placeholder'),
                  child: widget,
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('placeholder'))).height,
          0,
        );
      },
    );
  }

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
