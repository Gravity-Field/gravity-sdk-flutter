import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class EventPropsButton extends StatefulWidget {
  const EventPropsButton({super.key, required this.pageContext});

  final PageContext pageContext;

  @override
  State<EventPropsButton> createState() => _EventPropsButtonState();
}

class _EventPropsButtonState extends State<EventPropsButton> {
  int _request = 0;
  String _status = 'Кампания ещё не запрошена';
  List<CampaignContent> _contents = const [];

  Future<void> _send({required bool trackView}) async {
    final request = ++_request;
    setState(() {
      _status = 'Загрузка кампании…';
      _contents = const [];
    });
    final response = trackView
        ? await GravitySDK.instance.trackViewNoShow(
            pageContext: widget.pageContext,
          )
        : await GravitySDK.instance.triggerEventNoShow(
            pageContext: widget.pageContext,
            events: [
              AddToCartEvent(
                value: 99.99,
                productId: 'sku-123',
                quantity: 1,
                currency: 'RUB',
                customProps: const {'list': 'search'},
                eventTime: DateTime.now(),
              ),
              CustomEvent(
                type: 'loyalty-v1',
                name: 'Loyalty',
                cuid: 'user@example.com',
                cuidType: 'email',
                cart: const [
                  CartItem(productId: 'sku-123', quantity: 1, itemPrice: 99.99),
                ],
                customProps: const {'points': '150'},
                eventTime: DateTime.now(),
              ),
            ],
          );
    if (!mounted || request != _request) return;
    if (response == null) {
      setState(() => _status = 'Кампании нет');
      return;
    }
    // Headless: the SDK returns right away. The app owns both the delay
    // and the UI built from the returned campaign content.
    setState(() => _status = 'Ожидание: ${response.delayTime} мс…');
    await Future<void>.delayed(Duration(milliseconds: response.delayTime));
    if (!mounted || request != _request) return;
    setState(() {
      _contents = [
        for (final campaign in response.data.data)
          for (final payload in campaign.payload) ...payload.contents,
      ];
      _status = _contents.isEmpty
          ? 'Кампании нет'
          : 'Кампания показана приложением';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Показ кампании приложением',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          OutlinedButton(
            onPressed: () => _send(trackView: true),
            child: const Text('Запросить кампанию просмотра'),
          ),
          FilledButton(
            onPressed: () => _send(trackView: false),
            child: const Text('Отправить события с customProps'),
          ),
          if (_status.isNotEmpty) Text(_status),
          // This is ordinary app-owned Flutter UI, not an SDK renderer.
          for (final content in _contents)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.variables.title ?? 'Содержимое кампании',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final text
                        in content.variables.elements
                                ?.map((element) => element.text)
                                .whereType<String>() ??
                            const <String>[])
                      Text(text),
                    // Custom variables are useful for content without text elements.
                    for (final entry in content.rawVariables.entries)
                      if (!const {
                        'title',
                        'elements',
                        'frameUI',
                        'onLoad',
                        'onImpression',
                        'onVisibleImpression',
                        'onClose',
                        'index',
                        'tooltipConfig',
                        'positioning',
                      }.contains(entry.key))
                        Text('${entry.key}: ${jsonEncode(entry.value)}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
