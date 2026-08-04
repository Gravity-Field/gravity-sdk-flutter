import 'package:flutter/widgets.dart' hide Element;

import '../models/internal/element.dart';

/// Shared validity rule for form inputs, used both for submit-button gating
/// and for the pre-submit re-check in SubmitExecutor.
///
/// `minLength` implies the field must be filled: an untouched field with a
/// visible «Минимум N символов» hint blocks submit from the first frame —
/// otherwise the empty field reads as valid while one typed character does
/// not. A field stays optional only when neither `required` nor `minLength`
/// is set. Length is measured over the trimmed value in grapheme clusters —
/// the same unit the maxLength counter enforces.
bool isInputValueValid(Element input, Object? value) {
  final isEmpty =
      value == null || (value is String && value.trim().isEmpty);
  if (input.isRequired && isEmpty) return false;

  final minLength = input.minLength;
  if (minLength != null) {
    if (isEmpty) return false;
    if (value is String) {
      return value.trim().characters.length >= minLength;
    }
  }
  return true;
}
