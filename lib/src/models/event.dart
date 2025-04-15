class Event {
  final String name;
  final List<String> urls;

  Event({required this.name, required this.urls});

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      name: json['name'],
      urls: List<String>.from(json['urls']),
    );
  }
}
