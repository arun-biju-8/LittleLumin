// lib/screens/parent/home/widgets/specialist_support_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/child_model.dart';
import '../../../../models/specialist_case_model.dart';
import '../../../../services/specialist_case_service.dart';
import '../../../../theme/meadow_theme.dart';
import '../../../chat/chat_screen.dart';
import '../../llg_connect_page.dart';

class SpecialistSupportCard extends StatelessWidget {
  final ChildModel? activeChild;
  final SpecialistCaseService? caseService;
  final String? parentId;
  final String? parentName;

  const SpecialistSupportCard({
    super.key,
    required this.activeChild,
    this.caseService,
    this.parentId,
    this.parentName,
  });

  @override
  Widget build(BuildContext context) {
    if (activeChild == null) return const SizedBox.shrink();

    String? uid = parentId;
    String? pName = parentName;
    if (uid == null) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        uid = currentUser?.uid;
        pName ??= currentUser?.displayName;
      } catch (_) {
        // Safe fallback in test environments where Firebase is not initialized
        return const SizedBox.shrink();
      }
    }
    if (uid == null) return const SizedBox.shrink();

    final Stream<List<SpecialistCaseModel>> casesStream;
    try {
      final service = caseService ?? SpecialistCaseService();
      casesStream = service.getParentCasesStream(uid, childId: activeChild!.childId);
    } catch (_) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: casesStream,
      builder: (context, snapshot) {
        final cases = snapshot.data ?? [];

        // Check for active or pending case
        final activeCase = cases.cast<SpecialistCaseModel?>().firstWhere(
              (c) => c?.status == CaseStatus.accepted || c?.status == CaseStatus.active,
              orElse: () => null,
            );

        final pendingCase = cases.cast<SpecialistCaseModel?>().firstWhere(
              (c) => c?.status == CaseStatus.pending,
              orElse: () => null,
            );

        if (activeCase != null) {
          return _buildActiveCaseCard(context, activeCase, uid!, pName ?? 'Parent');
        } else if (pendingCase != null) {
          return _buildPendingCaseCard(context, pendingCase);
        } else {
          return _buildDiscoveryCard(context);
        }
      },
    );
  }

  Widget _buildActiveCaseCard(
    BuildContext context,
    SpecialistCaseModel activeCase,
    String currentUserId,
    String currentUserName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: MeadowSpacing.lg),
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.primary.withOpacity(0.2), width: 1.5),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: MeadowColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            activeCase.specialistName,
                            style: MeadowTypography.label.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${activeCase.specialistRole.replaceAll('_', ' ').toUpperCase()} • ACTIVE GUIDE',
                      style: MeadowTypography.caption.copyWith(
                        fontSize: 10,
                        color: MeadowColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: MeadowColors.textSecondary),
                tooltip: 'Support Hub',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LLGConnectPage(initialChildId: activeChild!.childId),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Consultation Focus: ${activeCase.purpose}',
            style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        specialistCase: activeCase,
                        currentUserId: currentUserId,
                        currentUserName: currentUserName,
                        currentUserRole: 'parent',
                        otherParticipantName: activeCase.specialistName,
                        otherParticipantRole: activeCase.specialistRole,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Message Guide'),
                style: MeadowButtons.small(),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LLGConnectPage(
                        initialChildId: activeChild!.childId,
                        initialSection: 'recommendations',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.lightbulb_outline, size: 16),
                label: const Text('Recommendations'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeadowColors.primary,
                  side: const BorderSide(color: MeadowColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: MeadowTypography.button.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCaseCard(BuildContext context, SpecialistCaseModel pendingCase) {
    return Container(
      margin: const EdgeInsets.only(bottom: MeadowSpacing.lg),
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.gold.withOpacity(0.4), width: 1.5),
        boxShadow: MeadowShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MeadowColors.goldSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: MeadowColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultation Request Pending',
                  style: MeadowTypography.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'With ${pendingCase.specialistName} • Awaiting guide review',
                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LLGConnectPage(initialChildId: activeChild!.childId),
                ),
              );
            },
            child: Text(
              'View Status',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: MeadowColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: MeadowSpacing.lg),
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MeadowColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety_outlined, color: MeadowColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specialist & Support',
                  style: MeadowTypography.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connect with a certified LittleLumin Guide (LLG) for expert developmental plans.',
                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LLGConnectPage(initialChildId: activeChild!.childId),
                ),
              );
            },
            style: MeadowButtons.small(),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
