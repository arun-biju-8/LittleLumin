// lib/screens/parent/llg_connect_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../services/specialist_case_service.dart';
import '../../models/contact_consent_model.dart';
import '../../services/contact_consent_service.dart';
import '../../services/consultation_summary_service.dart';
import '../../utils/validators.dart';
import '../../widgets/global_header.dart';
import '../chat/chat_screen.dart';

class LLGConnectPage extends StatefulWidget {
  final String? initialChildId;

  const LLGConnectPage({super.key, this.initialChildId});

  @override
  State<LLGConnectPage> createState() => _LLGConnectPageState();
}

class _LLGConnectPageState extends State<LLGConnectPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpecialistCaseService _caseService = SpecialistCaseService();
  final ContactConsentService _consentService = ContactConsentService();
  final ConsultationSummaryService _summaryService = ConsultationSummaryService();

  String? _selectedChildId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const GlobalHeader(
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            _buildHeaderBanner(),
            const SizedBox(height: 24),
            _buildChildSelector(),
            const SizedBox(height: 24),

            // Stream user's cases for the selected child to drive discovery separation
            if (user != null && _selectedChildId != null)
              StreamBuilder<List<SpecialistCaseModel>>(
                stream: _caseService.getParentCasesStream(user.uid, childId: _selectedChildId),
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Your Selected Guide & Consultation Requests
                      _buildCasesSection(cases),
                      const SizedBox(height: 32),

                      // Section 2: Explore Other Guides (Separated & Filtered)
                      _buildExploreHeader(hasActiveRelationship),
                      const SizedBox(height: 16),
                      _buildSpecialistsList(activeOrPendingIds, hasActiveRelationship),
                    ],
                  );
                },
              )
            else
              const Center(child: CircularProgressIndicator()),

            const SizedBox(height: 32),
            _buildConsultationSummariesSection(),
            const SizedBox(height: 32),
            _buildObservationsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expert Guidance for Your Child',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect with verified LittleLumin Guides (LLGs) and Clinical Specialists. All requests are backed by explicit DPDP parental consent.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
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

  Widget _buildChildSelector() {
    return StreamBuilder<List<ChildModel>>(
      stream: ChildService().getChildren(),
      builder: (context, snapshot) {
        final children = snapshot.data ?? [];
        if (children.isEmpty) return const SizedBox.shrink();

        if (_selectedChildId == null && children.isNotEmpty) {
          _selectedChildId = children.first.childId;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.child_care, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 12),
              Text(
                'Reviewing For:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _selectedChildId,
                underline: const SizedBox.shrink(),
                items: children.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.childId,
                    child: Text(
                      '${c.name} (${c.ageYears} yrs)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedChildId = val);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCasesSection(List<SpecialistCaseModel> cases) {
    if (cases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF0EA5E9), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'No active guide or pending requests for this child yet. Choose a verified specialist below to begin consultation.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
              ),
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
            const Icon(Icons.shield_outlined, color: Color(0xFF0EA5E9), size: 20),
            const SizedBox(width: 8),
            Text(
              'Your Selected Guide & Consultation Requests',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your active consultations and pending requests are listed below. Each consultation is isolated with explicit consent.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cases.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildParentCaseCard(cases[index]);
          },
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
        statusColor = const Color(0xFF10B981);
        statusLabel = 'ACTIVE CONSULTATION';
        statusIcon = Icons.check_circle_outline;
        break;
      case CaseStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'AWAITING GUIDE ACCEPTANCE';
        statusIcon = Icons.hourglass_top_outlined;
        break;
      case CaseStatus.declined:
        statusColor = const Color(0xFF64748B);
        statusLabel = 'DECLINED';
        statusIcon = Icons.cancel_outlined;
        break;
      case CaseStatus.revoked:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'CONSENT WITHDRAWN';
        statusIcon = Icons.lock_outline;
        break;
      case CaseStatus.completed:
        statusColor = const Color(0xFF0EA5E9);
        statusLabel = 'COMPLETED';
        statusIcon = Icons.task_alt;
        break;
    }

    final isClinical = c.specialistRole.contains('clinical');
    final isAuthorized = c.canAccessChildData;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.status == CaseStatus.revoked
              ? const Color(0xFFFEE2E2)
              : (isAuthorized ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFE2E8F0)),
          width: isAuthorized ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.specialistName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isClinical ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isClinical ? 'Clinical Specialist' : 'Learning Guide',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isClinical ? const Color(0xFF4F46E5) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Purpose: ${c.purpose}',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
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
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Categories authorized
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: c.authorizedDataCategories.map((cat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cat.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF334155), fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Action Buttons: Chat, Contact Request, WhatsApp, Withdraw Consent
          Row(
            children: [
              if (isAuthorized) ...[
                ElevatedButton.icon(
                  onPressed: () => _openChat(c),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message Guide'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openContactSharingDialog(c),
                  icon: const Icon(Icons.contact_phone_outlined, size: 16),
                  label: const Text('Contact Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0EA5E9),
                    side: const BorderSide(color: Color(0xFF0EA5E9)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              const Spacer(),
              if (c.status == CaseStatus.pending)
                TextButton.icon(
                  onPressed: () => _cancelPendingRequest(c),
                  icon: const Icon(Icons.close, size: 15, color: Colors.redAccent),
                  label: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                )
              else if (isAuthorized)
                TextButton.icon(
                  onPressed: () => _confirmWithdrawConsent(c),
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                  label: const Text('Withdraw Consent', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ),
            ],
          ),

          // Stream contact sharing status for this case
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
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Text(
                    'Direct Contact Details (Consent Granted):',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...approvedRequests.map((req) {
                final isPhoneOrWA = req.requestedItem == ContactItemType.phone || req.requestedItem == ContactItemType.whatsapp;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        '${req.requestedItem.name.toUpperCase()}: ${req.sharedContactValue}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                      ),
                      if (isPhoneOrWA) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _launchWhatsApp(req.sharedContactValue ?? '', c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'WhatsApp',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
    // Clean phone number
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.open_in_new, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Text('Open WhatsApp Consultation?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'You are leaving LittleLumin to communicate on WhatsApp.\n\nNotice:\n• External WhatsApp messages are conducted outside LittleLumin.\n• Your guide (${c.specialistName}) will document an authorized Consultation Summary in your child\'s LittleLumin file following your call.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
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
          title: Text('Request Contact Sharing', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request ${c.specialistName}\'s direct contact details under explicit consent.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
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
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
            const Icon(Icons.shield_moon_outlined, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text('Withdraw Consent?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to withdraw consent for ${c.specialistName}?\n\nUnder our privacy controls, the specialist\'s access to ${c.childName}\'s developmental progress will be terminated immediately.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
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
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to revoke: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildExploreHeader(bool hasActiveRelationship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore Other Guides & Specialists',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasActiveRelationship
              ? 'Your child currently has an active assigned guide above. You can view profiles of other verified guides or request an alternative for a different developmental focus.'
              : 'Browse certified child development professionals and request tailored developmental guidance.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialistsList(Set<String> activeOrPendingIds, bool hasActiveRelationship) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('llgProfiles')
          .where('isVerified', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        // Filter out specialists already requested or active so user is never confused!
        final availableDocs = docs.where((d) => !activeOrPendingIds.contains(d.id)).toList();

        if (availableDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline, size: 40, color: Color(0xFF10B981)),
                const SizedBox(height: 12),
                Text(
                  activeOrPendingIds.isNotEmpty
                      ? 'All available specialists are already connected in your consultation section above.'
                      : 'No other verified specialists available right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                    fontSize: 14,
                  ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isClinical
                    ? const Color(0xFF4F46E5).withOpacity(0.12)
                    : const Color(0xFF0EA5E9).withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isClinical ? const Color(0xFF4F46E5) : const Color(0xFF0EA5E9),
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
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 18, color: Color(0xFF0EA5E9)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qualification • $experience experience',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(
                isClinical ? Icons.medical_services_outlined : Icons.school_outlined,
                isClinical ? 'Clinical Specialist' : 'Learning Guide',
              ),
              _buildBadge(Icons.psychology_outlined, specialization),
              _buildBadge(Icons.videocam_outlined, consultationMode),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _viewGuideProfile(name, data),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openRequestReviewDialog(llgId, name, userType, hasActiveRelationship),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: Text(hasActiveRelationship ? 'Request Alternative Focus' : 'Authorize & Request Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClinical ? const Color(0xFF4F46E5) : const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
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
                    backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'G',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(data['qualification'] ?? 'Verified Specialist', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.verified, size: 16, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 4),
                            Text('Admin Verified Credentials', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildProfileDetailRow('Specialization', data['specialization'] ?? 'Early Childhood'),
              _buildProfileDetailRow('Experience', data['experience'] ?? '5+ years'),
              _buildProfileDetailRow('Organization', data['organization'] ?? 'LittleLumin Network'),
              _buildProfileDetailRow('Languages', data['languages'] ?? 'English'),
              _buildProfileDetailRow('Modes', data['consultationMode'] ?? 'Online & Clinical'),
              const SizedBox(height: 16),
              Text('About & Clinical Philosophy', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                data['bio'] ?? 'Dedicated to supporting healthy milestones.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
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
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
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
              const Icon(Icons.verified_user_outlined, color: Color(0xFF0EA5E9), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Consultation with $llgName',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: Text(
                      'Note: $childName already has an active consultation. You are adding an additional consultation for a specific focus.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Specify the consultation focus and authorize targeted learning progress sharing for $childName.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Consultation Purpose:',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
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
                const SizedBox(height: 16),
                Text(
                  'Parent Notes / Specific Questions:',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Share any specific questions or observations (optional)...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.policy_outlined, size: 16, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 6),
                          Text(
                            'DPDP Parental Consent Notice (v1.0)',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Authorized Data: $childName\'s name, age ($childAgeYears yrs), verified domain scores, and recent learning activities.\n• Excluded Data: Sensitive birth notes, medical history, and other children remain strictly private.\n• Validity: Active for 90 days. You can withdraw consent anytime.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consentAuthorized,
                  activeColor: const Color(0xFF0EA5E9),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'I explicitly authorize sharing the specified learning data with $llgName for this consultation.',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  ),
                  onChanged: (val) {
                    setDialogState(() => consentAuthorized = val ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: !consentAuthorized
                  ? null
                  : () async {
                      final notes = noteController.text.trim();
                      final validationError = Validators.notes(notes);
                      if (validationError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(validationError), backgroundColor: Colors.red),
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
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to submit request: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
              child: const Text('Authorize & Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationSummariesSection() {
    if (_selectedChildId == null) return const SizedBox.shrink();

    return StreamBuilder<List<dynamic>>(
      stream: _summaryService.getChildSummariesStream(_selectedChildId!),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? [];
        if (summaries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documented Consultation Summaries (${summaries.length})',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Official notes from sessions conducted with your specialist.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article_outlined, color: Color(0xFF0EA5E9), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Session with ${s.llgName} (${s.consultationMode})',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat.yMMMd().format(s.consultationDate),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Guidance Provided:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                      const SizedBox(height: 2),
                      Text(s.guidanceProvided, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
                      if (s.agreedFollowUpActions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Agreed Actions:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                        ...s.agreedFollowUpActions.map((a) => Text('• $a', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)))),
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

  Widget _buildObservationsSection() {
    if (_selectedChildId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('llgObservations')
          .where('childId', isEqualTo: _selectedChildId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Past Specialist Observations',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final obs = docs[idx].data() as Map<String, dynamic>;
                final llgName = obs['llgName'] ?? 'Specialist';
                final observation = obs['observation'] ?? '';
                final severity = obs['severity'] ?? 'normal';
                final recommendations = List<String>.from(obs['recommendations'] ?? []);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF0EA5E9), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Observation by $llgName',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: severity == 'critical'
                                  ? Colors.red.withOpacity(0.1)
                                  : (severity == 'high'
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              severity.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: severity == 'critical'
                                    ? Colors.red
                                    : (severity == 'high' ? Colors.orange : Colors.blue),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        observation,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), height: 1.4),
                      ),
                      if (recommendations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Recommendations:',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        ...recommendations.map((r) => Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
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
}
