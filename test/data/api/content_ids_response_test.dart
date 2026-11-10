import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/api/content_ids_response.dart';

void main() {
  for (final field in ['priority', 'delayTime']) {
    for (final (name, raw, expected) in <(String, Object?, int)>[
      ('integer', 1500, 1500),
      ('double', 1500.9, 1500),
      ('negative double', -1500.9, -1500),
      ('shared negative double', -1.5, -1),
      // Dart's JSON decoder accepts overflowing numbers as non-finite doubles.
      ('overflowing JSON number', jsonDecode('1e400'), 0),
      ('zero', 0, 0),
      ('integer string', '1500', 1500),
      ('explicit positive string', '+1500', 1500),
      ('precise large integer string', '9007199254740993', 9007199254740993),
      ('hex string', '0x10', 0),
      ('uppercase hex string', '0X3E8', 0),
      ('negative hex string', '-0x1', 0),
      ('huge finite number', 1e30, 9223372036854775807),
      (
        'huge finite integer string',
        '99999999999999999999',
        9223372036854775807,
      ),
      ('negative huge finite number', -1e30, -9223372036854775808),
      ('padded string', ' 1500 ', 1500),
      ('decimal string', '1500.0', 1500),
      ('fractional string', '1500.9', 1500),
      ('negative string', '-1500.9', -1500),
      ('exponent string', '1.5e3', 1500),
      ('null', null, 0),
      ('true', true, 0),
      ('false', false, 0),
      ('non-numeric string', 'invalid', 0),
      ('empty string', '', 0),
      ('whitespace string', '   ', 0),
      ('object', <String, Object?>{'value': 1500}, 0),
      ('list', <Object?>[1500], 0),
      ('empty object', <String, Object?>{}, 0),
      ('empty array', <Object?>[], 0),
      ('NaN number', double.nan, 0),
      ('infinite number', double.infinity, 0),
      ('negative infinite number', double.negativeInfinity, 0),
      ('NaN string', 'NaN', 0),
      ('infinite string', 'Infinity', 0),
      ('negative infinite string', '-Infinity', 0),
      ('overflow string', '1e999', 9223372036854775807),
      ('NBSP and ideographic padding', '\u00A01500\u3000', 1500),
      ('NEL padding', '\u00851500', 1500),
      ('leading BOM', '\uFEFF15', 0),
      ('trailing BOM', '15\uFEFF', 0),
      ('leading zero-width space', '\u200B15', 0),
      ('trailing zero-width space', '15\u200B', 0),
      ('trailing decimal point', '1.', 1),
      ('trailing point with exponent', '1.e2', 100),
      ('leading decimal point', '.5', 0),
      ('shared positive sign', '+5', 5),
      ('shared negative integer', '-3', -3),
      ('shared exponent', '1e3', 1000),
      ('exact fraction below one', '0.9999999999999999999999', 0),
      ('negative fraction', '-0.9', 0),
      ('positive overflow exponent', '1e400', 9223372036854775807),
      ('negative overflow exponent', '-1e400', -9223372036854775808),
      ('underflow exponent', '1e-400', 0),
      ('huge exponent', '1e999999999', 9223372036854775807),
      ('previous double overflow', '1e309', 9223372036854775807),
      ('underscores', '1_000', 0),
      ('decimal comma', '1,5', 0),
      ('shared invalid letters', 'abc', 0),
      ('non-ASCII digits', '\u0661\u0665', 0),
      ('internal whitespace', '1 5', 0),
      ('internal newline', '15\n00', 0),
      ('missing exponent digits', '1e+', 0),
      ('only point', '.', 0),
      ('unmatched suffix', '15x', 0),
      (
        'exact int64 max fraction',
        '9223372036854775807.9',
        9223372036854775807,
      ),
      ('exact near max fraction', '9223372036854775806.9', 9223372036854775806),
      (
        'exact int64 min fraction',
        '-9223372036854775808.9',
        -9223372036854775808,
      ),
      (
        'exact near min fraction',
        '-9223372036854775807.9',
        -9223372036854775807,
      ),
      (
        'exact decimal beyond double precision',
        '9007199254740993.0',
        9007199254740993,
      ),
      (
        'negative exact decimal beyond double precision',
        '-9007199254740993.0',
        -9007199254740993,
      ),
      ('zero with huge exponent', '0e999999999', 0),
      ('very long positive exponent', '1e${'9' * 10000}', 9223372036854775807),
      ('very long negative exponent', '1e-${'9' * 10000}', 0),
      ('long mantissa with cancelling exponent', '1${'0' * 1000}e-1000', 1),
      for (final codePoint in [
        0x0009,
        0x000A,
        0x000B,
        0x000C,
        0x000D,
        0x0020,
        0x0085,
        0x00A0,
        0x1680,
        ...List.generate(11, (index) => 0x2000 + index),
        0x2028,
        0x2029,
        0x202F,
        0x205F,
        0x3000,
      ])
        (
          'Unicode White_Space U+${codePoint.toRadixString(16)}',
          '${String.fromCharCode(codePoint)}1500${String.fromCharCode(codePoint)}',
          1500,
        ),
    ]) {
      test(
        '$field tolerates $name without losing campaigns or other fields',
        () {
          final response = CampaignIdsResponse.fromJson({
            'user': {'uid': 'user', 'ses': 'session'},
            'campaigns': [
              {
                'campaignId': 'tested',
                'priority': 7,
                'delayTime': 42,
                field: raw,
              },
              {'campaignId': 'other', 'priority': 9, 'delayTime': 100},
            ],
          });
          expect(response.campaigns, hasLength(2));
          final tested = response.campaigns.first;
          expect(tested.campaignId, 'tested');
          expect(tested.priority, field == 'priority' ? expected : 7);
          expect(tested.delayTime, field == 'delayTime' ? expected : 42);
          expect(response.campaigns.last.campaignId, 'other');
          expect(response.campaigns.last.priority, 9);
          expect(response.campaigns.last.delayTime, 100);
        },
      );
    }
  }

  for (final field in ['priority', 'delayTime']) {
    for (final (name, raw, expected) in [
      ('internal whitespace', '1${' ' * 100000}2', 0),
      ('huge integer', '9' * 100000, 9223372036854775807),
      ('long fraction', '1.${'0' * 100000}', 1),
      ('invalid huge integer', '${'9' * 100000}x', 0),
      ('invalid long fraction', '1.${'0' * 100000}x', 0),
      (
        'tiny fraction with cancelling exponent',
        '0.${'0' * 100000}1e100001',
        1,
      ),
    ]) {
      test('$field parses 100000-character $name in linear time', () {
        final json = {
          'user': {'uid': 'user', 'ses': 'session'},
          'campaigns': [
            {'campaignId': 'tested', field: raw},
            {'campaignId': 'sibling', 'priority': 9, 'delayTime': 100},
          ],
        };
        final stopwatch = Stopwatch()..start();
        final response = CampaignIdsResponse.fromJson(json);
        stopwatch.stop();
        expect(response.campaigns, hasLength(2));
        final campaign = response.campaigns.first;
        expect(
          field == 'priority' ? campaign.priority : campaign.delayTime,
          expected,
        );
        expect(response.campaigns.last.campaignId, 'sibling');
        expect(response.campaigns.last.priority, 9);
        expect(response.campaigns.last.delayTime, 100);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      });
    }
  }

  test('missing campaign numbers default to zero', () {
    final campaign = CampaignId.fromJson({'campaignId': 'missing'});
    expect(campaign.priority, 0);
    expect(campaign.delayTime, 0);
  });
}
