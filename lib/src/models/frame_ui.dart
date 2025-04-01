import 'close.dart';
import 'container.dart';

class FrameUI {
  final Container container;
  final Close? close;

  const FrameUI({
    required this.container,
    required this.close,
  });

  factory FrameUI.fromJson(Map<String, dynamic> json) {
    return FrameUI(
      container: Container.fromJson(json['container']),
      close: json['close'] != null ? Close.fromJson(json['close']) : null,
    );
  }
}
