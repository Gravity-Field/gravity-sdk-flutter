import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/external/content_settings.dart';
import 'package:gravity_sdk/src/models/external/options.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/rt_rule.dart';
import 'package:gravity_sdk/src/models/external/rt_rule_condition.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:gravity_sdk/src/repos/choose_batch_keys.dart';

PageContext ctx({
  String location = '/home',
  Map<String, Object> attributes = const {},
  ContextType type = ContextType.other,
}) => PageContext(type: type, data: const [], location: location, attributes: attributes);

Map<String, dynamic> request({
  String? selector,
  String? campaignId,
  PageContext? context,
  ContentSettings contentSettings = const ContentSettings(),
  Options options = const Options(),
  User? user,
  List<RtRule>? rules,
}) => {
  if (selector != null) 'selector': selector,
  if (campaignId != null) 'campaignId': campaignId,
  'context': context ?? ctx(),
  'contentSettings': contentSettings,
  'options': options,
  'user': user,
  if (rules != null) 'rules': rules,
};

void main() {
  group('chooseTypedIdentifier', () {
    test('prefixes selector and campaignId so equal values never collide', () {
      expect(chooseTypedIdentifier(request(selector: 'x')), 'sel:x');
      expect(chooseTypedIdentifier(request(campaignId: 'x')), 'cid:x');
      expect(
        chooseTypedIdentifier(request(selector: 'x')),
        isNot(chooseTypedIdentifier(request(campaignId: 'x'))),
      );
    });

    test('throws on a request without selector or campaignId', () {
      expect(() => chooseTypedIdentifier(request()), throwsArgumentError);
      expect(() => chooseDedupKey(request()), throwsArgumentError);
    });
  });

  group('chooseDedupKey', () {
    test('is stable across attribute insertion order', () {
      final a = request(selector: 's', context: ctx(attributes: {'a': '1', 'b': '2'}));
      final b = request(selector: 's', context: ctx(attributes: {'b': '2', 'a': '1'}));

      expect(chooseDedupKey(a), chooseDedupKey(b));
    });

    test('differs when contentSettings differ', () {
      final a = request(selector: 's');
      final b = request(selector: 's', contentSettings: const ContentSettings(skusOnly: true));

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });

    test('differs when options differ', () {
      final a = request(selector: 's');
      final b = request(selector: 's', options: const Options(isReturnCounter: true));

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });

    test('differs when user differs', () {
      final a = request(selector: 's');
      final b = request(selector: 's', user: const User(custom: 'alice', ses: 'ses1'));

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });

    test('differs when rules differ', () {
      final a = request(selector: 's');
      final b = request(selector: 's', rules: [const RtRule(type: 'include', conditions: [])]);

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });

    test('differs between selector and campaignId with the same value', () {
      expect(
        chooseDedupKey(request(selector: 'same')),
        isNot(chooseDedupKey(request(campaignId: 'same'))),
      );
    });

    // Generated toJson leaves nested models (RtRule.conditions) as objects;
    // a toString-based key encoder collapsed all of them to one string.
    test('differs when rule conditions differ', () {
      final a = request(selector: 's', rules: [
        const RtRule(type: 'include', conditions: [RtRuleCondition(field: 'price', arguments: [])]),
      ]);
      final b = request(selector: 's', rules: [
        const RtRule(type: 'include', conditions: [RtRuleCondition(field: 'brand', arguments: [])]),
      ]);

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });

    test('differs across session generations while the group key does not', () {
      final a = {...request(selector: 's'), 'gen': 0};
      final b = {...request(selector: 's'), 'gen': 1};

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
      expect(chooseGroupKey(a), chooseGroupKey(b));
    });

    test('wire-invalid attribute values cannot collide with wire-valid ones', () {
      final dt = DateTime.utc(2026, 1, 1);
      Map<String, dynamic> withAttrs(Map<String, Object> attributes) =>
          request(selector: 's', context: ctx(attributes: attributes));

      expect(
        chooseDedupKey(withAttrs({'a': dt})),
        isNot(chooseDedupKey(withAttrs({'a': dt.toString()}))),
      );
      expect(
        chooseDedupKey(withAttrs({'a': {'x', 'y'}})),
        isNot(chooseDedupKey(withAttrs({'a': ['x', 'y']}))),
      );
      expect(
        chooseDedupKey(withAttrs({'m': {1: 'x'}})),
        isNot(chooseDedupKey(withAttrs({'m': {'1': 'x'}}))),
      );
    });

    test('cyclic attribute structures do not overflow key generation', () {
      final cyclic = <String, Object>{};
      cyclic['self'] = cyclic;

      final key = chooseDedupKey(request(selector: 's', context: ctx(attributes: {'c': cyclic})));

      expect(key, chooseDedupKey(request(selector: 's', context: ctx(attributes: {'c': cyclic}))));
    });

    test('does not throw on non-JSON attribute values and still distinguishes them', () {
      // A DateTime in attributes must fail on the wire (reported), not
      // synchronously inside schedule() during key generation.
      final a = request(selector: 's', context: ctx(attributes: {'ts': DateTime.utc(2026, 1, 1)}));
      final b = request(selector: 's', context: ctx(attributes: {'ts': DateTime.utc(2026, 1, 2)}));

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
      expect(chooseDedupKey(a), chooseDedupKey(a));
    });

    test('does not lose values behind non-string nested map keys', () {
      final a = request(selector: 's', context: ctx(attributes: {'m': {1: 'x'}}));
      final b = request(selector: 's', context: ctx(attributes: {'m': {'1': null}}));

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });

    // The pre-fix key concatenated attributes as 'k=v&k=v', so these two
    // contexts produced identical keys and silently shared one response.
    test('attribute values cannot forge separator collisions', () {
      final a = request(selector: 's', context: ctx(attributes: {'a': '1&b=2'}));
      final b = request(selector: 's', context: ctx(attributes: {'a': '1', 'b': '2'}));

      expect(chooseDedupKey(a), isNot(chooseDedupKey(b)));
    });
  });

  group('chooseGroupKey', () {
    test('ignores identifier, contentSettings and rules', () {
      final a = request(selector: 's1');
      final b = request(
        campaignId: 'c1',
        contentSettings: const ContentSettings(skusOnly: true),
        rules: [const RtRule(type: 'include', conditions: [])],
      );

      expect(chooseGroupKey(a), chooseGroupKey(b));
    });

    test('differs when user differs', () {
      final a = request(selector: 's');
      final b = request(selector: 's', user: const User(custom: 'alice', ses: 'ses1'));

      expect(chooseGroupKey(a), isNot(chooseGroupKey(b)));
    });

    test('differs when context differs', () {
      final a = request(selector: 's', context: ctx(location: '/home'));
      final b = request(selector: 's', context: ctx(location: '/cart'));

      expect(chooseGroupKey(a), isNot(chooseGroupKey(b)));
    });

    test('differs when options differ', () {
      final a = request(selector: 's');
      final b = request(selector: 's', options: const Options(isImplicitPageview: true));

      expect(chooseGroupKey(a), isNot(chooseGroupKey(b)));
    });
  });

  group('session/custom user separation', () {
    test('requests differing only in isSessionUser share neither group nor dedup key', () {
      final custom = request(selector: 's');
      final session = {...request(selector: 's'), 'isSessionUser': true};

      expect(chooseGroupKey(custom), isNot(chooseGroupKey(session)));
      expect(chooseDedupKey(custom), isNot(chooseDedupKey(session)));
    });
  });

  group('key invariant', () {
    // RequestBatcher requires the dedup key to be at least as specific as the
    // group key: two requests deduped together must land in the same batch.
    test('equal dedup keys imply equal group keys', () {
      final variants = <Map<String, dynamic>>[
        request(selector: 's'),
        request(selector: 's', context: ctx(attributes: {'a': '1', 'b': '2'})),
        request(selector: 's', context: ctx(attributes: {'b': '2', 'a': '1'})),
        {...request(selector: 's'), 'isSessionUser': true},
        request(campaignId: 's'),
        request(selector: 's', contentSettings: const ContentSettings(skusOnly: true)),
        request(selector: 's', options: const Options(isReturnCounter: true)),
        request(selector: 's', user: const User(custom: 'alice', ses: 'ses1')),
        request(selector: 's', rules: [const RtRule(type: 'include', conditions: [])]),
      ];

      for (final a in variants) {
        for (final b in variants) {
          if (chooseDedupKey(a) == chooseDedupKey(b)) {
            expect(chooseGroupKey(a), chooseGroupKey(b));
          }
        }
      }
    });
  });
}
