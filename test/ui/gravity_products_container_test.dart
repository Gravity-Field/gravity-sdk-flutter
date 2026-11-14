import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/internal/product_container_type.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_products_container.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_sdk/src/models/actions/product_event.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

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
  String contentId = 'grid-content',
  String decisionId = 'decision',
  bool tracking = false,
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
        events: tracking
            ? [
                ProductEvent.fromJson({
                  'type': 'visible_impression',
                  'urls': <String>[],
                }),
              ]
            : null,
      ),
    ),
  );
  final content = CampaignContent(
    contentId: contentId,
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
            campaign: Campaign.fromJson({
              'payload': [
                {
                  'campaignId': 'campaign',
                  'experienceId': 'experience',
                  'variationId': 'variation',
                  'decisionId': decisionId,
                  'contents': <Object>[],
                },
              ],
            }),
            content: content,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'grid-test',
      packageName: 'grid-test',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    ErrorReporter.disableNetworkForTests = true;
    await GravitySDK.instance.initialize(apiKey: 'test', section: 'test');
  });

  testWidgets('a new content opening can count the same product slots again', (
    tester,
  ) async {
    final impressions = <ProductImpressionEvent>[];
    GravitySDK.instance.gravityEventCallback = (event) {
      if (event is ProductImpressionEvent) impressions.add(event);
    };
    addTearDown(() => GravitySDK.instance.gravityEventCallback = null);
    await tester.pumpWidget(_subject(size: null, tracking: true));
    await tester.pump();
    expect(impressions, hasLength(4));
    await tester.pumpWidget(_subject(size: null, tracking: true));
    await tester.pump();
    expect(impressions, hasLength(4), reason: 'rebuild retains protection');
    await tester.pumpWidget(
      _subject(size: null, tracking: true, contentId: 'new-content'),
    );
    await tester.pump();
    expect(
      impressions,
      hasLength(8),
      reason: 'different content owns a new opening',
    );
    await tester.pumpWidget(
      _subject(
        size: null,
        tracking: true,
        contentId: 'new-content',
        decisionId: 'new-decision',
      ),
    );
    await tester.pump();
    expect(
      impressions,
      hasLength(12),
      reason: 'new campaign decision owns its impressions',
    );
  });

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

  testWidgets(
    'grid counts each slot once starting at exactly half visibility',
    (tester) async {
      final impressions = <ProductImpressionEvent>[];
      GravitySDK.instance.gravityEventCallback = (event) {
        if (event is ProductImpressionEvent) impressions.add(event);
      };
      addTearDown(() => GravitySDK.instance.gravityEventCallback = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 77);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_subject(size: null, tracking: true));
      await tester.pump();
      expect(
        impressions,
        isEmpty,
        reason: '77 of 156 pixels is less than half',
      );
      tester.view.physicalSize = const Size(320, 78);
      await tester.pump();
      await tester.pump();
      expect(
        impressions,
        hasLength(2),
        reason: '78 of 156 pixels is exactly half',
      );
      tester.view.physicalSize = const Size(320, 320);
      await tester.pump();
      await tester.pump();
      expect(
        impressions,
        hasLength(4),
        reason: 'already counted first row does not repeat',
      );
    },
  );

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
