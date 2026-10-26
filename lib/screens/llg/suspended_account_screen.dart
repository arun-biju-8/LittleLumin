// lib/screens/llg/suspended_account_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/llg_appeal_service.dart';
import '../../models/admin_models.dart';
import '../auth/login_page.dart';

class SuspendedAccountScreen extends StatefulWidget {
  const SuspendedAccountScreen({super.key});

  @override
  State<SuspendedAccountScreen> createState() => _SuspendedAccountScreenState();
}

class _SuspendedAccountScreenState extends State<SuspendedAccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LLGAppealService _appealService = LLGAppealService();

  bool _isSubmittingAppeal = false;
  final TextEditingController _appealController = TextEditingController();

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showAppealDialog(String llgId, String llgName, String llgEmail, String suspensionReason) {
    _appealController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: Color(0xFF14B8A6), size: 24),
              const SizedBox(width: 10),
              Text(
                'Submit Review Appeal',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provide context, clarifications, or evidence for the administrative review committee.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _appealController,
                  maxLines: 5,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your detailed explanation or response...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF14B8A6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: _isSubmittingAppeal
                  ? null
                  : () async {
                      final text = _appealController.text.trim();
                      if (text.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide at least 10 characters in your appeal.')),
                        );
                        return;
                      }

                      setDialogState(() => _isSubmittingAppeal = true);
                      try {
                        await _appealService.submitAppeal(
                          llgId: llgId,
                          llgName: llgName,
                          llgEmail: llgEmail,
                          suspensionReason: suspensionReason,
                          appealText: text,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your appeal was submitted successfully for administrative review.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error submitting appeal: $e')),
                        );
                      } finally {
                        setDialogState(() => _isSubmittingAppeal = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmittingAppeal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Appeal'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final uid = user?.uid ?? '';

    // Non-dismissible: cannot pop back into authenticated shell while suspended
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 10),
              Text(
                'LittleLumin Specialist Portal',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Color(0xFF94A3B8), size: 18),
              label: Text('Sign Out', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() ?? {};
            final llgName = userData['name'] as String? ?? 'Learning Guide';
            final llgEmail = userData['email'] as String? ?? user?.email ?? '';
            final reason = userData['suspensionReason'] as String? ?? 'Administrative policy compliance review';
            final category = userData['suspensionCategory'] as String? ?? 'Safety & Compliance';
            final isTemporary = userData['isTemporarySuspension'] as bool? ?? false;

            DateTime? suspendedAt;
            final rawSuspendedAt = userData['suspendedAt'];
            if (rawSuspendedAt is Timestamp) suspendedAt = rawSuspendedAt.toDate();

            DateTime? suspensionUntil;
            final rawSuspensionUntil = userData['suspensionUntil'];
            if (rawSuspensionUntil is Timestamp) suspensionUntil = rawSuspensionUntil.toDate();

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Badge & Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.lock_person_outlined, color: Color(0xFFEF4444), size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Account Access Suspended',
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Specialist: $llgName',
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: Color(0xFF334155)),
                            const SizedBox(height: 16),

                            // Detail Rows
                            _buildInfoRow('Account Status', 'Suspended', isWarning: true),
                            _buildInfoRow('Category', category),
                            _buildInfoRow(
                              'Suspension Type',
                              isTemporary
                                  ? 'Temporary (${suspensionUntil != null ? DateFormat('MMM d, y').format(suspensionUntil) : 'Specified Duration'})'
                                  : 'Indefinite',
                            ),
                            if (suspendedAt != null)
                              _buildInfoRow('Effective Date', DateFormat('MMM d, y (h:mm a)').format(suspendedAt)),
                            _buildInfoRow('Reason Provided', reason),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Appeals Stream Card
                      StreamBuilder<List<LLGAppealModel>>(
                        stream: _appealService.getAppealsForLLGStream(uid),
                        builder: (context, appealSnap) {
                          final appeals = appealSnap.data ?? [];
                          final latestAppeal = appeals.isNotEmpty ? appeals.first : null;

                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.balance_outlined, color: Color(0xFF14B8A6), size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Review & Appeal Procedure',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'As a registered LittleLumin specialist, you have the right to request an administrative review or appeal regarding this suspension decision.',
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), height: 1.5),
                                ),
                                const SizedBox(height: 16),

                                if (latestAppeal != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Appeal Status',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                                            ),
                                            _buildAppealStatusBadge(latestAppeal.status),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Submitted on ${DateFormat('MMM d, y (h:mm a)').format(latestAppeal.createdAt)}',
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          latestAppeal.appealText,
                                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0)),
                                        ),
                                        if (latestAppeal.adminNotes != null && latestAppeal.adminNotes!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          const Divider(color: Color(0xFF334155)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Administrative Review Response:',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF14B8A6)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            latestAppeal.adminNotes!,
                                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0)),
                                          ),
                                        ],
                                        if (latestAppeal.restorationConditions != null && latestAppeal.restorationConditions!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Conditions for Restoration: ${latestAppeal.restorationConditions!.join(', ')}',
                                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Submit Appeal Action
                                if (latestAppeal == null || latestAppeal.isRejected)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAppealDialog(uid, llgName, llgEmail, reason),
                                      icon: const Icon(Icons.send_rounded, size: 18),
                                      label: Text(
                                        latestAppeal == null ? 'Submit Review Appeal' : 'Submit Revised Appeal',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF14B8A6),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Sign Out Button
                      OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, size: 18, color: Color(0xFF94A3B8)),
                        label: Text('Sign Out of LittleLumin', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isWarning ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealStatusBadge(String status) {
    Color bg = const Color(0xFF334155);
    Color fg = Colors.white;
    String label = status.toUpperCase();

    if (status == 'pending') {
      bg = const Color(0xFFF59E0B).withOpacity(0.2);
      fg = const Color(0xFFF59E0B);
      label = 'UNDER REVIEW';
    } else if (status == 'approved') {
      bg = const Color(0xFF10B981).withOpacity(0.2);
      fg = const Color(0xFF10B981);
      label = 'APPROVED';
    } else if (status == 'rejected') {
      bg = const Color(0xFFEF4444).withOpacity(0.2);
      fg = const Color(0xFFEF4444);
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
