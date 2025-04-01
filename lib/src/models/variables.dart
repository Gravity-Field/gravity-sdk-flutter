import 'close.dart';
import 'frame_ui.dart';
import 'style.dart';
import 'element.dart';

class Variables {
  final FrameUI frameUI;
  final List<GravityElement> elements;

  Variables({required this.frameUI, required this.elements});

  factory Variables.fromJson(Map<String, dynamic> json) {
    return Variables(
      frameUI: FrameUI.fromJson(json['frameUI']),
      elements: (json['elements'] as List).map((e) => GravityElement.fromJson(e)).toList(),
    );
  }
}
