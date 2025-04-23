import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/inline/inline_from_content.dart';

import '../../models/content.dart';
import '../../utils/element_utils.dart';

class GravityInlineWidget extends StatefulWidget {
  final String templateId;
  final double? width;
  final double? height;

  const GravityInlineWidget({
    super.key,
    required this.templateId,
    this.width,
    this.height,
  });

  @override
  State<GravityInlineWidget> createState() => _GravityInlineWidgetState();
}

class _GravityInlineWidgetState extends State<GravityInlineWidget> {
  bool isLoading = true;
  Content? content;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() async {
    final response = await GravitySDK.instance.getContent(widget.templateId);
    final content = response.data.first.payload.first.contents.first;
    setState(() {
      this.content = content;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Builder(
        builder: (context) {
          if (content != null) {
            return InlineFromContent(
              content: content!,
            );
          }

          return Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}
