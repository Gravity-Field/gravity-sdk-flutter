import 'package:flutter/material.dart';
import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../models/internal/tooltip_config.dart';
import '../../../utils/content_events_service.dart';
import 'tooltip_content.dart';

class TooltipOverlay {
  static OverlayEntry? _barrierEntry;
  static OverlayEntry? _contentEntry;
  static CampaignContent? _currentContent;
  static Campaign? _currentCampaign;

  static void show({
    required BuildContext context,
    required CampaignContent content,
    required Campaign campaign,
    required TooltipConfig config,
    required String selector,
  }) {
    dismiss();

    _currentContent = content;
    _currentCampaign = campaign;

    final overlay = Overlay.of(context);

    _barrierEntry = OverlayEntry(
      builder: (context) => Listener(
        onPointerDown: (_) => dismiss(),
        behavior: HitTestBehavior.translucent,
        child: const SizedBox.expand(),
      ),
    );

    _contentEntry = OverlayEntry(
      builder: (context) =>
          TooltipContent(content: content, campaign: campaign, config: config, selector: selector, onDismiss: dismiss),
    );

    overlay.insert(_barrierEntry!);
    overlay.insert(_contentEntry!);
  }

  static void dismiss() {
    if (_currentContent != null && _currentCampaign != null) {
      ContentEventsService.instance.sendContentClosed(
        content: _currentContent!,
        campaign: _currentCampaign!,
      );
    }

    _contentEntry?.remove();
    _contentEntry = null;
    _barrierEntry?.remove();
    _barrierEntry = null;
    _currentContent = null;
    _currentCampaign = null;
  }

  static bool get isShowing => _contentEntry != null;
}
