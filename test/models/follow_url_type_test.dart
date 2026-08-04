import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';

const _wireNames = {
  'browser': FollowUrlType.browser,
  'webview': FollowUrlType.webview,
};

void main() {
  group('cross-SDK follow_url type vectors', () {
    final vectors =
        jsonDecode(
              File(
                'test/fixtures/follow_url_type_vectors.json',
              ).readAsStringSync(),
            )
            as List;
    for (final rawVector in vectors) {
      final vector = rawVector as Map<String, dynamic>;
      test(vector['name'], () {
        final onClick = OnClick.fromJson(
          vector['onClick'] as Map<String, dynamic>,
        );
        expect(onClick.action, Action.followUrl);
        expect(onClick.type, _wireNames[vector['expected']]);
      });
    }
  });

  test('legacy onClick without type resolves to browser', () {
    final onClick = OnClick.fromJson({'action': 'close'});
    expect(onClick.action, Action.close);
    expect(onClick.type, FollowUrlType.browser);
  });
}
