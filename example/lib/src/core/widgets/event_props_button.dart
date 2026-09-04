import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class EventPropsButton extends StatelessWidget {
  const EventPropsButton({super.key, required this.pageContext});

  final PageContext pageContext;

  Future<void> _send() {
    return GravitySDK.instance.triggerEventNoShow(
      pageContext: pageContext,
      events: [
        AddToCartEvent(
          value: 99.99,
          productId: 'sku-123',
          quantity: 1,
          currency: 'RUB',
          customProps: const {'list': 'search'},
          eventTime: DateTime.now(),
        ),
        CustomEvent(
          type: 'loyalty-v1',
          name: 'Loyalty',
          cuid: 'user@example.com',
          cuidType: 'email',
          cart: const [CartItem(productId: 'sku-123', quantity: 1, itemPrice: 99.99)],
          customProps: const {'points': '150'},
          eventTime: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FilledButton(
        onPressed: _send,
        child: const Text('Отправить события с customProps'),
      ),
    );
  }
}
