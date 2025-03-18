
class User {
  final String uid;
  final String ses;

  User({required this.uid, required this.ses});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'],
      ses: json['ses'],
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'ses': ses,
  };
}
