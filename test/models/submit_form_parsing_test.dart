import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/form_action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';

Map<String, dynamic> validSubmit() => {
  'action': 'submit_form',
  'closeOnClick': false,
  'event': {'type': 'in-app-review-v1', 'name': 'In-app review submitted'},
  'routes': [
    {
      'when': {'attributeName': 'rating', 'operator': 'more_or_equal', 'value': 4},
      'do': [
        {'effect': 'open_url', 'url': 'https://store.example'},
      ],
    },
  ],
  'default': {
    'do': [
      {'effect': 'close'},
    ],
  },
};

void main() {
  test('valid submit_form parses fully', () {
    final o = OnClick.fromJson(validSubmit());
    expect(o.action, Action.submitForm);
    expect(o.event!.type, 'in-app-review-v1');
    expect(o.routes, hasLength(1));
    expect(o.routes!.single.when, isNotNull);
    expect(o.routes!.single.effects.single.effect, FormEffectType.openUrl);
    expect(o.defaultRoute!.effects.single.effect, FormEffectType.close);
  });
  group('follow_url effect (новое имя open_url с type)', () {
    Map<String, dynamic> withRouteEffect(Map<String, dynamic> effect) => {
      ...validSubmit(),
      'routes': [
        {
          'when': {'attributeName': 'rating', 'operator': 'more_or_equal', 'value': 4},
          'do': [effect],
        },
      ],
    };

    test('parses url and webview type', () {
      final o = OnClick.fromJson(
        withRouteEffect(
          {'effect': 'follow_url', 'type': 'webview', 'url': 'https://example.com'},
        ),
      );
      expect(o.action, Action.submitForm);
      final effect = o.routes!.single.effects.single;
      expect(effect.effect, FormEffectType.openUrl);
      expect(effect.url, 'https://example.com');
      expect(effect.urlType, FollowUrlType.webview);
    });
    test('browser type parses', () {
      final o = OnClick.fromJson(
        withRouteEffect(
          {'effect': 'follow_url', 'type': 'browser', 'url': 'https://example.com'},
        ),
      );
      expect(o.routes!.single.effects.single.urlType, FollowUrlType.browser);
    });
    test('absent, unknown and non-string type resolve to browser', () {
      for (final effect in [
        {'effect': 'follow_url', 'url': 'https://example.com'},
        {'effect': 'follow_url', 'type': 'external', 'url': 'https://example.com'},
        {'effect': 'follow_url', 'type': 7, 'url': 'https://example.com'},
      ]) {
        final o = OnClick.fromJson(withRouteEffect(effect));
        expect(o.action, Action.submitForm, reason: 'type must not break decoding: $effect');
        expect(o.routes!.single.effects.single.urlType, FollowUrlType.browser);
      }
    });
    test('follow_url without url demotes the whole onClick', () {
      final o = OnClick.fromJson(
        withRouteEffect(
          {'effect': 'follow_url', 'type': 'browser'},
        ),
      );
      expect(o.action, Action.unknown);
    });
    test('legacy open_url keeps browser type', () {
      final o = OnClick.fromJson(validSubmit());
      expect(o.routes!.single.effects.single.urlType, FollowUrlType.browser);
    });
  });
  test('submit_form without routes is valid (default only)', () {
    final o = OnClick.fromJson(validSubmit()..remove('routes'));
    expect(o.action, Action.submitForm);
    expect(o.routes, isEmpty);
  });
  group('structural violation -> whole onClick unknown', () {
    final cases = <String, Map<String, dynamic>>{
      'missing default': validSubmit()..remove('default'),
      'empty default do': {
        ...validSubmit(),
        'default': {'do': []},
      },
      'route without when': {
        ...validSubmit(),
        'routes': [
          {
            'do': [
              {'effect': 'close'},
            ],
          },
        ],
      },
      'route with v2 operator': {
        ...validSubmit(),
        'routes': [
          {
            'when': {'attributeName': 'r', 'operator': 'contains', 'value': 'x'},
            'do': [
              {'effect': 'close'},
            ],
          },
        ],
      },
      'route with empty do': {
        ...validSubmit(),
        'routes': [
          {
            'when': {'attributeName': 'r', 'operator': 'is_empty'},
            'do': [],
          },
        ],
      },
      'unknown effect': {
        ...validSubmit(),
        'default': {
          'do': [
            {'effect': 'request_review'},
          ],
        },
      },
      'open_url without url': {
        ...validSubmit(),
        'routes': [
          {
            'when': {'attributeName': 'r', 'operator': 'is_empty'},
            'do': [
              {'effect': 'open_url'},
            ],
          },
        ],
      },
      'fractional step': {
        ...validSubmit(),
        'default': {
          'do': [
            {'effect': 'open_step', 'step': 1.7},
          ],
        },
      },
      'open_step not last': {
        ...validSubmit(),
        'default': {
          'do': [
            {'effect': 'open_step', 'step': 2},
            {'effect': 'close'},
          ],
        },
      },
      'missing event name': {
        ...validSubmit(),
        'event': {'type': 'x'},
      },
      'empty event type': {
        ...validSubmit(),
        'event': {'type': '', 'name': 'y'},
      },
    };
    cases.forEach((name, json) {
      test(name, () => expect(OnClick.fromJson(json).action, Action.unknown));
    });
  });
  test('legacy onClick untouched', () {
    final o = OnClick.fromJson({'action': 'close'});
    expect(o.action, Action.close);
    expect(o.event, isNull);
    expect(o.defaultRoute, isNull);
  });
}
