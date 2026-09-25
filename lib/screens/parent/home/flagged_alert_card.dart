import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../services/flag_service.dart';
import '../llg_connect_page.dart';
import '../parent_theme.dart';

class FlaggedAlertCard extends StatefulWidget {
  final ChildModel? child;
  final String? childId;
  final String? childName;
  final String? domain;
  final String? linkText;
  final VoidCallback? onViewLLG;

  const FlaggedAlertCard({
    super.key,
    this.child,
    this.childId,
    this.childName,
    this.domain,
    this.linkText,
    this.onViewLLG,
  });

  @override
  State<FlaggedAlertCard> createState() => _FlaggedAlertCardState();
}

class _FlaggedAlertCardState extends State<FlaggedAlertCard> {
  bool _dismissed = false;

  String get _resolvedChildId => widget.childId ?? widget.child?.childId ?? '';
  String get _resolvedChildName => widget.childName ?? widget.child?.name ?? 'Your child';
  String get _resolvedDomain => widget.domain ?? 'cognitive';

  String get _resolvedLinkText {
    if (widget.linkText != null && widget.linkText!.isNotEmpty) {
      return widget.linkText!;
    }
    return FlagService.computeLinkText(
      flaggedAt: widget.child?.flaggedAt,
      parentResponse: 'pending',
    );
  }

  bool get _isActiveFlag {
    if (widget.child != null) {
      return widget.child!.isFlagged;
    }
    return _resolvedChildId.isNotEmpty;
  }

  void _openLLGConnect(BuildContext context) {
    if (_resolvedChildId.isNotEmpty) {
      FlagService().parentApproved(_resolvedChildId, _resolvedDomain).catchError((_) {});
    }

    if (widget.onViewLLG != null) {
      widget.onViewLLG!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LLGConnectPage(initialChildId: _resolvedChildId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActiveFlag) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_dismissed) ...[
          _buildDismissibleCard(context),
          const SizedBox(height: 8),
        ],
        _buildPersistentLink(context),
      ],
    );
  }

  Widget _buildDismissibleCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: ParentRadius.card,
        border: Border.all(
          color: ParentColors.warning.withOpacity(0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ParentColors.warning.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ParentColors.warning.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.handshake_outlined,
                  color: Color(0xFFB45309),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A specialist could help',
                  style: ParentTypography.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$_resolvedChildName has been finding some activities trickier than usual. '
            'Our specialists can create a personalized plan — at your pace.',
            style: ParentTypography.body.copyWith(
              color: const Color(0xFF78350F),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _openLLGConnect(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: ParentRadius.button,
                ),
              ),
              child: Text(
                'Yes, show me specialists',
                style: ParentTypography.button.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _dismissed = true);
                if (_resolvedChildId.isNotEmpty) {
                  FlagService().parentDeclined(_resolvedChildId, _resolvedDomain).catchError((_) {});
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: ParentColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              child: const Text('Maybe later', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentLink(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: ParentRadius.input,
        onTap: () => _openLLGConnect(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: ParentColors.primary.withOpacity(0.06),
            borderRadius: ParentRadius.input,
            border: Border.all(
              color: ParentColors.primary.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.support_agent_rounded,
                size: 20,
                color: ParentColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _resolvedLinkText,
                  style: ParentTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ParentColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: ParentColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
