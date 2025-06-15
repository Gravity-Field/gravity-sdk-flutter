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
            _VisitButton(),
          ],
        ),
      ),
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
        GravitySDK.instance.trackView(
          context: context,
          pageContext: PageContext(
            type: ContextType.cart,
            data: [],
            location: 'cart_screen',
          ),
        );
      },
      child: Text('Go To Visit'),
    );
  }
}
