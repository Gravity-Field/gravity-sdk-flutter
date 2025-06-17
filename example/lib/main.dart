import 'package:example/visit_screen.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/gravity_sdk.dart';

import 'inline_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GravitySDK.instance.initialize(
    apiKey: 'Mjk3OWQ1MDg2NGQzZTQ1YzI0Yjk3N2Y4ZDlmN2QxOGE5MGVhNTU5ZmY1MThjZDEwYTAzNGE4ZDZiZTI2MzQ1NA==',
    section: '6819e7c0d7303f0f6b0ef263',
    productWidgetBuilder: CustomProductWidgetBuilder(),
    gravityEventCallback: (TrackingEvent event) {
      print('event: $event');
    },
  );

  runApp(MyApp());
}

class CustomProductWidgetBuilder extends ProductWidgetBuilder {
  @override
  Widget build(Slot product, BuildContext context) {
    return Container(
      width: 20,
      color: Colors.amber,
      height: 20,
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
