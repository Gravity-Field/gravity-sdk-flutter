// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trigger_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$AddToCartEventToJson(AddToCartEvent instance) =>
    <String, dynamic>{
      'value': instance.value,
      'productId': instance.productId,
      'quantity': instance.quantity,
      'currency': instance.currency,
      'cart': instance.cart,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$PurchaseEventToJson(PurchaseEvent instance) =>
    <String, dynamic>{
      'uniqueTransactionId': instance.uniqueTransactionId,
      'value': instance.value,
      'currency': instance.currency,
      'cart': instance.cart,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$RemoveFromCartEventToJson(
        RemoveFromCartEvent instance) =>
    <String, dynamic>{
      'value': instance.value,
      'productId': instance.productId,
      'quantity': instance.quantity,
      'currency': instance.currency,
      'cart': instance.cart,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$SyncCartEventToJson(SyncCartEvent instance) =>
    <String, dynamic>{
      'value': instance.value,
      'currency': instance.currency,
      'cart': instance.cart,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$AddToWishlistEventToJson(AddToWishlistEvent instance) =>
    <String, dynamic>{
      'value': instance.value,
      'productId': instance.productId,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$SignUpEventToJson(SignUpEvent instance) =>
    <String, dynamic>{
      'hashedEmail': instance.hashedEmail,
      'cuid': instance.cuid,
      'cuidType': instance.cuidType,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$LoginEventToJson(LoginEvent instance) =>
    <String, dynamic>{
      'hashedEmail': instance.hashedEmail,
      'cuid': instance.cuid,
      'cuidType': instance.cuidType,
      'type': instance.type,
      'name': instance.name,
    };

Map<String, dynamic> _$CustomEventToJson(CustomEvent instance) =>
    <String, dynamic>{
      'type': instance.type,
      'name': instance.name,
      'customProps': instance.customProps,
    };

Map<String, dynamic> _$CartItemToJson(CartItem instance) => <String, dynamic>{
      'productId': instance.productId,
      'quantity': instance.quantity,
      'itemPrice': instance.itemPrice,
    };
