// lib/screens/parent/llg_connect_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
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
            Text(
              'Verified Child Development Guides (LLG)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All specialists are verified by administrators with valid licenses and clinical credentials.',
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

  Widget _buildSpecialistCard(String llgId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Child Specialist';
    final qualification = data['qualification'] ?? 'Development Specialist';
    final experience = data['experience'] ?? '5+ years';
    final specialization = data['specialization'] ?? 'Early Childhood Development';
    final consultationMode = data['consultationMode'] ?? 'Online & Clinical';
    final bio = data['bio'] ?? 'Dedicated to supporting healthy milestones and cognitive growth.';

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
                backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0EA5E9),
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
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
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
              _buildBadge(Icons.school_outlined, specialization),
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
              onPressed: () => _openRequestReviewDialog(llgId, name),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Request Specialist Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
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

  Future<void> _openRequestReviewDialog(String llgId, String llgName) async {
    final noteController = TextEditingController();
    final user = _auth.currentUser;

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a child first.')),
      );
      return;
    }

    final childDoc = await _firestore.collection('children').doc(_selectedChildId).get();
    final childName = childDoc.data()?['name'] ?? 'Child';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Request Review from $llgName',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A notification will be sent to the specialist regarding $childName\'s recent activity and milestones.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Text(
              'Parent Notes / Concerns:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe areas of concern or questions (optional)...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
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
                // 1. Notify the LLG
                await _firestore.collection('notifications').add({
                  'userId': llgId,
                  'type': 'review_requested',
                  'childId': _selectedChildId,
                  'childName': childName,
                  'parentId': user?.uid ?? '',
                  'parentName': user?.displayName ?? 'Parent',
                  'title': 'Review Requested for $childName',
                  'body': notes.isNotEmpty ? notes : 'Parent has requested specialist review and observation.',
                  'readAt': null,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // 2. Notify Admin
                await _firestore.collection('notifications').add({
                  'userId': 'admin',
                  'type': 'review_requested',
                  'childId': _selectedChildId,
                  'llgId': llgId,
                  'title': 'Specialist Review Requested',
                  'body': 'Parent requested review for $childName with $llgName',
                  'readAt': null,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Review request submitted to specialist.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('❌ Error submitting review request: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
          ),
        ],
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
