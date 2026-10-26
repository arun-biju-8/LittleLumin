// lib/screens/parent/llg_connect_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../models/contact_consent_model.dart';
import '../../models/recommendation_model.dart';
import '../../models/consultation_summary_model.dart';
import '../../services/child_service.dart';
import '../../services/specialist_case_service.dart';
import '../../services/contact_consent_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/consultation_summary_service.dart';
import '../../models/specialist_report_model.dart';
import '../../services/specialist_report_service.dart';
import '../../services/parent_complaint_service.dart';
import '../../models/admin_models.dart';
import 'complaint_submission_dialog.dart';
import 'specialist_review_dialog.dart';
import '../../theme/meadow_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/global_header.dart';
import '../chat/chat_screen.dart';
import 'recommendation_detail_screen.dart';

class LLGConnectPage extends StatefulWidget {
  final String? initialChildId;
  final String initialSection; // 'overview', 'recommendations', 'reports', 'consents', 'directory', 'summaries', 'complaints'
  final int? initialTabIndex;
  final String? currentUserId;

  const LLGConnectPage({
    super.key,
    this.initialChildId,
    this.initialSection = 'overview',
    this.initialTabIndex,
    this.currentUserId,
  });

  @override
  State<LLGConnectPage> createState() => _LLGConnectPageState();
}

class _LLGConnectPageState extends State<LLGConnectPage> {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final SpecialistCaseService _caseService = SpecialistCaseService();
  final ContactConsentService _consentService = ContactConsentService();
  final RecommendationService _recommendationService = RecommendationService();
  final ConsultationSummaryService _summaryService = ConsultationSummaryService();
  final SpecialistReportService _reportService = SpecialistReportService();
  final ParentComplaintService _complaintService = ParentComplaintService();

  String? _selectedChildId;
  late String _activeSection;
  bool _isLoading = false;

