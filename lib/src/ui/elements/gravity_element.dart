import 'package:flutter/material.dart' hide Element, Action;
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';

import '../../models/external/campaign.dart';
import '../../models/internal/element.dart';
import '../../models/internal/products.dart';
import 'gravity_button.dart';
import 'gravity_image.dart';
import 'gravity_option_select.dart';
import 'gravity_products_container.dart';
import 'gravity_text.dart';
import 'gravity_text_input.dart';
import 'gravity_webview.dart';

class GravityElement {
  final CampaignContent content;
  final Campaign campaign;
  final Element element;
  final Function(OnClick) onClickCallback;
  final Products? products;
  final FormSession? session;
  final bool formsEnabled;
  final bool enabled;

  GravityElement({
    required this.content,
    required this.campaign,
    required this.element,
    required this.onClickCallback,
    this.products,
    this.session,
    this.formsEnabled = false,
    this.enabled = true,
  });

  Widget getWidget() {
    switch (element.type) {
      case ElementType.image:
        return GravityImageWidget(
          element: element,
          onClickCallback: onClickCallback,
        );
      case ElementType.text:
        return GravityText(element: element, onClickCallback: onClickCallback);
      case ElementType.button:
        return GravityButton(
          element: element,
          enabled: enabled,
          onClickCallback: onClickCallback,
        );
      case ElementType.spacer:
        return Spacer();

      case ElementType.productsContainer:
        if (products == null) {
          return SizedBox.shrink();
        }
        return GravityProductsContainer(
          element: element,
          products: products!,
          campaign: campaign,
          content: content,
        );
      case ElementType.webview:
        return GravityWebView(element: element);
      case ElementType.optionSelect:
        if (session == null || !formsEnabled) return SizedBox.shrink();
        return GravityOptionSelect(element: element, session: session!);
      case ElementType.textInput:
        if (session == null || !formsEnabled) return SizedBox.shrink();
        return GravityTextInput(element: element, session: session!);
      case ElementType.unknown:
        return SizedBox.shrink();
    }
  }
}
