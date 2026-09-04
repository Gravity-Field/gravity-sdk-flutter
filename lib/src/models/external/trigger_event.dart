import 'package:json_annotation/json_annotation.dart';

part 'trigger_event.g.dart';

abstract class TriggerEvent {
  /// Extra properties sent alongside the typed fields. String values only.
  @JsonKey(includeIfNull: false)
  final Map<String, String>? customProps;

  /// When the event happened; sent in UTC. Omitted, the server uses receipt time.
  @JsonKey(includeIfNull: false, toJson: _eventTimeToJson)
  final DateTime? eventTime;

  TriggerEvent({this.customProps, this.eventTime});

  String get type;

  String get name;

  Map<String, dynamic> toJson();
}

String? _eventTimeToJson(DateTime? time) => time?.toUtc().toIso8601String();

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
    super.customProps,
    super.eventTime,
  });

  @override
  Map<String, dynamic> toJson() => _$AddToCartEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class PurchaseEvent extends TriggerEvent {
  final String uniqueTransactionId;
  final double value;
  final String? currency;
  final List<CartItem> cart;

  @override
  final String type = 'purchase-v1';
  @override
  final String name = 'Purchase';

  PurchaseEvent({
    required this.uniqueTransactionId,
    required this.value,
    required this.cart,
    this.currency,
    super.customProps,
    super.eventTime,
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
    super.customProps,
    super.eventTime,
  });

  @override
  Map<String, dynamic> toJson() => _$RemoveFromCartEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class SyncCartEvent extends TriggerEvent {
  final double value;
  final String? currency;
  final List<CartItem>? cart;

  @override
  final String type = 'sync-cart-v1';
  @override
  final String name = 'Sync cart';

  SyncCartEvent({
    required this.value,
    this.currency,
    this.cart,
    super.customProps,
    super.eventTime,
  });

  @override
  Map<String, dynamic> toJson() => _$SyncCartEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class AddToWishlistEvent extends TriggerEvent {
  final double value;
  final String productId;

  @override
  final String type = 'add-to-wishlist-v1';
  @override
  final String name = 'Add to Wishlist';

  AddToWishlistEvent({
    required this.value,
    required this.productId,
    super.customProps,
    super.eventTime,
  });

  @override
  Map<String, dynamic> toJson() => _$AddToWishlistEventToJson(this);
}

@JsonSerializable(createFactory: false, createToJson: true)
class SignUpEvent extends TriggerEvent {
  final String? hashedEmail;
  final String? cuid;
  final String? cuidType;

  @override
  final String type = 'signup-v1';
  @override
  final String name = 'Signup';

  SignUpEvent({
    this.hashedEmail,
    this.cuid,
    this.cuidType,
    super.customProps,
    super.eventTime,
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
    super.customProps,
    super.eventTime,
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
  @JsonKey(includeIfNull: false)
  final String? cuid;
  @JsonKey(includeIfNull: false)
  final String? cuidType;
  @JsonKey(includeIfNull: false)
  final List<CartItem>? cart;

  CustomEvent({
    required this.type,
    required this.name,
    this.cuid,
    this.cuidType,
    this.cart,
    super.customProps,
    super.eventTime,
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
