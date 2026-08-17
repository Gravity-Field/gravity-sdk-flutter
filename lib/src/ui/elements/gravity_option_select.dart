import 'package:flutter/material.dart' hide Element;

import '../../forms/form_session.dart';
import '../../models/actions/on_click.dart';
import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

class GravityOptionSelect extends StatelessWidget {
  const GravityOptionSelect({
    super.key,
    required this.element,
    required this.session,
    required this.onClickCallback,
  });

  final Element element;
  final FormSession session;
  final Function(OnClick) onClickCallback;

  @override
  Widget build(BuildContext context) {
    final attributeName = element.attributeName!;
    final options = element.options!;
    final style = element.style;
    final ratingStyle = style?.rating ?? RatingStyle();

    Widget output = ListenableBuilder(
      listenable: session,
      builder: (context, child) {
        final value = session.valueOf(attributeName);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < options.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  right: index == options.length - 1
                      ? 0
                      : ratingStyle.itemSpacing,
                ),
                child: _RatingStar(
                  index: index + 1,
                  count: options.length,
                  selected: value is num && index + 1 <= value,
                  color: value is num && index + 1 <= value
                      ? ratingStyle.selectedColor
                      : ratingStyle.unselectedColor,
                  size: ratingStyle.itemSize,
                  // State first, action second (with the fresh snapshot):
                  // SubmitExecutor reads the session synchronously, so an
                  // option-triggered submit must see the value of this tap.
                  onTap: () {
                    if (session.isSubmitting || session.isFinished) return;
                    session.setValue(attributeName, options[index].value);
                    final onClick = options[index].onClick;
                    if (onClick != null) onClickCallback(onClick);
                  },
                ),
              ),
          ],
        );
      },
    );

    final margin = style?.margin;
    if (margin != null) {
      output = Padding(
        padding: EdgeInsets.only(
          left: margin.left,
          right: margin.right,
          top: margin.top,
          bottom: margin.bottom,
        ),
        child: output,
      );
    }

    return output;
  }
}

class _RatingStar extends StatelessWidget {
  const _RatingStar({
    required this.index,
    required this.count,
    required this.selected,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final int index;
  final int count;
  final bool selected;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Оценка $index из $count',
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Icon(Icons.star, color: color, size: size),
      ),
    );
  }
}
