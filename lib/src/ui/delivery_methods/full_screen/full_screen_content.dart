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

class FullScreenContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;
  final FormSession? session;
  final ModalImpression? impression;

  const FullScreenContent({
    super.key,
    required this.content,
    required this.campaign,
    this.session,
    this.impression,
  });

  @override
  State<FullScreenContent> createState() => _FullScreenContentState();
}

class _FullScreenContentState extends State<FullScreenContent> {
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
    final backgroundColor = container.style?.backgroundColor;
    final fit = container.style?.backgroundFit ?? BoxFit.cover;

    return ModalAppearance(
      impression: impression,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            if (backgroundImage != null)
              Positioned.fill(child: Image.network(backgroundImage, fit: fit)),
            SafeArea(
              bottom: false,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(
                      left: container.style?.padding?.left ?? 0,
                      right: container.style?.padding?.right ?? 0,
                      top: container.style?.padding?.top ?? 0,
                      bottom: container.style?.padding?.bottom ?? 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: GravityElementsColumn(
                                content: widget.content,
                                campaign: widget.campaign,
                                products: products,
                                session: widget.session,
                                formsEnabled: true,
                                crossAxisAlignment:
                                    container.style?.contentAlignment
                                        ?.toCrossAxisAlignment() ??
                                    CrossAxisAlignment.center,
                                mainAxisAlignment:
                                    container.style?.verticalAlignment
                                        ?.toMainAxisAlignment() ??
                                    MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                onClickCallback: (element, action) {
                                  final shouldPop = shouldAutoPopOnClick(
                                    element,
                                    action,
                                  );
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
                          );
                        },
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
            ),
          ],
        ),
      ),
    );
  }
}
