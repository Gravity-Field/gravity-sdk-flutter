import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

Map<String, dynamic> wire(TriggerEvent event) => jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>;

void main() {
  const props = {'list': 'search', 'payment_type': 'card'};
  final localTime = DateTime(2026, 9, 3, 12, 30, 15, 250);

  List<TriggerEvent> typedEvents({Map<String, String>? customProps, DateTime? eventTime}) => [
    AddToCartEvent(value: 1, productId: 'p', quantity: 1, customProps: customProps, eventTime: eventTime),
    RemoveFromCartEvent(value: 1, productId: 'p', quantity: 1, customProps: customProps, eventTime: eventTime),
    SyncCartEvent(value: 1, customProps: customProps, eventTime: eventTime),
    PurchaseEvent(uniqueTransactionId: 't', value: 1, cart: const [], customProps: customProps, eventTime: eventTime),
    AddToWishlistEvent(value: 1, productId: 'p', customProps: customProps, eventTime: eventTime),
    SignUpEvent(cuid: 'c', customProps: customProps, eventTime: eventTime),
    LoginEvent(cuid: 'c', customProps: customProps, eventTime: eventTime),
    CustomEvent(type: 'x', name: 'X', customProps: customProps, eventTime: eventTime),
  ];

  test('every event sends customProps and eventTime when set', () {
    for (final event in typedEvents(customProps: props, eventTime: localTime)) {
      final json = wire(event);
      expect(json['customProps'], props, reason: event.type);
      expect(json['eventTime'], localTime.toUtc().toIso8601String(), reason: event.type);
      expect(json['eventTime'], endsWith('Z'), reason: event.type);
      expect(json['type'], event.type);
    }
  });

  test('unset customProps and eventTime are omitted, not sent as null', () {
    for (final event in typedEvents()) {
      final json = wire(event);
      expect(json.containsKey('customProps'), isFalse, reason: event.type);
      expect(json.containsKey('eventTime'), isFalse, reason: event.type);
    }
  });

  test('typed fields still serialize next to customProps', () {
    final json = wire(AddToCartEvent(value: 99.5, productId: 'sku-1', quantity: 2, currency: 'RUB', customProps: props));
    expect(json, {
      'value': 99.5,
      'productId': 'sku-1',
      'quantity': 2,
      'currency': 'RUB',
      'cart': null,
      'type': 'add-to-cart-v1',
      'name': 'Add to Cart',
      'customProps': props,
    });
  });

  test('CustomEvent carries cuid, cuidType, cart and eventTime', () {
    final json = wire(CustomEvent(
      type: 'loyalty-v1',
      name: 'Loyalty',
      cuid: 'user@example.com',
      cuidType: 'email',
      cart: const [CartItem(productId: 'sku-1', quantity: 2, itemPrice: 10.5)],
      customProps: props,
      eventTime: DateTime.utc(2026, 9, 3, 9, 0),
    ));
    expect(json, {
      'type': 'loyalty-v1',
      'name': 'Loyalty',
      'cuid': 'user@example.com',
      'cuidType': 'email',
      'cart': [
        {'productId': 'sku-1', 'quantity': 2, 'itemPrice': 10.5},
      ],
      'customProps': props,
      'eventTime': '2026-09-03T09:00:00.000Z',
    });
  });

  test('CustomEvent without the new fields is unchanged on the wire', () {
    expect(wire(CustomEvent(type: 'x', name: 'X')), {'type': 'x', 'name': 'X'});
  });
}
