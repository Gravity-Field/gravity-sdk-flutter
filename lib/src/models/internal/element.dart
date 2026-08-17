import 'package:json_annotation/json_annotation.dart';

import '../../data/error_reporting/error_reporter.dart';
import '../actions/action.dart';
import '../actions/on_click.dart';
import 'condition.dart';
import 'style.dart';

part 'element.g.dart';

@JsonEnum()
enum ElementType {
  @JsonValue('image')
  image,
  @JsonValue('text')
  text,
  @JsonValue('button')
  button,
  @JsonValue('spacer')
  spacer,
  @JsonValue('products-container')
  productsContainer,
  @JsonValue('webview')
  webview,
  @JsonValue('option-select')
  optionSelect,
  @JsonValue('text-input')
  textInput,
  unknown,
}

@JsonSerializable()
class Element {
  @JsonKey(unknownEnumValue: ElementType.unknown)
  final ElementType type;
  final String? text;
  final String? src;
  final Style? style;
  final OnClick? onClick;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? attributeName;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<FormOption>? options;
  @JsonKey(name: 'required', includeFromJson: false, includeToJson: false)
  final bool isRequired;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? maxLength;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? minLength;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool? showCounter;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? placeholder;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Condition? visibleWhen;

  Element({
    required this.type,
    this.text,
    this.src,
    required this.style,
    this.onClick,
    this.attributeName,
    this.options,
    this.isRequired = false,
    this.maxLength,
    this.minLength,
    this.showCounter,
    this.placeholder,
    this.visibleWhen,
  });

  factory Element.fromJson(Map<String, dynamic> json) {
    try {
      final result = _$ElementFromJson(json);
      if (result.type == ElementType.unknown) {
        return _demote(json, 'Unknown element type');
      }

      final rawRequired = json['required'];
      if (json.containsKey('required') && rawRequired is! bool) {
        return _demote(json, 'Invalid required');
      }
      final rawSelectMode = json['selectMode'];
      if (json.containsKey('selectMode') && rawSelectMode is! String) {
        return _demote(json, 'Invalid selectMode');
      }
      final rawDisplayFormat = json['displayFormat'];
      if (json.containsKey('displayFormat') && rawDisplayFormat is! String) {
        return _demote(json, 'Invalid displayFormat');
      }
      final rawPlaceholder = json['placeholder'];
      if (json.containsKey('placeholder') && rawPlaceholder is! String) {
        return _demote(json, 'Invalid placeholder');
      }
      final rawAttributeName = json['attributeName'];
      if (rawAttributeName != null && rawAttributeName is! String) {
        return _demote(json, 'Invalid attributeName');
      }
      final rawMaxLength = json['maxLength'];
      if (json.containsKey('maxLength') && rawMaxLength is! int) {
        return _demote(json, 'Invalid maxLength');
      }
      final rawMinLength = json['minLength'];
      if (json.containsKey('minLength') && rawMinLength is! int) {
        return _demote(json, 'Invalid minLength');
      }
      final rawShowCounter = json['showCounter'];
      if (json.containsKey('showCounter') && rawShowCounter is! bool) {
        return _demote(json, 'Invalid showCounter');
      }

      List<FormOption>? options;
      if (result.type == ElementType.optionSelect) {
        if (rawAttributeName is! String || rawAttributeName.isEmpty) {
          return _demote(json, 'Missing attributeName for option-select');
        }
        if (rawDisplayFormat != 'rating') {
          return _demote(json, 'Unsupported displayFormat for option-select');
        }
        if (rawSelectMode != null && rawSelectMode != 'single') {
          return _demote(json, 'Unsupported selectMode for option-select');
        }
        final rawOptions = json['options'];
        if (rawOptions is! List || rawOptions.length != 5) {
          return _demote(json, 'Invalid rating options');
        }
        final values = <FormOption>[];
        for (var index = 0; index < rawOptions.length; index++) {
          final option = rawOptions[index];
          if (option is! Map || option['value'] is! int || option['value'] != index + 1) {
            return _demote(json, 'Invalid rating option value');
          }
          values.add(
            FormOption(
              value: option['value'] as int,
              onClick: _parseOptionOnClick(option),
            ),
          );
        }
        options = values;
      }

      if (result.type == ElementType.textInput) {
        if (rawAttributeName is! String || rawAttributeName.isEmpty) {
          return _demote(json, 'Missing attributeName for text-input');
        }
        if (rawMaxLength != null && rawMaxLength <= 0) {
          return _demote(json, 'Invalid maxLength for text-input');
        }
        if (rawMinLength != null && rawMinLength < 0) {
          return _demote(json, 'Invalid minLength for text-input');
        }
        if (rawMinLength != null && rawMaxLength != null && rawMinLength > rawMaxLength) {
          return _demote(json, 'minLength above maxLength for text-input');
        }
      }

      Condition? visibleWhen;
      if (json.containsKey('visibleWhen')) {
        visibleWhen = Condition.tryParse(json['visibleWhen']);
        if (visibleWhen == null) {
          return _demote(json, 'Invalid visibleWhen');
        }
      }

      return Element(
        type: result.type,
        text: result.text,
        src: result.src,
        style: result.style,
        onClick: result.onClick,
        attributeName: rawAttributeName as String?,
        options: options,
        isRequired: rawRequired as bool? ?? false,
        maxLength: rawMaxLength as int?,
        // 0 carries the same meaning as an absent minLength — no minimum —
        // so it must not surface in the UI hint.
        minLength: rawMinLength == 0 ? null : rawMinLength as int?,
        showCounter: rawShowCounter as bool?,
        placeholder: rawPlaceholder as String?,
        visibleWhen: visibleWhen,
      );
    } catch (error) {
      return _demote(json, 'Invalid element payload: $error');
    }
  }

  bool get isFormInput => type == ElementType.optionSelect || type == ElementType.textInput;
}

class FormOption {
  final num value;
  final OnClick? onClick;

  const FormOption({required this.value, this.onClick});
}

OnClick? _parseOptionOnClick(Map option) {
  if (!option.containsKey('onClick')) return null;
  try {
    final raw = option['onClick'];
    if (raw is! Map) {
      throw const FormatException('onClick is not a map');
    }
    final onClick = OnClick.fromJson(Map<String, dynamic>.from(raw));
    if (onClick.action == Action.submitForm) return onClick;
    if (onClick.action != Action.unknown) {
      ErrorReporter.instance.report(
        message: 'Unsupported option onClick action: ${onClick.action.name}',
        level: 'warning',
        section: 'Element.fromJson',
        tags: {'category': 'parsing'},
      );
    }
    return null;
  } catch (error) {
    ErrorReporter.instance.report(
      message: 'Invalid option onClick: $error',
      level: 'warning',
      section: 'Element.fromJson',
      tags: {'category': 'parsing'},
    );
    return null;
  }
}

Element _demote(Map json, String reason) {
  ErrorReporter.instance.report(
    message: '$reason: ${json['type']}',
    level: 'warning',
    section: 'Element.fromJson',
    tags: {'category': 'parsing'},
  );
  return Element(type: ElementType.unknown, style: null);
}
