import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';
import 'package:gravity_sdk/src/ui/widgets/modal_appearance.dart';
import 'package:gravity_sdk/src/utils/modal_impression.dart';

import '../../../models/external/campaign.dart';
import '../../../models/actions/action.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../widgets/close_button.dart';
import '../../widgets/gravity_elements_column.dart';

class ModalContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;
  final FormSession? session;
  final ModalImpression? impression;

  const ModalContent({
    super.key,
    required this.content,
    required this.campaign,
    this.session,
    this.impression,
  });

  @override
  State<ModalContent> createState() => _ModalContentState();
}

class _ModalContentState extends State<ModalContent> {
  late final OnClickHandler onClickHandler;
  late final ModalImpression impression;

  @override
  void initState() {
    super.initState();
    impression =
        widget.impression ??
        ContentEventsService.instance.createModalImpression(
          content: widget.content,
          campaign: widget.campaign,
        );

    onClickHandler = OnClickHandler(
      campaign: widget.campaign,
      content: widget.content,
      session: widget.session,
      impression: impression,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ContentEventsService.instance.sendContentImpression(
        campaign: widget.campaign,
        content: widget.content,
      );
    });
  }

  @override
  Widget build(BuildContext context) => ModalImpressionScope(
    impression: impression,
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) {
    final frameUi = widget.content.variables.frameUI!;
    final container = frameUi.container;
    final close = frameUi.close;
    final products = widget.content.products;

    final backgroundImage = container.style?.backgroundImage;
    final backgroundColor = container.style?.backgroundColor ?? Colors.white;
    final fit = container.style?.backgroundFit ?? BoxFit.cover;
    final cornerRadius = container.style?.cornerRadius ?? 0;

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ModalAppearance(
        impression: impression,
        child: Stack(
          children: [
            if (backgroundImage != null)
              Positioned.fill(
                child: Image.network(
                  backgroundImage,
                  fit: fit,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: container.style?.padding?.left ?? 0,
                top: container.style?.padding?.top ?? 0,
                right: container.style?.padding?.right ?? 0,
                bottom: container.style?.padding?.bottom ?? 0,
              ),
              child: SingleChildScrollView(
                child: GravityElementsColumn(
                  content: widget.content,
                  campaign: widget.campaign,
                  products: products,
                  session: widget.session,
                  formsEnabled: true,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      container.style?.contentAlignment
                          ?.toCrossAxisAlignment() ??
                      CrossAxisAlignment.center,
                  onClickCallback: (element, action) {
                    final shouldPop = shouldAutoPopOnClick(element, action);
                    onClickHandler.handeOnClick(
                      action,
                      context,
                      explicitClose:
                          shouldPop &&
                          (action.action == Action.close ||
                              action.action == Action.cancel),
                    );
                    if (shouldPop) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
            if (close != null)
              GravityCloseButtonWidget(
                close: close,
                onClickCallback: (action) {
                  impression.explicitClose();
                  onClickHandler.handeOnClick(
                    action,
                    context,
                    explicitClose: true,
                  );
                  Navigator.of(context).pop();
                },
                onClose: () {
                  impression.explicitClose();
                  onClickHandler.finishExplicitClose();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
