// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Slot _$SlotFromJson(Map<String, dynamic> json) => Slot(
      item: Item.fromJson(json['item'] as Map<String, dynamic>),
      fallback: json['fallback'] as bool,
      strId: (json['strId'] as num).toInt(),
      slotId: json['slotId'] as String,
      events: (json['events'] as List<dynamic>)
          .map((e) => ProductEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
