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

class FrameUI {
  final Container container;

  const FrameUI({
    required this.container,
  });

  factory FrameUI.fromJson(Map<String, dynamic> json) {
    return FrameUI(container: Container.fromJson(json['container']));
  }
}

class Container {
  final Style style;

  Container({required this.style});

  factory Container.fromJson(Map<String, dynamic> json) {
    return Container(
      style: Style.fromJson(json['style']),
    );
  }
}

