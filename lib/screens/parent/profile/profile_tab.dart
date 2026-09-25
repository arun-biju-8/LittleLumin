import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/validators.dart';
import '../../landing_page.dart';
import '../parent_theme.dart';
import '../../../widgets/global_header.dart';
import 'settings_section.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileTab({super.key, this.onProfileUpdated});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  String _displayName = 'Parent';
  String _email = '';

  // Settings states
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  final String _currentLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _displayName = user.displayName?.isNotEmpty == true ? user.displayName! : 'Parent';
      _email = user.email ?? '';
    });

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _userData = doc.data();
            if (_userData?['name'] != null && _userData!['name'].toString().isNotEmpty) {
              _displayName = _userData!['name'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _userData?['phone'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
          title: Text('Edit Profile', style: ParentTypography.cardTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: ParentTypography.body,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, color: ParentColors.primary),
                    border: OutlineInputBorder(borderRadius: ParentRadius.input),
                  ),
                  validator: Validators.name,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: ParentTypography.body,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined, color: ParentColors.primary),
                    border: OutlineInputBorder(borderRadius: ParentRadius.input),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    return Validators.phone(val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final newName = nameController.text.trim();
                final newPhone = phoneController.text.trim();

                Navigator.pop(dialogCtx);
                setState(() => _isLoading = true);

                try {
                  final user = _auth.currentUser;
                  if (user != null) {
                    await user.updateDisplayName(newName);
                    await _firestore.collection('users').doc(user.uid).set({
                      'name': newName,
                      if (newPhone.isNotEmpty) 'phone': newPhone,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (mounted) {
                      setState(() {
                        _displayName = newName;
                        if (_userData != null) {
                          _userData!['name'] = newName;
                          _userData!['phone'] = newPhone;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Profile updated successfully!'),
                          backgroundColor: ParentColors.success,
                        ),
                      );
                      widget.onProfileUpdated?.call();
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: ParentColors.error),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text(title, style: ParentTypography.cardTitle),
        content: SingleChildScrollView(
          child: Text(content, style: ParentTypography.body.copyWith(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text('Log Out?', style: ParentTypography.cardTitle.copyWith(color: ParentColors.error)),
        content: Text('Are you sure you want to log out of LittleLumin?', style: ParentTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              await _auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingPageWidget()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentColors.surfaceAlt,
      appBar: const GlobalHeader(
        showBack: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Centered 80x80 Avatar with gradient ring
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ParentColors.primaryGradient,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: ParentColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _displayName,
                    style: ParentTypography.title.copyWith(fontSize: 22),
                  ),
                  if (_email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _email,
                      style: ParentTypography.caption,
                    ),
                  ],
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ParentColors.primary,
                      side: const BorderSide(color: ParentColors.primaryLight),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      shape: const RoundedRectangleBorder(
                        borderRadius: ParentRadius.chip,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: ParentColors.surfaceAlt, thickness: 1.5),
                  const SizedBox(height: 16),

                  // Settings Section
                  SettingsSection(
                    notificationsEnabled: _notificationsEnabled,
                    onNotificationsChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                    },
                    darkModeEnabled: _darkModeEnabled,
                    onDarkModeChanged: (val) {
                      setState(() => _darkModeEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Dark mode enabled' : 'Dark mode disabled'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    currentLanguage: _currentLanguage,
                    onLanguageTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('English is currently the active language.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    onPrivacyTap: () => _showInfoDialog(
                      'Privacy Policy',
                      'LittleLumin values your family\'s privacy. All developmental assessments, activities, and photos are securely encrypted and never shared with unauthorized parties without your explicit consent.',
                    ),
                    onTermsTap: () => _showInfoDialog(
                      'Terms of Service',
                      'By using LittleLumin, you agree to engage in parent-guided educational activities. LittleLumin provides developmental guidance and is not a substitute for clinical pediatric diagnoses.',
                    ),
                    onHelpTap: () => _showInfoDialog(
                      'Help & Support',
                      'Need help? Reach out to our parenting and technical support team at support@littlelumin.com or connect with a verified Ladybird Learning Guide in the app.',
                    ),
                    onRateTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⭐ Thank you for rating LittleLumin 5 stars!'),
                          backgroundColor: ParentColors.accent,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Divider(color: ParentColors.surfaceAlt, thickness: 1.5),
                  const SizedBox(height: 16),

                  // Logout: Red-tinted card with centered button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: ParentRadius.card,
                      border: Border.all(color: ParentColors.error.withOpacity(0.25), width: 1.2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: ParentRadius.card,
                        onTap: _confirmLogout,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout_rounded, size: 20, color: ParentColors.error),
                              const SizedBox(width: 8),
                              Text(
                                'Log Out of LittleLumin',
                                style: ParentTypography.button.copyWith(
                                  color: ParentColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
