import 'package:flutter/material.dart';

class AnchorData {
  final GlobalKey key;
  final LayerLink layerLink;

  AnchorData({required this.key, required this.layerLink});
}

class AnchorRegistry {
  AnchorRegistry._();
  static final AnchorRegistry instance = AnchorRegistry._();

  final Map<String, AnchorData> _anchors = {};

  void register(String selector, GlobalKey key, LayerLink layerLink) {
    _anchors[selector] = AnchorData(key: key, layerLink: layerLink);
  }

  void unregister(String selector) {
    _anchors.remove(selector);
  }

  AnchorData? getAnchorData(String selector) {
    return _anchors[selector];
  }

  LayerLink? getLayerLink(String selector) {
    return _anchors[selector]?.layerLink;
  }

  GlobalKey? getKey(String selector) {
    return _anchors[selector]?.key;
  }

  RenderBox? getRenderBox(String selector) {
    final key = _anchors[selector]?.key;
    final context = key?.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject;
    }
    return null;
  }

  Rect? getAnchorRect(String selector) {
    final renderBox = getRenderBox(selector);
    if (renderBox == null || !renderBox.hasSize) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  Size? getAnchorSize(String selector) {
    final renderBox = getRenderBox(selector);
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.size;
  }

  bool hasAnchor(String selector) {
    return _anchors.containsKey(selector);
  }

  void clear() {
    _anchors.clear();
  }
}
