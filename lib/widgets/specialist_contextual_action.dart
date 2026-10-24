// lib/widgets/specialist_contextual_action.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_model.dart';
import '../models/specialist_case_model.dart';
import '../services/specialist_case_service.dart';
import '../theme/meadow_theme.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/parent/llg_connect_page.dart';

/// Contextual option to connect with or discuss with a specialist.
///
/// Strictly displayed ONLY when an activity is recommended by LLG.
/// Uses empathetic, non-blaming language presenting specialist support
/// as an enriching developmental resource.
class SpecialistContextualAction extends StatelessWidget {
  final String childId;
  final ActivityModel? activity;
  final bool? isLlgRecommendedOverride;
  final SpecialistCaseService? caseService;
  final String? currentUserId;
  final String? currentUserName;
  final SpecialistCaseModel? connectedSpecialistCase;

  const SpecialistContextualAction({
    super.key,
    required this.childId,
    this.activity,
    this.isLlgRecommendedOverride,
    this.caseService,
    this.currentUserId,
    this.currentUserName,
    this.connectedSpecialistCase,
  });

  bool get _isLlgRecommended {
    if (isLlgRecommendedOverride != null) return isLlgRecommendedOverride!;
    return activity?.isLLGRecommended ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Only display when relevant to an LLG recommendation
    if (!_isLlgRecommended) {
      return const SizedBox.shrink();
    }

    // Direct injection for testability or pre-resolved case
    if (connectedSpecialistCase != null) {
      return _buildConnectedCard(context, connectedSpecialistCase!);
    }

    String? uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      try {
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        // Safe fallback in test environments without Firebase
      }
    }

    if (uid == null || uid.isEmpty) {
      return _buildUnconnectedCard(context);
    }

    final service = caseService ?? SpecialistCaseService();
    Stream<List<SpecialistCaseModel>> casesStream;
    try {
      casesStream = service.getParentCasesStream(uid, childId: childId);
    } catch (_) {
      casesStream = Stream.value([]);
    }

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: casesStream,
      builder: (context, snapshot) {
        final cases = snapshot.data ?? [];
        final activeCase = cases.cast<SpecialistCaseModel?>().firstWhere(
              (c) => c?.status == CaseStatus.accepted || c?.status == CaseStatus.active,
              orElse: () => null,
            );

        if (activeCase != null) {
          return _buildConnectedCard(context, activeCase);
        } else {
          return _buildUnconnectedCard(context);
        }
      },
    );
  }

  Widget _buildConnectedCard(BuildContext context, SpecialistCaseModel specialistCase) {
    final specialistName = specialistCase.specialistName.isNotEmpty
        ? specialistCase.specialistName
        : 'Your LittleLumin Guide';

    final specialistRole = specialistCase.specialistRole.isNotEmpty
        ? specialistCase.specialistRole.replaceAll('_', ' ')
        : 'Specialist';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: MeadowSpacing.md),
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.goldSurface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.gold.withOpacity(0.5), width: 1.5),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MeadowColors.gold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: MeadowColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Specialist Guidance Available',
                      style: MeadowTypography.label.copyWith(
                        fontSize: 14,
                        color: MeadowColors.primaryDark,
                      ),
                    ),
                    Text(
                      '$specialistName • ${specialistRole.toUpperCase()}',
                      style: MeadowTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MeadowColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This activity was recommended by your guide to support key developmental milestones. Specialist support is an additional resource for tips, adaptations, and questions.',
            style: MeadowTypography.body.copyWith(
              fontSize: 12.5,
              color: MeadowColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openChat(context, specialistCase),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Discuss with Your Specialist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeadowColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MeadowRadius.md),
                  ),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSpecialistProfile(context),
                icon: const Icon(Icons.person_outline_rounded, size: 16),
                label: const Text('View Connected Specialist'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeadowColors.primaryDark,
                  side: const BorderSide(color: MeadowColors.gold),
                  backgroundColor: Colors.white.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MeadowRadius.md),
                  ),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnconnectedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: MeadowSpacing.md),
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight, width: 1.2),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MeadowColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: MeadowColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized Specialist Guidance',
                      style: MeadowTypography.label.copyWith(
                        fontSize: 14,
                        color: MeadowColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Connect with a certified guide',
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This activity is part of our specialist-recommended developmental library. Connect with a certified LittleLumin Guide for personalized guidance, session notes, and customized activities.',
            style: MeadowTypography.body.copyWith(
              fontSize: 12,
              color: MeadowColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openSpecialistDirectory(context),
            icon: const Icon(Icons.handshake_outlined, size: 16),
            label: const Text('Connect with a Specialist'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MeadowColors.primary,
              side: const BorderSide(color: MeadowColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MeadowRadius.md),
              ),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, SpecialistCaseModel specialistCase) {
    final parentUid = currentUserId ?? specialistCase.parentId;
    final parentName = currentUserName ?? specialistCase.parentName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          specialistCase: specialistCase,
          currentUserId: parentUid,
          currentUserName: parentName.isNotEmpty ? parentName : 'Parent',
          currentUserRole: 'parent',
          otherParticipantName: specialistCase.specialistName,
          otherParticipantRole: specialistCase.specialistRole,
        ),
      ),
    );
  }

  void _openSpecialistProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LLGConnectPage(
          initialChildId: childId,
          initialSection: 'overview',
        ),
      ),
    );
  }

  void _openSpecialistDirectory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LLGConnectPage(
          initialChildId: childId,
          initialSection: 'directory',
        ),
      ),
    );
  }
}
