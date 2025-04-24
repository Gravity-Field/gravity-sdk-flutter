import 'frame_ui.dart';
import 'element.dart';
import 'action.dart';

class Variables {
  final FrameUI? frameUI;
  final List<Element> elements;
  final Action? onLoad;
  final Action? onImpression;
  final Action? onVisibleImpression;
  final Action? onClose;

  Variables({
    required this.frameUI,
    required this.elements,
    this.onLoad,
    this.onImpression,
    this.onVisibleImpression,
    this.onClose,
  });

  factory Variables.fromJson(Map<String, dynamic> json) {
    return Variables(
      frameUI: json['frameUI'] != null ? FrameUI.fromJson(json['frameUI']) : null,
      elements: (json['elements'] as List).map((e) => Element.fromJson(e)).toList(),
      onLoad: json['onLoad'] != null ? Action.fromJson(json['onLoad']) : null,
      onImpression: json['onImpression'] != null ? Action.fromJson(json['onImpression']) : null,
      onVisibleImpression: json['onVisibleImpression'] != null ? Action.fromJson(json['onVisibleImpression']) : null,
      onClose: json['onClose'] != null ? Action.fromJson(json['onClose']) : null,
    );
  }
}
