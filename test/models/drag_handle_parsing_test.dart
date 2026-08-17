import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/internal/frame_ui.dart';

// Inline map literals infer Map<dynamic, dynamic> for nested maps, which the
// generated parsers reject; the json round-trip mirrors production decoding.
FrameUI _frameUI(Map<String, dynamic> extra) => FrameUI.fromJson(
  jsonDecode(
        jsonEncode({
          'container': {
            'style': {'backgroundColor': '#ffffffff'},
          },
          ...extra,
        }),
      )
      as Map<String, dynamic>,
);

DragHandle? _handle(Object? dragHandle) =>
    _frameUI({'dragHandle': dragHandle}).dragHandle;

void main() {
  test('full dragHandle style parses', () {
    final handle = _handle({
      'style': {
        'visible': true,
        'backgroundColor': '#181d27ff',
        'size': {'width': 48, 'height': 6},
        'margin': {'top': 24, 'bottom': 8},
        'cornerRadius': 2,
      },
    })!;

    expect(handle.color, const Color(0xFF181D27));
    expect(handle.width, 48);
    expect(handle.height, 6);
    expect(handle.cornerRadius, 2);
    expect(handle.margin, const EdgeInsets.only(top: 24, bottom: 8));
  });

  test('visible handle without style values falls back to defaults', () {
    final handle = _handle({
      'style': {'visible': true},
    })!;

    expect(handle.color, const Color(0xFFD9D9D9));
    expect(handle.width, 36);
    expect(handle.height, 4);
    // A capsule unless the backend asks for something else.
    expect(handle.cornerRadius, 2);
    expect(handle.margin, const EdgeInsets.only(top: 18, bottom: 4));
  });

  group('unusable dimensions fall back to defaults', () {
    final cases = <String, Object?>{
      'negative': -10,
      'zero': 0,
      'NaN string': 'NaNpx',
      'infinity string': '1e999px',
    };
    cases.forEach((name, raw) {
      test(name, () {
        final handle = _handle({
          'style': {
            'visible': true,
            'size': {'width': raw, 'height': raw},
          },
        })!;

        expect(handle.width, 36);
        expect(handle.height, 4);
      });
    });
  });

  group('no handle, no throw', () {
    final cases = <String, Object?>{
      'explicit null': null,
      'visible false': {
        'style': {'visible': false, 'backgroundColor': '#d9d9d9ff'},
      },
      'visible missing': {
        'style': {'backgroundColor': '#d9d9d9ff'},
      },
      'visible garbage': {
        'style': {'visible': 'yes'},
      },
      'style missing': {'visible': true},
      'style is a string': {'style': 'visible'},
      'style is a list': {
        'style': [1, 2],
      },
      'dragHandle bool': true,
      'dragHandle string': 'show',
      'dragHandle list': [1, 2],
    };
    cases.forEach((name, dragHandle) {
      test(name, () => expect(_handle(dragHandle), isNull));
    });
  });

  test('unparsable style keeps a visible handle on the defaults', () {
    // `visible: true` states the intent; broken styling next to it must not
    // swallow the handle itself.
    final handle = _handle({
      'style': {'visible': true, 'size': 'big', 'margin': 42},
    })!;

    expect(handle.color, const Color(0xFFD9D9D9));
    expect(handle.width, 36);
    expect(handle.height, 4);
    expect(handle.margin, const EdgeInsets.only(top: 18, bottom: 4));
  });

  test('absent dragHandle key means no handle', () {
    expect(_frameUI(const {}).dragHandle, isNull);
  });

  test('params keeps carrying the snackbar duration', () {
    final frameUI = _frameUI({
      'params': {'duration': 7},
    });

    expect(frameUI.params!.duration, 7);
  });
}
