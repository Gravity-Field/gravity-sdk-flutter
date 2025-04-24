class Action {
  final String action;

  Action({required this.action});

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      action: json['action'],
    );
  }
}