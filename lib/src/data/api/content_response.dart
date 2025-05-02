

import '../../models/external/user.dart';
import '../../models/internal/payload.dart';

class ContentResponse {
  final User user;
  final List<DataItem> data;

  ContentResponse({required this.user, required this.data});

  factory ContentResponse.fromJson(Map<String, dynamic> json) {
    return ContentResponse(
      user: User.fromJson(json['user']),
      data: (json['data'] as List).map((e) => DataItem.fromJson(e)).toList(),
    );
  }
}

class DataItem {
  final String selector;
  final List<Payload> payload;

  DataItem({required this.selector, required this.payload});

  factory DataItem.fromJson(Map<String, dynamic> json) {
    return DataItem(
      selector: json['selector'],
      payload: (json['payload'] as List).map((e) => Payload.fromJson(e)).toList(),
    );
  }
}




