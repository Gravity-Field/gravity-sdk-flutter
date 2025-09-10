import 'package:json_annotation/json_annotation.dart';

part 'trigger_event.g.dart';

abstract class TriggerEvent {
  String get type;

  String get name;

  Map<String, dynamic> toJson();
}

@JsonSerializable(createFactory: false, createToJson: true)
class AddToCartEvent extends TriggerEvent {
  final double value;
  final String productId;
  final int quantity;
  final String? currency;
  final List<CartItem>? cart;

  @override
  final String type = 'add-to-cart-v1';
  @override
  final String name = 'Add to Cart';

  AddToCartEvent({
    required this.value,
    required this.productId,
    required this.quantity,
    this.currency,
    this.cart,
  });

  @override
  Map<String, dynamic> toJson() => _$AddToCartEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class PurchaseEvent extends TriggerEvent {
  final String uniqueTransactionId;
  final double value;
  final String? currency;
  final List<CartItem>? cart;

  @override
  final String type = 'purchase-v1';
  @override
  final String name = 'Purchase';

  PurchaseEvent({
    required this.uniqueTransactionId,
    required this.value,
    this.currency,
    this.cart,
  });

  @override
  Map<String, dynamic> toJson() => _$PurchaseEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class RemoveFromCartEvent extends TriggerEvent {
  final double value;
  final String productId;
  final int quantity;
  final String? currency;
  final List<CartItem>? cart;

  @override
  final String type = 'remove-from-cart-v1';
  @override
  final String name = 'Remove from Cart';

  RemoveFromCartEvent({
    required this.value,
    required this.productId,
    required this.quantity,
    this.currency,
    this.cart,
  });

  @override
  Map<String, dynamic> toJson() => _$RemoveFromCartEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class SyncCartEvent extends TriggerEvent {
  final String? currency;
  final List<CartItem>? cart;

  @override
  final String type = 'sync-cart-v1';
  @override
  final String name = 'Sync cart';

  SyncCartEvent({
    this.currency,
    this.cart,
  });

  @override
  Map<String, dynamic> toJson() => _$SyncCartEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class AddToWishlistEvent extends TriggerEvent {
  final String productId;

  @override
  final String type = 'add-to-wishlist-v1';
  @override
  final String name = 'Add to Wishlist';

  AddToWishlistEvent({required this.productId});

  @override
  Map<String, dynamic> toJson() => _$AddToWishlistEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class SignUpEvent extends TriggerEvent {
  final String hashedEmail;
  final String cuid;
  final String cuidType;

  @override
  final String type = 'signup-v1';
  @override
  final String name = 'Signup';

  SignUpEvent({
    required this.hashedEmail,
    required this.cuid,
    required this.cuidType,
  });

  @override
  Map<String, dynamic> toJson() => _$SignUpEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class LoginEvent extends TriggerEvent {
  final String? hashedEmail;
  final String? cuid;
  final String? cuidType;

  @override
  final String type = 'login-v1';
  @override
  final String name = 'Login';

  LoginEvent({
    this.hashedEmail,
    this.cuid,
    this.cuidType,
  });

  @override
  Map<String, dynamic> toJson() => _$LoginEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class CustomEvent extends TriggerEvent {
  @override
  final String type;
  @override
  final String name;
  final Map<String, String>? customProps;

  CustomEvent({
    required this.type,
    required this.name,
    this.customProps,
  });

  @override
  Map<String, dynamic> toJson() => _$CustomEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class CartItem {
  final String productId;
  final int quantity;
  final double itemPrice;

  const CartItem({
    required this.productId,
    required this.quantity,
    required this.itemPrice,
  });

  Map<String, dynamic> toJson() => _$CartItemToJson(this);
}
