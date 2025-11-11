import 'package:flutter/material.dart' hide Element;
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/internal/element.dart';

class GravityWebView extends StatefulWidget {
  final Element element;

  const GravityWebView({super.key, required this.element});

  @override
  State<GravityWebView> createState() => _GravityWebViewState();
}

class _GravityWebViewState extends State<GravityWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.element.src ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.element.style;

    Widget webviewWidget = ClipRRect(
      borderRadius: BorderRadius.circular(style?.cornerRadius ?? 0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: WebViewWidget(controller: _controller),
      ),
    );

    if (style?.margin != null) {
      webviewWidget = Padding(
        padding: EdgeInsets.only(
          left: style!.margin!.left,
          right: style.margin!.right,
          top: style.margin!.top,
          bottom: style.margin!.bottom,
        ),
        child: webviewWidget,
      );
    }

    return webviewWidget;
  }
}
