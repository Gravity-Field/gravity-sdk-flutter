import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/inline/inline_content.dart';

class GravityInlineWidget extends StatefulWidget {
  final String selector;
  final String? placeholderId;
  final double? width;
  final double? height;
  final PageContext pageContext;
  final bool showLoading;
  final Widget? loadingWidget;

  const GravityInlineWidget({
    super.key,
    required this.selector,
    this.placeholderId,
    this.width,
    this.height,
    required this.pageContext,
    this.showLoading = true,
    this.loadingWidget,
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

      final allContents = campaign.payload.expand((payload) => payload.contents).toList();

      if (allContents.isEmpty) {
        _setFailureState();
        return;
      }

      final selectedContent = _selectContent(allContents);
      if (selectedContent == null) {
        _setFailureState();
        return;
      }

      if (!_isContentValid(selectedContent)) {
        _setFailureState();
        return;
      }

      if (!mounted) return;
      setState(() {
        content = selectedContent;
        this.campaign = campaign;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      ErrorReporter.instance.report(
        message: e.toString(),
        level: 'error',
        section: 'GravityInlineWidget._loadContent',
        stacktrace: stackTrace.toString(),
        extra: {'selector': widget.selector},
        tags: {'category': 'ui'},
      );
      _setFailureState();
    }
  }

  /// Select content based on placeholderId.
  ///
  /// If placeholderId is provided, returns content with matching placeholderId.
  /// If placeholderId is not provided, returns content without placeholderId.
  CampaignContent? _selectContent(List<CampaignContent> contents) {
    if (widget.placeholderId != null) {
      return contents.where((content) => content.placeholderId == widget.placeholderId).firstOrNull;
    }

    return contents.where((content) => content.placeholderId == null).firstOrNull;
  }

  /// Validate if content should be rendered.
  ///
  /// Returns false if content has products but no slots (empty product list).
  bool _isContentValid(CampaignContent content) {
    if (content.products == null) return true;

    final slots = content.products!.slots;
    return slots != null && slots.isNotEmpty;
  }

  void _setFailureState() {
    if (!mounted) return;
    setState(() {
      isLoading = false;
      isFailure = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFailure) {
      return SizedBox.shrink();
    }

    Widget? child;

    if (isLoading && widget.showLoading) {
      child = widget.loadingWidget ?? Center(child: CircularProgressIndicator());
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