  String? get _effectiveUserId {
    if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
      return widget.currentUserId;
    }
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
    if (widget.initialTabIndex != null) {
      if (widget.initialTabIndex == 1) {
        _activeSection = 'reports';
      } else if (widget.initialTabIndex == 2) {
        _activeSection = 'complaints';
      } else {
        _activeSection = 'overview';
      }
    } else {
      _activeSection = widget.initialSection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _effectiveUserId;

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: const GlobalHeader(
        showBack: true,
        title: 'Specialist & Support',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.screenH, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(color: MeadowColors.primary),
              ),

            // 1. Header Banner
            _buildHeaderBanner(),
            const SizedBox(height: 16),

            // 2. Child Selector
            _buildChildSelector(),
            const SizedBox(height: 16),

            // 3. Section Selector Bar
            _buildSectionSelector(uid ?? ''),
            const SizedBox(height: 20),

            // 4. Section Content
            _buildActiveSectionContent(uid ?? ''),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSectionContent(String uid) {
    Stream<List<SpecialistCaseModel>> casesStream;
    try {
      casesStream = _caseService.getParentCasesStream(uid, childId: _selectedChildId);
    } catch (_) {
      casesStream = Stream.value([]);
    }

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: casesStream,
      builder: (context, caseSnapshot) {
        final cases = caseSnapshot.data ?? [];
        final activeOrPendingIds = cases
            .where((c) =>
                c.status == CaseStatus.accepted ||
                c.status == CaseStatus.active ||
                c.status == CaseStatus.pending)
            .map((c) => c.specialistId)
            .toSet();

        final hasActiveRelationship = cases.any((c) =>
            c.status == CaseStatus.accepted || c.status == CaseStatus.active);

        final childId = _selectedChildId ?? widget.initialChildId ?? '';

        switch (_activeSection) {
          case 'reports':
            return _buildReportsSection(uid, childId: childId);
          case 'complaints':
            return _buildComplaintsSection(uid);
          case 'recommendations':
            return _buildRecommendationsSection(childId);
          case 'consents':
            return _buildContactConsentsSection(uid, cases);
          case 'directory':
            return _buildSpecialistsDirectorySection(activeOrPendingIds, hasActiveRelationship);
          case 'summaries':
            return _buildConsultationSummariesSection(childId);
          case 'overview':
          default:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCasesSection(cases),
                const SizedBox(height: 24),
                _buildReportsSection(uid, childId: childId),
                const SizedBox(height: 24),
                _buildRecommendationsPreviewSection(childId),
                const SizedBox(height: 24),
                _buildContactConsentsPreviewSection(uid),
                const SizedBox(height: 24),
                _buildConsultationSummariesSection(childId),
              ],
            );
        }
      },
    );
  }

  // =========================================================================
  // HEADER BANNER
  // =========================================================================
  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MeadowColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: MeadowColors.primary, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expert Guidance & Specialist Support',
                  style: MeadowTypography.h3.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Collaborate with certified LittleLumin Guides (LLGs) and Clinical Specialists. All data access is protected by explicit DPDP parental consent.',
                  style: MeadowTypography.body.copyWith(
                    fontSize: 12,
                    color: MeadowColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CHILD SELECTOR
  // =========================================================================
  Widget _buildChildSelector() {
    Stream<List<ChildModel>> stream;
    try {
      stream = ChildService().getChildren();
    } catch (_) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<ChildModel>>(
      stream: stream,
      builder: (context, snapshot) {
        final children = snapshot.data ?? [];
        if (children.isEmpty) return const SizedBox.shrink();

        if (_selectedChildId == null && children.isNotEmpty) {
          _selectedChildId = children.first.childId;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: MeadowColors.surface,
            borderRadius: BorderRadius.circular(MeadowRadius.lg),
            border: Border.all(color: MeadowColors.borderLight),
            boxShadow: MeadowShadows.soft,
          ),
          child: Row(
            children: [
              const Icon(Icons.child_care_rounded, color: MeadowColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Reviewing For:',
                style: MeadowTypography.label.copyWith(fontSize: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      value: _selectedChildId,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: MeadowColors.textSecondary),
                      items: children.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.childId,
                          child: Text(
                            '${c.name} (${c.ageYears} yrs)',
                            style: MeadowTypography.body.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedChildId = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // SECTION SELECTOR NAVIGATION PILLS
  // =========================================================================
  Widget _buildSectionSelector(String userId) {
    Stream<List<ContactConsentModel>> stream;
    try {
      stream = _consentService.getIncomingRequestsStream(userId);
    } catch (_) {
      stream = Stream.value([]);
    }
    return StreamBuilder<List<ContactConsentModel>>(
      stream: stream,
      builder: (context, consentSnap) {
        final pendingConsents = consentSnap.data ?? [];
        final pendingCount = pendingConsents.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildNavPill('overview', 'Overview & Guide', Icons.dashboard_outlined),
              const SizedBox(width: 8),
              _buildNavPill('reports', 'Reports', Icons.assessment_outlined),
              const SizedBox(width: 8),
              _buildNavPill('recommendations', 'Recommendations', Icons.lightbulb_outline),
              const SizedBox(width: 8),
              _buildNavPill(
                'consents',
                'Contact Requests',
                Icons.security_outlined,
                badgeCount: pendingCount,
              ),
              const SizedBox(width: 8),
              _buildNavPill('directory', 'Find Specialists', Icons.person_search_outlined),
              const SizedBox(width: 8),
              _buildNavPill('summaries', 'Session Summaries', Icons.assignment_outlined),
              const SizedBox(width: 8),
              _buildNavPill('complaints', 'Complaints', Icons.shield_outlined),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavPill(String sectionId, String label, IconData icon, {int badgeCount = 0}) {
    final isSelected = _activeSection == sectionId;
    return InkWell(
      onTap: () => setState(() => _activeSection = sectionId),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MeadowColors.primary : MeadowColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MeadowColors.primary : MeadowColors.borderLight,
          ),
          boxShadow: isSelected ? MeadowShadows.soft : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : MeadowColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : MeadowColors.textSecondary,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : MeadowColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? MeadowColors.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ASSIGNED GUIDE & CASES SECTION
  // =========================================================================
  Widget _buildCasesSection(List<SpecialistCaseModel> cases) {
    if (cases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: MeadowColors.surface,
          borderRadius: BorderRadius.circular(MeadowRadius.xl),
          border: Border.all(color: MeadowColors.borderLight),
          boxShadow: MeadowShadows.card,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: MeadowColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, color: MeadowColors.primary, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'No Learning Guide Assigned Yet',
              style: MeadowTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Connect with a certified LittleLumin Guide to receive personalized developmental plans, milestone observations, and dedicated consultation.',
              style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _activeSection = 'directory'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Browse Verified Specialists'),
              style: MeadowButtons.small(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: MeadowColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Assigned Guide & Case Status', style: MeadowTypography.h2),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your active consultations and pending requests are listed below.',
          style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cases.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) => _buildParentCaseCard(cases[index]),
        ),
      ],
    );
  }

  Widget _buildParentCaseCard(SpecialistCaseModel c) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (c.status) {
      case CaseStatus.accepted:
      case CaseStatus.active:
        statusColor = MeadowColors.success;
        statusLabel = 'ACTIVE CONSULTATION';
        statusIcon = Icons.check_circle_rounded;
        break;
      case CaseStatus.pending:
        statusColor = MeadowColors.warning;
        statusLabel = 'AWAITING GUIDE ACCEPTANCE';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case CaseStatus.declined:
        statusColor = MeadowColors.textTertiary;
        statusLabel = 'DECLINED';
        statusIcon = Icons.cancel_outlined;
        break;
      case CaseStatus.revoked:
        statusColor = MeadowColors.error;
        statusLabel = 'CONSENT WITHDRAWN';
        statusIcon = Icons.lock_outline;
        break;
      case CaseStatus.completed:
        statusColor = MeadowColors.cognitive;
        statusLabel = 'COMPLETED';
        statusIcon = Icons.task_alt;
        break;
    }

    final isAuthorized = c.canAccessChildData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(
          color: isAuthorized ? MeadowColors.primary.withOpacity(0.3) : MeadowColors.borderLight,
          width: isAuthorized ? 1.5 : 1,
        ),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Text(
                  c.specialistName.isNotEmpty ? c.specialistName[0].toUpperCase() : 'S',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.specialistName,
                            style: MeadowTypography.label.copyWith(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MeadowColors.primarySurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.specialistRole.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: MeadowColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Focus: ${c.purpose}',
                      style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Authorized data categories tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: c.authorizedDataCategories.map((cat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MeadowColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cat.replaceAll('_', ' ').toUpperCase(),
                  style: MeadowTypography.caption.copyWith(fontSize: 9, color: MeadowColors.textSecondary),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Action Buttons: Chat, Direct Contact, Withdraw Consent (Responsive Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isAuthorized) ...[
                ElevatedButton.icon(
                  onPressed: () => _openChat(c),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message Guide'),
                  style: MeadowButtons.small(),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openContactSharingDialog(c),
                  icon: const Icon(Icons.contact_phone_outlined, size: 16),
                  label: const Text('Direct Contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MeadowColors.primary,
                    side: const BorderSide(color: MeadowColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (c.status == CaseStatus.pending)
                TextButton.icon(
                  onPressed: () => _cancelPendingRequest(c),
                  icon: const Icon(Icons.close, size: 15, color: MeadowColors.error),
                  label: const Text('Cancel Request', style: TextStyle(color: MeadowColors.error, fontSize: 12)),
                )
              else if (isAuthorized)
                TextButton.icon(
                  onPressed: () => _confirmWithdrawConsent(c),
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: MeadowColors.error),
                  label: const Text('Withdraw Consent', style: TextStyle(color: MeadowColors.error, fontSize: 12)),
                ),
            ],
          ),

          // Additional parent actions: Rate Specialist & Report Concern (Responsive Wrap)
          const SizedBox(height: 12),
          const Divider(color: MeadowColors.borderLight, height: 1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (c.status == CaseStatus.active || c.status == CaseStatus.accepted || c.status == CaseStatus.completed) ...[
                TextButton.icon(
                  onPressed: () => SpecialistReviewDialog.show(
                    context,
                    parentId: c.parentId,
                    parentName: c.parentName,
                    specialistId: c.specialistId,
                    specialistName: c.specialistName,
                    caseId: c.caseId,
                  ),
                  icon: const Icon(Icons.star_outline_rounded, size: 16, color: MeadowColors.warning),
                  label: const Text('Rate Specialist', style: TextStyle(color: MeadowColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
              ],
              TextButton.icon(
                onPressed: () => ComplaintSubmissionDialog.show(
                  context,
                  parentId: c.parentId,
                  parentName: c.parentName,
                  parentEmail: _auth.currentUser?.email ?? '',
                  specialistId: c.specialistId,
                  specialistName: c.specialistName,
                  caseId: c.caseId,
                ),
                icon: const Icon(Icons.report_problem_outlined, size: 15, color: MeadowColors.textSecondary),
                label: const Text('Report Concern', style: TextStyle(color: MeadowColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),

          // Approved contact details card if available
          _buildApprovedContactInfo(c),
        ],
      ),
    );
  }

  Widget _buildApprovedContactInfo(SpecialistCaseModel c) {
    return StreamBuilder<List<ContactConsentModel>>(
      stream: _consentService.getCaseConsentRequestsStream(c.caseId),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final approvedRequests = requests.where((r) => r.isApproved && r.sharedContactValue != null).toList();

        if (approvedRequests.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MeadowColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MeadowColors.sageLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 16, color: MeadowColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Direct Contact Details (Consent Granted):',
                    style: MeadowTypography.label.copyWith(fontSize: 12, color: MeadowColors.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...approvedRequests.map((req) {
                final isPhoneOrWA = req.requestedItem == ContactItemType.phone || req.requestedItem == ContactItemType.whatsapp;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${req.requestedItem.name.toUpperCase()}: ${req.sharedContactValue}',
                        style: MeadowTypography.body.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (isPhoneOrWA) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _launchWhatsApp(req.sharedContactValue ?? '', c),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'WhatsApp',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // RECOMMENDATIONS SECTION
  // =========================================================================
  Widget _buildRecommendationsPreviewSection(String childId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: MeadowColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('Personalized Recommendations', style: MeadowTypography.h2),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _activeSection = 'recommendations'),
              child: const Text('View All'),
            ),
          ],
        ),
        _buildRecommendationsStream(childId, limit: 2),
      ],
    );
  }

  Widget _buildRecommendationsSection(String childId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: MeadowColors.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('LLG Recommendations & Activity Guidance', style: MeadowTypography.h2),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Personalized activities prescribed by your verified guide based on evaluated developmental needs.',
          style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildRecommendationsStream(childId),
      ],
    );
  }

  Widget _buildRecommendationsStream(String childId, {int? limit}) {
    Stream<List<RecommendationModel>> stream;
    try {
      stream = _recommendationService.getChildRecommendationsStream(childId);
    } catch (_) {
      stream = Stream.value([]);
    }
    return StreamBuilder<List<RecommendationModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        final recs = snapshot.data ?? [];
        if (recs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(MeadowRadius.xl),
              border: Border.all(color: MeadowColors.borderLight),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 36, color: MeadowColors.sage),
                  const SizedBox(height: 8),
                  Text('No Activity Recommendations Yet', style: MeadowTypography.label),
                  const SizedBox(height: 4),
                  Text(
                    'When your guide prescribes personalized activities, they will appear here.',
                    style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final displayList = limit != null ? recs.take(limit).toList() : recs;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayList.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildRecommendationCard(displayList[i]),
        );
      },
    );
  }

  Widget _buildRecommendationCard(RecommendationModel rec) {
    final domainColor = MeadowDomain.colorFor(rec.skillDomain);
    final domainSurface = MeadowDomain.surfaceFor(rec.skillDomain);

    return InkWell(
      onTap: () => _openRecommendationDetail(rec),
      borderRadius: BorderRadius.circular(MeadowRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MeadowColors.surface,
          borderRadius: BorderRadius.circular(MeadowRadius.xl),
          border: Border.all(color: MeadowColors.borderLight),
          boxShadow: MeadowShadows.card,
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: domainSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  MeadowDomain.labelFor(rec.skillDomain),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: domainColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rec.title,
                  style: MeadowTypography.label.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MeadowColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.status.name.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: MeadowColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended by ${rec.llgName} • ${rec.durationMinutes} mins • ${rec.frequency}',
            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontSize: 11),
          ),
          if (rec.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Rationale: ${rec.rationale}',
              style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textPrimary),
            ),
          ],
          if (rec.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...rec.instructions.take(3).map((ins) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $ins', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
            )),
          ],
          if (rec.hasParentResponded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MeadowColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: MeadowColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Response: ${rec.parentResponse.name.replaceAll('_', ' ').toUpperCase()}${rec.parentFeedback != null ? " — \"${rec.parentFeedback}\"" : ""}',
                      style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openRecommendationDetail(rec),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Activity & Steps'),
                style: MeadowButtons.small(),
              ),
              OutlinedButton.icon(
                onPressed: () => _openRecommendationDetail(rec),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: Text(rec.hasParentResponded ? 'Update Response' : 'Submit Response'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeadowColors.primary,
                  side: const BorderSide(color: MeadowColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  void _openRecommendationDetail(RecommendationModel rec) {
    final childId = _selectedChildId ?? widget.initialChildId ?? rec.childId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationDetailScreen(
          recommendation: rec,
          childId: childId,
          childName: rec.childName,
          onResponseSubmitted: () => setState(() {}),
        ),
      ),
    );
  }



  // =========================================================================
  // CONTACT CONSENTS & PRIVACY SECTION
  // =========================================================================
  Widget _buildContactConsentsPreviewSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, color: MeadowColors.motor, size: 20),
                const SizedBox(width: 8),
                Text('Contact Sharing Requests', style: MeadowTypography.h2),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _activeSection = 'consents'),
              child: const Text('Manage'),
            ),
          ],
        ),
        _buildIncomingConsentsStream(userId),
      ],
    );
  }

  Widget _buildContactConsentsSection(String userId, List<SpecialistCaseModel> cases) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.security_rounded, color: MeadowColors.motor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Contact Sharing & Explicit Consent', style: MeadowTypography.h2),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Under DPDP principles, your personal contact details are strictly protected and only shared after your explicit approval.',
          style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Incoming pending requests
        Text('Pending Requests Directed to You', style: MeadowTypography.h3),
        const SizedBox(height: 8),
        _buildIncomingConsentsStream(userId),

        const SizedBox(height: 24),

        // Active Approved Consents for cases
        if (cases.isNotEmpty) ...[
          Text('Active Approved Contact Permissions', style: MeadowTypography.h3),
          const SizedBox(height: 8),
          ...cases.map((c) => _buildApprovedContactInfo(c)),
        ],
      ],
    );
  }

  Widget _buildIncomingConsentsStream(String userId) {
    Stream<List<ContactConsentModel>> stream;
    try {
      stream = _consentService.getIncomingRequestsStream(userId);
    } catch (_) {
      stream = Stream.value([]);
    }
    return StreamBuilder<List<ContactConsentModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(MeadowRadius.xl),
              border: Border.all(color: MeadowColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: MeadowColors.success, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No pending contact requests. Your contact info is safe and private.',
                    style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildIncomingConsentCard(requests[i]),
        );
      },
    );
  }

  Widget _buildIncomingConsentCard(ContactConsentModel req) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.warning.withOpacity(0.5), width: 1.5),
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
                  color: MeadowColors.goldSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: MeadowColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request from ${req.requesterName}',
                      style: MeadowTypography.label.copyWith(fontSize: 14),
                    ),
                    Text(
                      'Requested: ${req.requestedItem.name.toUpperCase()}',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Purpose stated: "${req.purpose}"',
            style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleApproveConsent(req),
                  style: MeadowButtons.small(),
                  child: const Text('Accept & Share'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _handleDeclineConsent(req),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeadowColors.error,
                  side: const BorderSide(color: MeadowColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleApproveConsent(ContactConsentModel req) {
    final contactController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Approve Contact Sharing', style: MeadowTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm sharing your ${req.requestedItem.name.toUpperCase()} with ${req.requesterName} for consultation.',
              style: MeadowTypography.body.copyWith(fontSize: 13, color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactController,
              decoration: InputDecoration(
                labelText: 'Contact Detail to Share (optional override)',
                hintText: 'Leave blank to use profile default',
                hintStyle: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _consentService.respondToRequest(
                  requestId: req.id,
                  approve: true,
                  contactValueIfApproved: contactController.text.trim().isNotEmpty
                      ? contactController.text.trim()
                      : null,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Contact sharing approved.'), backgroundColor: MeadowColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: MeadowColors.error),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: MeadowButtons.small(),
            child: const Text('Confirm & Share'),
          ),
        ],
      ),
    );
  }

  void _handleDeclineConsent(ContactConsentModel req) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Decline Request?', style: MeadowTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to decline contact sharing with ${req.requesterName}?',
              style: MeadowTypography.body.copyWith(fontSize: 13, color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for declining (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: MeadowColors.error, foregroundColor: Colors.white),
            child: const Text('Decline Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _consentService.respondToRequest(
          requestId: req.id,
          approve: false,
          declineReason: reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request declined.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: MeadowColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================================
  // SPECIALIST DIRECTORY SECTION
  // =========================================================================
  Widget _buildSpecialistsDirectorySection(Set<String> activeOrPendingIds, bool hasActiveRelationship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_search_rounded, color: MeadowColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Explore Verified Specialists', style: MeadowTypography.h2),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hasActiveRelationship
              ? 'Your child currently has an assigned guide. You can also connect with specialists for different developmental areas.'
              : 'Browse certified child development professionals and request tailored developmental guidance.',
          style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildSpecialistsList(activeOrPendingIds, hasActiveRelationship),
      ],
    );
  }

  Widget _buildSpecialistsList(Set<String> activeOrPendingIds, bool hasActiveRelationship) {
    Stream<QuerySnapshot> stream;
    try {
      stream = _firestore
          .collection('llgProfiles')
          .where('isVerified', isEqualTo: true)
          .snapshots();
    } catch (_) {
      stream = const Stream.empty();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        final availableDocs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? 'active').toLowerCase();
          if (status == 'suspended' || status == 'deactivated') return false;
          return !activeOrPendingIds.contains(d.id);
        }).toList();

        if (availableDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(MeadowRadius.xl),
              border: Border.all(color: MeadowColors.borderLight),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline, size: 36, color: MeadowColors.success),
                const SizedBox(height: 12),
                Text(
                  activeOrPendingIds.isNotEmpty
                      ? 'All available specialists are already connected in your consultation section.'
                      : 'No other verified specialists available right now.',
                  textAlign: TextAlign.center,
                  style: MeadowTypography.label.copyWith(fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = availableDocs[index].data() as Map<String, dynamic>;
            final llgId = availableDocs[index].id;
            return _buildSpecialistCard(llgId, data, hasActiveRelationship);
          },
        );
      },
    );
  }

  Widget _buildSpecialistCard(String llgId, Map<String, dynamic> data, bool hasActiveRelationship) {
    final name = data['name'] ?? 'Child Specialist';
    final qualification = data['qualification'] ?? 'Development Specialist';
    final experience = data['experience'] ?? '5+ years';
    final specialization = data['specialization'] ?? 'Early Childhood Development';
    final consultationMode = data['consultationMode'] ?? 'Online & In-Person';
    final bio = data['bio'] ?? 'Dedicated to supporting healthy milestones and cognitive growth.';
    final userType = (data['userType'] ?? 'llg').toString().toLowerCase();
    final isClinical = userType.contains('clinical');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: MeadowColors.primarySurface,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MeadowColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: MeadowTypography.label.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: MeadowColors.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qualification • $experience experience',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    _buildRatingRow(data),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge(isClinical ? Icons.medical_services_outlined : Icons.school_outlined, isClinical ? 'Clinical Specialist' : 'Learning Guide'),
              _buildBadge(Icons.psychology_outlined, specialization),
              _buildBadge(Icons.videocam_outlined, consultationMode),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _viewGuideProfile(name, data),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('View Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeadowColors.textPrimary,
                  side: const BorderSide(color: MeadowColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openRequestReviewDialog(llgId, name, userType, hasActiveRelationship),
                  icon: const Icon(Icons.shield_outlined, size: 15),
                  label: Text(hasActiveRelationship ? 'Request Alternative Focus' : 'Authorize Consultation'),
                  style: MeadowButtons.small(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MeadowColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MeadowColors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: MeadowTypography.caption.copyWith(fontSize: 11, color: MeadowColors.textSecondary)),
        ],
      ),
    );
  }

  // =========================================================================
  // CONSULTATION SUMMARIES SECTION
  // =========================================================================
  Widget _buildConsultationSummariesSection(String childId) {
    Stream<List<ConsultationSummaryModel>> stream;
    try {
      stream = _summaryService.getChildSummariesStream(childId);
    } catch (_) {
      stream = Stream.value([]);
    }
    return StreamBuilder<List<ConsultationSummaryModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }

        final summaries = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: MeadowColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Documented Consultation Summaries', style: MeadowTypography.h2),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Official clinical and developmental session notes documented by your specialist.',
              style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: 14),

            if (summaries.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MeadowColors.surface,
                  borderRadius: BorderRadius.circular(MeadowRadius.xl),
                  border: Border.all(color: MeadowColors.borderLight),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.article_outlined, size: 36, color: MeadowColors.sage),
                      const SizedBox(height: 8),
                      Text('No Consultation Summaries Documented Yet', style: MeadowTypography.label),
                      const SizedBox(height: 4),
                      Text(
                        'Session notes and agreed follow-up plans from your specialist will appear here.',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summaries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final s = summaries[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MeadowColors.surface,
                      borderRadius: BorderRadius.circular(MeadowRadius.xl),
                      border: Border.all(color: MeadowColors.borderLight),
                      boxShadow: MeadowShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: MeadowColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.consultationMode.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: MeadowColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'With ${s.llgName}',
                                style: MeadowTypography.label.copyWith(fontSize: 14),
                              ),
                            ),
                            Text(
                              DateFormat.yMMMd().format(s.consultationDate),
                              style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Reason: ${s.consultationReason}', style: MeadowTypography.body.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Guidance: ${s.guidanceProvided}', style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary)),
                        if (s.agreedFollowUpActions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Agreed Actions:', style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold, color: MeadowColors.primary)),
                          ...s.agreedFollowUpActions.map((a) => Padding(
                            padding: const EdgeInsets.only(left: 6, top: 2),
                            child: Text('• $a', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
                          )),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // ACTIONS: CHAT, WHATSAPP, REQUEST CONSULTATION, WITHDRAW CONSENT
  // =========================================================================
  void _openChat(SpecialistCaseModel c) {
    final user = _auth.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          specialistCase: c,
          currentUserId: user.uid,
          currentUserName: user.displayName ?? 'Parent',
          currentUserRole: 'parent',
          otherParticipantName: c.specialistName,
          otherParticipantRole: c.specialistRole,
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone, SpecialistCaseModel c) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.open_in_new, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Text('Open WhatsApp Consultation?', style: MeadowTypography.h3),
          ],
        ),
        content: Text(
          'You are leaving LittleLumin to communicate on WhatsApp.\n\nNotice:\n• External WhatsApp messages are conducted outside LittleLumin.\n• Your guide (${c.specialistName}) will document an authorized Consultation Summary in your child\'s LittleLumin file following your call.',
          style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            child: const Text('Continue to WhatsApp'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final msg = Uri.encodeComponent('Hello ${c.specialistName}, I am contacting you regarding ${c.childName} from LittleLumin.');
      final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open WhatsApp: $e')),
          );
        }
      }
    }
  }

  Future<void> _openContactSharingDialog(SpecialistCaseModel c) async {
    final purposeController = TextEditingController();
    ContactItemType selectedItem = ContactItemType.phone;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Request Contact Sharing', style: MeadowTypography.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request ${c.specialistName}\'s direct contact details under explicit consent.',
                style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ContactItemType>(
                value: selectedItem,
                decoration: InputDecoration(
                  labelText: 'Contact Detail Requested',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: ContactItemType.phone, child: Text('Phone Number')),
                  DropdownMenuItem(value: ContactItemType.whatsapp, child: Text('WhatsApp Number')),
                  DropdownMenuItem(value: ContactItemType.email, child: Text('Email Address')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedItem = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeController,
                decoration: InputDecoration(
                  labelText: 'Reason for Request',
                  hintText: 'e.g. For urgent milestone follow-up call',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final purpose = purposeController.text.trim();
                if (purpose.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please state a reason for this contact request.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _consentService.requestContactSharing(
                    caseId: c.caseId,
                    childId: c.childId,
                    requesterId: _auth.currentUser!.uid,
                    requesterName: _auth.currentUser?.displayName ?? 'Parent',
                    requesterRole: 'parent',
                    recipientId: c.specialistId,
                    recipientName: c.specialistName,
                    recipientRole: c.specialistRole,
                    requestedItem: selectedItem,
                    purpose: purpose,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Contact sharing request submitted to guide.'),
                        backgroundColor: MeadowColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: MeadowColors.error),
                    );
                  }
                }
              },
              style: MeadowButtons.small(),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelPendingRequest(SpecialistCaseModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Consultation Request?'),
        content: Text('Are you sure you want to cancel your pending consultation request with ${c.specialistName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: MeadowColors.error, foregroundColor: Colors.white),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _caseService.revokeConsent(c.caseId, _auth.currentUser!.uid, reason: 'Parent cancelled pending request.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: MeadowColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmWithdrawConsent(SpecialistCaseModel c) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield_moon_outlined, color: MeadowColors.error, size: 24),
            const SizedBox(width: 8),
            Text('Withdraw Consent?', style: MeadowTypography.h3),
          ],
        ),
        content: Text(
          'Are you sure you want to withdraw consent for ${c.specialistName}?\n\nUnder our privacy controls, the specialist\'s access to ${c.childName}\'s developmental progress will be terminated immediately.',
          style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Active')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: MeadowColors.error, foregroundColor: Colors.white),
            child: const Text('Withdraw Consent'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _caseService.revokeConsent(c.caseId, user.uid, reason: 'Parent withdrew consultation consent.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Consent withdrawn. Specialist access terminated immediately.'),
              backgroundColor: MeadowColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to revoke: $e'), backgroundColor: MeadowColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _viewGuideProfile(String name, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: MeadowColors.primarySurface,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'G',
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: MeadowColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: MeadowTypography.h2),
                        const SizedBox(height: 4),
                        Text(data['qualification'] ?? 'Verified Specialist', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: MeadowColors.primary),
                            SizedBox(width: 4),
                            Text('Admin Verified Credentials', style: TextStyle(fontSize: 12, color: MeadowColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: MeadowColors.borderLight),
              const SizedBox(height: 12),
              _buildProfileDetailRow('Specialization', data['specialization'] ?? 'Early Childhood'),
              _buildProfileDetailRow('Experience', data['experience'] ?? '5+ years'),
              _buildProfileDetailRow('Organization', data['organization'] ?? 'LittleLumin Network'),
              _buildProfileDetailRow('Languages', data['languages'] ?? 'English'),
              _buildProfileDetailRow('Modes', data['consultationMode'] ?? 'Online & Clinical'),
              const SizedBox(height: 16),
              Text('About & Clinical Philosophy', style: MeadowTypography.label),
              const SizedBox(height: 6),
              Text(
                data['bio'] ?? 'Dedicated to supporting healthy milestones.',
                style: MeadowTypography.body.copyWith(fontSize: 13, color: MeadowColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: MeadowTypography.body.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestReviewDialog(
    String llgId,
    String llgName,
    String specialistRole,
    bool hasActiveRelationship,
  ) async {
    final noteController = TextEditingController();
    final user = _auth.currentUser;

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a child first.')),
      );
      return;
    }

    final childDoc = await _firestore.collection('children').doc(_selectedChildId).get();
    final childData = childDoc.data() ?? {};
    final childName = childData['name'] ?? 'Child';
    final childAgeYears = (childData['age'] as num?)?.toInt() ?? 4;

    if (!mounted) return;

    String selectedPurpose = 'Developmental Milestone Review';
    bool consentAuthorized = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: MeadowColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Consultation with $llgName',
                  style: MeadowTypography.h3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasActiveRelationship) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MeadowColors.goldSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MeadowColors.gold.withOpacity(0.4)),
                    ),
                    child: Text(
                      'Note: $childName already has an active consultation. You are adding an additional consultation for a specific focus.',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Specify the consultation focus and authorize targeted learning progress sharing for $childName.',
                  style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Text('Consultation Purpose:', style: MeadowTypography.label.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedPurpose,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Developmental Milestone Review', child: Text('Developmental Milestone Review')),
                    DropdownMenuItem(value: 'Learning & Educational Guidance', child: Text('Learning & Educational Guidance')),
                    DropdownMenuItem(value: 'Speech & Language Support', child: Text('Speech & Language Support')),
                    DropdownMenuItem(value: 'Behavioral & Social Guidance', child: Text('Behavioral & Social Guidance')),
                    DropdownMenuItem(value: 'Motor Skills Coordination', child: Text('Motor Skills Coordination')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedPurpose = val);
                  },
                ),
                const SizedBox(height: 14),
                Text('Parent Notes / Specific Questions:', style: MeadowTypography.label.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Share any specific questions or observations (optional)...',
                    hintStyle: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MeadowColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MeadowColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.policy_outlined, size: 16, color: MeadowColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'DPDP Parental Consent Notice (v1.0)',
                            style: MeadowTypography.label.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Authorized Data: $childName\'s name, age ($childAgeYears yrs), verified domain scores, and recent learning activities.\n• Excluded Data: Sensitive birth notes and medical history remain strictly private.\n• Validity: Active for 90 days. You can withdraw consent anytime.',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consentAuthorized,
                  activeColor: MeadowColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'I explicitly authorize sharing the specified learning data with $llgName for this consultation.',
                    style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold),
                  ),
                  onChanged: (val) {
                    setDialogState(() => consentAuthorized = val ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: !consentAuthorized
                  ? null
                  : () async {
                      final notes = noteController.text.trim();
                      final validationError = Validators.notes(notes);
                      if (validationError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(validationError), backgroundColor: MeadowColors.error),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);

                      try {
                        await _caseService.createCaseRequest(
                          parentId: user?.uid ?? '',
                          parentName: user?.displayName ?? 'Parent',
                          childId: _selectedChildId!,
                          childName: childName,
                          childAgeYears: childAgeYears,
                          specialistId: llgId,
                          specialistName: llgName,
                          specialistRole: specialistRole,
                          purpose: selectedPurpose,
                          authorizedDataCategories: ['domain_scores', 'activity_history', 'observations'],
                          parentNotes: notes.isNotEmpty ? notes : null,
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Consultation request submitted! Awaiting guide acceptance.'),
                              backgroundColor: MeadowColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to submit request: $e'), backgroundColor: MeadowColors.error),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              style: MeadowButtons.small(),
              child: const Text('Authorize & Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // RATINGS, REPORTS & COMPLAINTS SECTIONS
  // =========================================================================

  Widget _buildRatingRow(Map<String, dynamic> data) {
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

    if (ratingCount > 0) {
      return Row(
        children: [
          const Icon(Icons.star_rounded, size: 16, color: MeadowColors.warning),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: MeadowTypography.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            '($ratingCount ${ratingCount == 1 ? 'review' : 'reviews'})',
            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontSize: 11),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MeadowColors.borderLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline_rounded, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            'Not yet rated',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection(String parentId, {String? childId}) {
    final effectiveParentId = parentId.isNotEmpty
        ? parentId
        : (_effectiveUserId ?? '');
    final selectedChild = childId ?? _selectedChildId;

    return StreamBuilder<List<SpecialistReportModel>>(
      stream: _reportService.getParentReportsStream(effectiveParentId, childId: selectedChild),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reports: ${snapshot.error}', style: MeadowTypography.body),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(MeadowRadius.xl),
              border: Border.all(color: MeadowColors.borderLight),
            ),
            child: Column(
              children: [
                const Icon(Icons.description_outlined, size: 40, color: MeadowColors.textSecondary),
                const SizedBox(height: 12),
                Text('No Specialist Reports Yet', style: MeadowTypography.h3),
                const SizedBox(height: 6),
                Text(
                  'When your assigned learning guide or developmental specialist finalizes and shares an evaluation report, it will appear here for your review.',
                  textAlign: TextAlign.center,
                  style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assessment_rounded, color: MeadowColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Specialist Developmental Reports', style: MeadowTypography.h2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Official clinical and progress evaluations prepared by your assigned guides.',
              style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = reports[index];
                final isUnread = !report.isReadByParent;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUnread ? MeadowColors.primarySurface.withOpacity(0.5) : MeadowColors.surface,
                    borderRadius: BorderRadius.circular(MeadowRadius.xl),
                    border: Border.all(
                      color: isUnread ? MeadowColors.primary : MeadowColors.borderLight,
                      width: isUnread ? 1.5 : 1,
                    ),
                    boxShadow: MeadowShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    report.title,
                                    style: MeadowTypography.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MeadowColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y').format(report.generatedAt),
                            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Author: ${report.specialistName} • Child: ${report.childName}',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MeadowTypography.body.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _reportService.markReportAsReadByParent(report.id);
                              _showReportDetailsDialog(report);
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('Open & Read Report'),
                            style: MeadowButtons.small(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showReportDetailsDialog(SpecialistReportModel report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: MeadowColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assessment_rounded, color: MeadowColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.title, style: MeadowTypography.h3.copyWith(fontSize: 16)),
                  Text(
                    'Authored by ${report.specialistName} • ${DateFormat('MMM d, y').format(report.generatedAt)}',
                    style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MeadowColors.primarySurface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MeadowColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Executive Summary', style: MeadowTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(report.summary, style: MeadowTypography.body.copyWith(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Strengths
                if (report.strengths.isNotEmpty) ...[
                  Text('Developmental Strengths', style: MeadowTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: MeadowColors.success)),
                  const SizedBox(height: 6),
                  ...report.strengths.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: MeadowColors.success),
                        const SizedBox(width: 6),
                        Expanded(child: Text(s, style: MeadowTypography.body.copyWith(fontSize: 12))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 14),
                ],

                // Growth Areas
                if (report.growthAreas.isNotEmpty) ...[
                  Text('Targeted Growth Areas', style: MeadowTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: MeadowColors.warning)),
                  const SizedBox(height: 6),
                  ...report.growthAreas.map((g) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.trending_up, size: 16, color: MeadowColors.warning),
                        const SizedBox(width: 6),
                        Expanded(child: Text(g, style: MeadowTypography.body.copyWith(fontSize: 12))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 14),
                ],

                // Specialist Recommendations
                if (report.recommendations.isNotEmpty) ...[
                  Text('Specialist Recommendations', style: MeadowTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: MeadowColors.primary)),
                  const SizedBox(height: 6),
                  ...report.recommendations.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: MeadowColors.primary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(r, style: MeadowTypography.body.copyWith(fontSize: 12))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: MeadowButtons.small(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsSection(String parentId) {
    return StreamBuilder<List<ParentComplaintModel>>(
      stream: _complaintService.getParentComplaintsStream(parentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }

        final complaints = snapshot.data ?? [];

        if (complaints.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(MeadowRadius.xl),
              border: Border.all(color: MeadowColors.borderLight),
            ),
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, size: 40, color: MeadowColors.textSecondary),
                const SizedBox(height: 12),
                Text('No Concerns or Complaints Filed', style: MeadowTypography.h3),
                const SizedBox(height: 6),
                Text(
                  'If you ever experience issues regarding professional conduct, missed sessions, or safety concerns with a learning guide, you can file a confidential report from your consultation card.',
                  textAlign: TextAlign.center,
                  style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: MeadowColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('My Filed Concerns & Complaints', style: MeadowTypography.h2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Confidential reports submitted for administrative review.',
              style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: complaints.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final complaint = complaints[index];

                Color badgeBg = Colors.grey.shade200;
                Color badgeFg = Colors.black87;
                String statusText = complaint.status.replaceAll('_', ' ').toUpperCase();

                if (complaint.isPending) {
                  badgeBg = const Color(0xFFFEF3C7);
                  badgeFg = const Color(0xFFD97706);
                } else if (complaint.isUnderInvestigation) {
                  badgeBg = const Color(0xFFE0E7FF);
                  badgeFg = const Color(0xFF4338CA);
                } else if (complaint.isResolved) {
                  badgeBg = const Color(0xFFD1FAE5);
                  badgeFg = const Color(0xFF059669);
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MeadowColors.surface,
                    borderRadius: BorderRadius.circular(MeadowRadius.xl),
                    border: Border.all(color: MeadowColors.borderLight),
                    boxShadow: MeadowShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            complaint.categoryDisplayName,
                            style: MeadowTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              statusText,
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specialist: ${complaint.specialistName} • Submitted: ${DateFormat('MMM d, y').format(complaint.createdAt)}',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(complaint.description, style: MeadowTypography.body.copyWith(fontSize: 13)),
                      if (complaint.resolutionSummary != null && complaint.resolutionSummary!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Administrative Resolution:', style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                              const SizedBox(height: 2),
                              Text(complaint.resolutionSummary!, style: MeadowTypography.body.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
