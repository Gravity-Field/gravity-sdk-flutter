import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/inline/inline_from_content.dart';

import '../../models/internal/campaign_content.dart';

class GravityInlineWidget extends StatefulWidget {
  final String selector;
  final double? width;
  final double? height;

  const GravityInlineWidget({
    super.key,
    required this.selector,
    this.width,
    this.height,
  });

  @override
  State<GravityInlineWidget> createState() => _GravityInlineWidgetState();
}

class _GravityInlineWidgetState extends State<GravityInlineWidget> {
  bool isLoading = true;
  CampaignContent? content;
  Campaign? campaign;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() async {
    final response = await GravitySDK.instance.getContentBySelector(selector: widget.selector);
    final campaign = response.data.first;
    final content = campaign.payload.first.contents.first;
    setState(() {
      this.content = content;
      this.campaign = campaign;
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
          if (content != null && campaign != null) {
            return InlineFromContent(
              content: content!,
              campaign: campaign!,
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
