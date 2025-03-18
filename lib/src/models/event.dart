class Event {
  final String type;
  final List<String> urls;

  Event({required this.type, required this.urls});

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      type: json['type'],
      urls: List<String>.from(json['urls']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'urls': urls,
      };
}
