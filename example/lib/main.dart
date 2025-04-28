import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

import 'inline_screen.dart';

void main() {
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
  MyApp({super.key});

  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    GravitySDK.instance.initialize(
      apiKey: 'api-key',
      section: 'section',
      navigatorKey: navigatorKey,
      // productWidgetBuilder: CustomProductWidgetBuilder(),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
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
            SizedBox(height: 32),
            _ModalButton1(),
            _ModalButton2(),
            _BottomSheetButton1(),
            _BottomSheetBanner(),
            _BottomSheetProductsRow(),
            // _BottomSheetProductsGrid(),
            _FullScreenButton(),
          ],
        ),
      ),
    );
  }
}

class _InlineButton extends StatelessWidget {
  const _InlineButton({super.key});

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

class _ModalButton1 extends StatelessWidget {
  const _ModalButton1();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final response = await GravitySDK.instance.getContent('modal-template-1');
        if (context.mounted) {
          GravitySDK.instance.showModalContent(context, response);
        }
      },
      child: Text('Modal 1'),
    );
  }
}

class _ModalButton2 extends StatelessWidget {
  const _ModalButton2();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final response = await GravitySDK.instance.getContent('modal-template-2');
        if (context.mounted) {
          GravitySDK.instance.showModalContent(context, response);
        }
      },
      child: Text('Modal 2'),
    );
  }
}

class _BottomSheetButton1 extends StatelessWidget {
  const _BottomSheetButton1();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final response = await GravitySDK.instance.getContent('bottom-sheet-template-1');
        if (context.mounted) {
          GravitySDK.instance.showBottomSheetContent(context, response);
        }
      },
      child: Text('BottomSheet 1'),
    );
  }
}

class _BottomSheetBanner extends StatelessWidget {
  const _BottomSheetBanner();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final response = await GravitySDK.instance.getContent('bottom-sheet-banner');
        if (context.mounted) {
          GravitySDK.instance.showBottomSheetContent(context, response);
        }
      },
      child: Text('Bottom Sheet Banner'),
    );
  }
}

class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final response = await GravitySDK.instance.getContent('fullscreen-banner');
        if (context.mounted) {
          GravitySDK.instance.showFullScreenContent(context, response);
        }
      },
      child: Text('Show Full Screen'),
    );
  }
}

class _BottomSheetProductsRow extends StatelessWidget {
  const _BottomSheetProductsRow();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final response = await GravitySDK.instance.getContent('bottom-sheet-products-row');
        if (context.mounted) {
          GravitySDK.instance.showBottomSheetProductsRow(context, response);
        }
      },
      child: Text('Bottom Sheet Products Row'),
    );
  }
}
