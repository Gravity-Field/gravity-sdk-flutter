import 'event.dart';
import 'item.dart';

class Slot {
  final Item item;
  final bool fallback;
  final int strId;
  final String slotId;
  final List<Event> events;

  Slot({
    required this.item,
    required this.fallback,
    required this.strId,
    required this.slotId,
    required this.events,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      item: Item.fromJson(json['item']),
      fallback: json['fallback'],
      strId: json['strId'],
      slotId: json['slotId'],
      events: (json['events'] as List).map((e) => Event.fromJson(e)).toList(),
    );
  }
}

