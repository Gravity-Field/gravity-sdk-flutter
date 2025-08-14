import 'package:example/visit_screen.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';

import 'inline_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GravitySDK.instance.initialize(
    apiKey: 'api-key',
    section: 'section',
    productWidgetBuilder: CustomProductWidgetBuilder(),
    gravityEventCallback: (TrackingEvent event) {
      print('event: $event');
    },
  );

  runApp(MyApp());
}

class CustomProductWidgetBuilder extends ProductWidgetBuilder {
  @override
  Widget build({
    required BuildContext context,
    required Slot product,
    required CampaignContent content,
    required Campaign campaign,
  }) {
    return Container(
      width: 200,
      color: Colors.amber,
      height: 250,
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          Text(product.item['sku']),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Gravity SDK Example'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _InlineButton(),
            _VisitButton(),
            _SendAddToCartEvent(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InlineButton extends StatelessWidget {
  const _InlineButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.green),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const InlineScreen(),
          ),
        );
      },
      child: Text('Go To Inline'),
    );
  }
}

class _SendAddToCartEvent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.green),
      ),
      onPressed: () async {
        final events = [
          AddToCartEvent(
            value: 118.26,
            currency: 'RUB',
            productId: 'item-34454',
            quantity: 2,
            cart: [
              CartItem(productId: 'sku-123', quantity: 2, itemPrice: 59.99),
              CartItem(productId: 'sku-456', quantity: 1, itemPrice: 69.99),
            ],
          ),
        ];
        GravitySDK.instance.triggerEvent(
          context: context,
          events: events,
          pageContext: PageContext(
            type: ContextType.cart,
            data: ['checkout'],
            location: 'app://checkout',
          ),
        );
      },
      child: Text('Send Add To Cart Event'),
    );
  }
}

class _VisitButton extends StatelessWidget {
  const _VisitButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.green),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const VisitScreen(),
          ),
        );
      },
      child: Text('Go To Visit'),
    );
  }
}
