import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/inline/inline_content.dart';

import '../../models/internal/campaign_content.dart';

class GravityInlineWidget extends StatefulWidget {
  final String selector;
  final double? width;
  final double? height;
  final PageContext pageContext;
  final bool showLoading;

  const GravityInlineWidget({
    super.key,
    required this.selector,
    this.width,
    this.height,
    required this.pageContext,
    this.showLoading = true,
  });

  @override
  State<GravityInlineWidget> createState() => _GravityInlineWidgetState();
}

class _GravityInlineWidgetState extends State<GravityInlineWidget> {
  bool isLoading = true;
  bool isFailure = false;

  CampaignContent? content;
  Campaign? campaign;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() async {
    try {
      final response = await GravitySDK.instance.getContentBySelector(
        selector: widget.selector,
        pageContext: widget.pageContext,
      );
      final campaign = response.data.first;
      final content = campaign.payload.first.contents.first;
      setState(() {
        this.content = content;
        this.campaign = campaign;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isFailure = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isFailure) {
      return SizedBox.shrink();
    }

    Widget? child;

    if (isLoading && widget.showLoading) {
      child = Center(
        child: CircularProgressIndicator(),
      );
    } else if (content != null && campaign != null) {
      child = InlineContent(
        content: content!,
        campaign: campaign!,
      );
    }

    if (widget.width != null || widget.height != null) {
      child = SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      );
    }

    return child ?? SizedBox.shrink();
  }
}
