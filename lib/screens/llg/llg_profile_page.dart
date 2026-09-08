// lib/screens/llg/llg_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/constants.dart';
import '../landing_page.dart';

class LLGProfilePage extends StatefulWidget {
  const LLGProfilePage({super.key});

  @override
  State<LLGProfilePage> createState() => _LLGProfilePageState();
}

class _LLGProfilePageState extends State<LLGProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingPageWidget()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text('No active user'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('llgProfiles')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, profileSnapshot) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              final userData = userSnapshot.data?.data() ?? {};
              final profileData = profileSnapshot.data?.data() ?? {};

              final name = userData['name'] ?? currentUser!.displayName ?? 'LLG Guide';
              final email = userData['email'] ?? currentUser!.email ?? '';
              final isVerified = userData['isVerified'] == true || profileData['isVerified'] == true;

              final qualification = profileData['qualification'] ?? userData['qualification'] ?? 'N/A';
              final license = profileData['license'] ?? userData['license'] ?? 'N/A';
              final experience = profileData['experience'] ?? userData['experience'] ?? 'N/A';
              final specialization = profileData['specialization'] ?? userData['specialization'] ?? 'N/A';
              final organization = profileData['organization'] ?? userData['organization'] ?? 'N/A';
              final region = profileData['region'] ?? userData['region'] ?? 'N/A';
              final languages = profileData['languages'] ?? userData['languages'] ?? 'N/A';
              final consultationMode = profileData['consultationMode'] ?? userData['consultationMode'] ?? 'Online & In-Person';
              final bio = profileData['bio'] ?? userData['bio'] ?? '';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                    const SizedBox(height: 10),

                                    // VERIFICATION BADGE (Task 33)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isVerified
                                            ? AppColors.success.withValues(alpha: 0.15)
                                            : Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isVerified ? AppColors.success : Colors.orange,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                                            size: 16,
                                            color: isVerified ? AppColors.success : Colors.orange,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isVerified ? 'Verified LLG Guide' : 'Pending Verification',
                                            style: TextStyle(
                                              color: isVerified ? AppColors.success : Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Professional Info Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Professional Qualifications',
                                style: AppTextStyles.heading2.copyWith(fontSize: 16),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            children: [
                              _infoBlock('Qualification', qualification),
                              _infoBlock('License / Registration', license),
                              _infoBlock('Years Experience', experience),
                              _infoBlock('Specialization', specialization),
                              _infoBlock('Organization', organization),
                              _infoBlock('Region / Location', region),
                              _infoBlock('Languages', languages),
                              _infoBlock('Consultation Mode', consultationMode),
                            ],
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Bio & Guidance Philosophy:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                bio,
                                style: TextStyle(color: Colors.grey[800], fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      label: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
