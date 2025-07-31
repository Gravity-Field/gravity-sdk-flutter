import 'package:gravity_sdk/src/models/actions/product_event.dart';
import 'package:json_annotation/json_annotation.dart';

import 'item.dart';

part 'slot.g.dart';

@JsonSerializable()
class Slot {
  final Item item;
  final bool fallback;
  final int strId;
  final String slotId;
  final List<ProductEvent>? events;

  Slot({
    required this.item,
    required this.fallback,
    required this.strId,
    required this.slotId,
    this.events,
  });

  factory Slot.fromJson(Map<String, dynamic> json) => _$SlotFromJson(json);
}

