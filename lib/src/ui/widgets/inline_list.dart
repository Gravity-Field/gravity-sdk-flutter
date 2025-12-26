import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/inline/inline_content.dart';

class GravityInlineListWidget extends StatefulWidget {
  final String group;
  final double? height;
  final PageContext pageContext;
  final bool showLoading;
  final Widget? loadingWidget;
  final bool showIndicator;
  final Color? indicatorActiveColor;
  final Color? indicatorInactiveColor;

  const GravityInlineListWidget({
    super.key,
    required this.group,
    this.height,
    required this.pageContext,
    this.showLoading = true,
    this.loadingWidget,
    this.showIndicator = true,
    this.indicatorActiveColor,
    this.indicatorInactiveColor,
  });

  @override
  State<GravityInlineListWidget> createState() => _GravityInlineListWidgetState();
}

class _GravityInlineListWidgetState extends State<GravityInlineListWidget> {
  bool isLoading = true;
  bool isFailure = false;

  List<_CampaignItem> items = [];
  int currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadContent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadContent() async {
    try {
      final response = await GravitySDK.instance.getContentByGroup(
        group: widget.group,
        pageContext: widget.pageContext,
      );

      final loadedItems = <_CampaignItem>[];

      for (final campaign in response.data) {
        final allContents = campaign.payload.expand((payload) => payload.contents).toList();

        for (final content in allContents) {
          if (_isContentValid(content)) {
            loadedItems.add(_CampaignItem(campaign: campaign, content: content));
          }
        }
      }

      if (loadedItems.isEmpty) {
        _setFailureState();
        return;
      }

      loadedItems.sort((a, b) {
        final indexA = a.content.variables.index ?? 0;
        final indexB = b.content.variables.index ?? 0;
        return indexA.compareTo(indexB);
      });

      setState(() {
        items = loadedItems;
        isLoading = false;
      });
    } catch (e) {
      _setFailureState();
    }
  }

  bool _isContentValid(CampaignContent content) {
    if (content.products == null) return true;

    final slots = content.products!.slots;
    return slots != null && slots.isNotEmpty;
  }

  void _setFailureState() {
    setState(() {
      isLoading = false;
      isFailure = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFailure) {
      return const SizedBox.shrink();
    }

    if (isLoading && widget.showLoading) {
      return SizedBox(
        height: widget.height ?? 200,
        child: widget.loadingWidget ?? const Center(child: CircularProgressIndicator()),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height ?? 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) {
              setState(() {
                currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final item = items[index];
              return InlineContent(content: item.content, campaign: item.campaign);
            },
          ),
        ),
        if (widget.showIndicator && items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PageIndicator(
              count: items.length,
              currentIndex: currentPage,
              activeColor: widget.indicatorActiveColor ?? Theme.of(context).primaryColor,
              inactiveColor: widget.indicatorInactiveColor ?? Colors.grey.shade300,
            ),
          ),
      ],
    );
  }
}

class _CampaignItem {
  final Campaign campaign;
  final CampaignContent content;

  _CampaignItem({required this.campaign, required this.content});
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  const _PageIndicator({
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
