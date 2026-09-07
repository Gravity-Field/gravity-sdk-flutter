import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

/// Shows the raw `variables` keys of a campaign and the values of the keys
/// that have no typed counterpart in [Variables].
class RawVariablesView extends StatefulWidget {
  const RawVariablesView({
    super.key,
    required this.selector,
    required this.pageContext,
  });

  final String selector;
  final PageContext pageContext;

  @override
  State<RawVariablesView> createState() => _RawVariablesViewState();
}

class _RawVariablesViewState extends State<RawVariablesView> {
  static const _typedKeys = {
    'frameUI',
    'elements',
    'title',
    'onLoad',
    'onImpression',
    'onVisibleImpression',
    'onClose',
    'index',
    'tooltipConfig',
    'positioning',
  };

  late final Future<CampaignContent?> _content = _load();

  Future<CampaignContent?> _load() async {
    final response = await GravitySDK.instance.getContentBySelectorWithDetails(
      selector: widget.selector,
      pageContext: widget.pageContext,
    );
    return response.data.data.firstOrNull?.payload.firstOrNull?.contents.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
    return FutureBuilder<CampaignContent?>(
      future: _content,
      builder: (context, snapshot) {
        final content = snapshot.data;
        if (content == null) return const SizedBox.shrink();
        final raw = content.rawVariables;
        final custom = raw.keys.where((k) => !_typedKeys.contains(k)).toList();
        return Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variables', style: Theme.of(context).textTheme.titleSmall),
                  Text('selector: ${widget.selector}', style: mono),
                  Text('all keys: ${raw.keys.join(', ')}', style: mono),
                  Text(custom.isEmpty ? 'custom keys: none' : 'custom keys:', style: mono),
                  for (final key in custom) Text('  $key = ${jsonEncode(raw[key])}', style: mono),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
