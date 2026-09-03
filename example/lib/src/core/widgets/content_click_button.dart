import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class ContentClickButton extends StatefulWidget {
  const ContentClickButton({
    super.key,
    required this.selector,
    required this.pageContext,
  });

  final String selector;
  final PageContext pageContext;

  @override
  State<ContentClickButton> createState() => _ContentClickButtonState();
}

class _ContentClickButtonState extends State<ContentClickButton> {
  late final Future<(Campaign, CampaignContent)?> _loaded = _load();

  Future<(Campaign, CampaignContent)?> _load() async {
    final response = await GravitySDK.instance.getContentBySelectorWithDetails(
      selector: widget.selector,
      pageContext: widget.pageContext,
    );
    final campaign = response.data.data.firstOrNull;
    final content = campaign?.payload.firstOrNull?.contents.firstOrNull;
    if (campaign == null || content == null) return null;
    return (campaign, content);
  }

  Future<void> _sendClick() async {
    final loaded = await _loaded;
    if (loaded == null) return;
    final (campaign, content) = loaded;
    GravitySDK.instance.sendContentEngagement(ContentClickEngagement(content, campaign));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: _sendClick,
        child: const Text('Отправить content click'),
      ),
    );
  }
}
