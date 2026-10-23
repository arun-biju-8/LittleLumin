// lib/screens/parent/llg_connect_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../services/specialist_case_service.dart';
import '../../utils/validators.dart';
import '../../widgets/global_header.dart';

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

  String? _selectedChildId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
  }

  @override
  Widget build(BuildContext context) {
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
            if (_isLoading) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
            _buildHeaderBanner(),
            const SizedBox(height: 24),
            _buildChildSelector(),
            const SizedBox(height: 24),
            _buildActiveCasesSection(),
            const SizedBox(height: 32),
            Text(
              'Verified Specialists & Learning Guides',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All specialists are verified by administrators with valid professional credentials. Sharing requires your explicit, case-specific consent.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            _buildSpecialistsList(),
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
                  'Receive clinical notes, milestone observations, and actionable recommendations from verified development specialists.',
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
          padding: const EdgeInsets.all(16),
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

  Widget _buildSpecialistsList() {
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
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.person_search_outlined, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  'No Verified Specialists Available Right Now',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our administrators are currently reviewing specialist credentials.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final llgId = docs[index].id;
            return _buildSpecialistCard(llgId, data);
          },
        );
      },
    );
  }

  Widget _buildActiveCasesSection() {
    final user = _auth.currentUser;
    if (user == null || _selectedChildId == null) return const SizedBox.shrink();

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getParentCasesStream(user.uid, childId: _selectedChildId),
      builder: (context, snapshot) {
        final cases = snapshot.data ?? [];
        if (cases.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF0EA5E9), size: 20),
                const SizedBox(width: 8),
                Text(
                  'My Consultation Requests & Active Cases (${cases.length})',
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
              'Case-specific consent is active. You can review scope or withdraw consent at any time.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cases.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final c = cases[index];
                return _buildParentCaseCard(c);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildParentCaseCard(SpecialistCaseModel c) {
    Color statusColor;
    String statusLabel;
    switch (c.status) {
      case CaseStatus.accepted:
      case CaseStatus.active:
        statusColor = const Color(0xFF10B981);
        statusLabel = 'ACTIVE CONSULTATION';
        break;
      case CaseStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'AWAITING SPECIALIST ACCEPTANCE';
        break;
      case CaseStatus.declined:
        statusColor = const Color(0xFF64748B);
        statusLabel = 'DECLINED';
        break;
      case CaseStatus.revoked:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'CONSENT WITHDRAWN';
        break;
      case CaseStatus.completed:
        statusColor = const Color(0xFF0EA5E9);
        statusLabel = 'COMPLETED';
        break;
    }

    final isClinical = c.specialistRole.contains('clinical');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.status == CaseStatus.revoked ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
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
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Icon(
                  c.status == CaseStatus.revoked ? Icons.lock_outline : Icons.assignment_outlined,
                  color: statusColor,
                  size: 20,
                ),
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
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
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
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requested: ${DateFormat.yMMMd().format(c.consentedAt)} • DPDP ${c.consentNoticeVersion}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              if (c.status == CaseStatus.pending || c.status == CaseStatus.accepted || c.status == CaseStatus.active)
                TextButton.icon(
                  onPressed: () => _confirmWithdrawConsent(c),
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                  label: const Text('Withdraw Consent', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildSpecialistCard(String llgId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Child Specialist';
    final qualification = data['qualification'] ?? 'Development Specialist';
    final experience = data['experience'] ?? '5+ years';
    final specialization = data['specialization'] ?? 'Early Childhood Development';
    final consultationMode = data['consultationMode'] ?? 'Online & Clinical';
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
                backgroundColor: isClinical ? const Color(0xFF4F46E5).withOpacity(0.12) : const Color(0xFF0EA5E9).withOpacity(0.12),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openRequestReviewDialog(llgId, name, userType),
              icon: const Icon(Icons.shield_outlined, size: 16),
              label: const Text('Authorize & Request Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isClinical ? const Color(0xFF4F46E5) : const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
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

  Future<void> _openRequestReviewDialog(String llgId, String llgName, String specialistRole) async {
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
                    DropdownMenuItem(
                      value: 'Developmental Milestone Review',
                      child: Text('Developmental Milestone Review'),
                    ),
                    DropdownMenuItem(
                      value: 'Learning & Educational Guidance',
                      child: Text('Learning & Educational Guidance'),
                    ),
                    DropdownMenuItem(
                      value: 'Speech & Language Support',
                      child: Text('Speech & Language Support'),
                    ),
                    DropdownMenuItem(
                      value: 'Behavioral & Social Guidance',
                      child: Text('Behavioral & Social Guidance'),
                    ),
                    DropdownMenuItem(
                      value: 'Motor Skills Coordination',
                      child: Text('Motor Skills Coordination'),
                    ),
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
                // DPDP Parental Consent Box
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
                              content: Text('✅ Case consultation request and consent submitted.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('❌ Error submitting case request: $e');
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

  Widget _buildObservationsSection() {
    if (_selectedChildId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('llgObservations')
          .where('childId', isEqualTo: _selectedChildId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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
