import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class VisitScreen extends StatelessWidget {
  const VisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visit Screen'),
      ),
      body: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CartVisitButton(),
            _HomePageVisitButton(),
            _OtherVisitButton(),
          ],
        ),
      ),
    );
  }
}

class _CartVisitButton extends StatelessWidget {
  const _CartVisitButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.green),
      ),
      onPressed: () {
        GravitySDK.instance.trackView(
          context: context,
          pageContext: PageContext(
            type: ContextType.cart,
            data: [],
            location: 'cart_screen',
          ),
        );
      },
      child: Text('Cart Visit'),
    );
  }
}

class _HomePageVisitButton extends StatelessWidget {
  const _HomePageVisitButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.green),
      ),
      onPressed: () {
        GravitySDK.instance.trackView(
          context: context,
          pageContext: PageContext(
            type: ContextType.homepage,
            data: [],
            location: 'homepage',
          ),
        );
      },
      child: Text('HomePage Visit'),
    );
  }
}

class _OtherVisitButton extends StatelessWidget {
  const _OtherVisitButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.green),
      ),
      onPressed: () {
        GravitySDK.instance.trackView(
          context: context,
          pageContext: PageContext(
            type: ContextType.other,
            data: [],
            location: 'other',
          ),
        );
      },
      child: Text('Other Visit'),
    );
  }
}

