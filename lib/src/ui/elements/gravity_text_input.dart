import 'package:flutter/material.dart' hide Element;

import '../../forms/form_session.dart';
import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

/// «Минимум 1 символ / 2 символа / 5 символов».
String minLengthHint(int minLength) {
  final mod100 = minLength % 100;
  final mod10 = minLength % 10;
  final String noun;
  if (mod10 == 1 && mod100 != 11) {
    noun = 'символ';
  } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    noun = 'символа';
  } else {
    noun = 'символов';
  }
  return 'Минимум $minLength $noun';
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class GravityTextInput extends StatefulWidget {
  const GravityTextInput({
    super.key,
    required this.element,
    required this.session,
  });

  final Element element;
  final FormSession session;

  @override
  State<GravityTextInput> createState() => _GravityTextInputState();
}

class _GravityTextInputState extends State<GravityTextInput> {
  late final TextEditingController _controller;

  String get _attributeName => widget.element.attributeName!;

  String get _sessionText {
    final value = widget.session.valueOf(_attributeName);
    return value is String ? value : '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _sessionText);
    widget.session.addListener(_syncFromSession);
  }

  @override
  void didUpdateWidget(GravityTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_syncFromSession);
      widget.session.addListener(_syncFromSession);
    }
    _syncFromSession();
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncFromSession);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromSession() {
    final text = _sessionText;
    if (_controller.text == text) return;

    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.element.style ?? Style();
    final textStyle = style.textStyle;
    final height = style.size?.height;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(style.cornerRadius ?? 0),
      borderSide: BorderSide.none,
    );

    Widget output = TextField(
      controller: _controller,
      keyboardType: TextInputType.multiline,
      maxLength: widget.element.maxLength,
      // A null from buildCounter removes the counter together with its
      // reserved line; counterText: '' would keep an empty row instead.
      buildCounter: widget.element.showCounter == false ? _noCounter : null,
      maxLines: null,
      expands: height != null,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        color: textStyle?.color,
        fontSize: textStyle?.fontSize,
        fontWeight: textStyle?.fontWeight,
      ),
      decoration: InputDecoration(
        hintText: widget.element.placeholder,
        helperText: widget.element.minLength == null
            ? null
            : minLengthHint(widget.element.minLength!),
        filled: style.backgroundColor != null,
        fillColor: style.backgroundColor,
        contentPadding: style.padding == null
            ? EdgeInsets.zero
            : EdgeInsets.only(
                left: style.padding!.left,
                right: style.padding!.right,
                top: style.padding!.top,
                bottom: style.padding!.bottom,
              ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
      onChanged: (text) => widget.session.setValue(_attributeName, text),
    );

    if (style.size != null) {
      output = SizedBox(
        width: style.size!.width,
        height: height,
        child: output,
      );
    }

    if (style.margin != null) {
      output = Padding(
        padding: EdgeInsets.only(
          left: style.margin!.left,
          right: style.margin!.right,
          top: style.margin!.top,
          bottom: style.margin!.bottom,
        ),
        child: output,
      );
    }

    return output;
  }
}
