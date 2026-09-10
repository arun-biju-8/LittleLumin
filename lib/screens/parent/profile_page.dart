// lib/screens/parent/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/child_model.dart';
import '../../utils/constants.dart';
import '../landing_page.dart';
import 'edit_child_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _userData;
  int _childCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChildCount();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        _userData = doc.data();
        _nameController.text = _userData?['name'] ?? '';
        _emailController.text = _userData?['email'] ?? '';
        _phoneController.text = _userData?['phone'] ?? '';
      });
    }
  }

  Future<void> _loadChildCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('children')
        .where('parentId', isEqualTo: user.uid)
        .get();

    setState(() {
      _childCount = snapshot.docs.length;
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update display name in Auth
      await user.updateDisplayName(_nameController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Profile', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = _userData?['name'] ?? '';
                  _phoneController.text = _userData?['phone'] ?? '';
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Avatar Section — FIXED
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      _userData?['name']?.isNotEmpty == true
                          ? _userData?['name']?[0]?.toUpperCase() ?? 'P'
                          : 'P',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _userData?['name'] ?? 'Parent',
                    style: AppTextStyles.heading1.copyWith(fontSize: 22),
                  ),
                  Text(
                    _userData?['userType']?.toUpperCase() ?? 'PARENT',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Children',
                    '$_childCount',
                    Icons.child_care,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildStatCard(
                    'Completed Activities',
                    '0',
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildStatCard(
                    'Stars Earned',
                    '0',
                    Icons.star,
                    AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Edit Form
            Card(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: AppTextStyles.heading2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _buildProfileField(
                        label: 'Full Name',
                        value: _userData?['name'] ?? '',
                        controller: _nameController,
                        icon: Icons.person_outline,
                        enabled: _isEditing,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _buildProfileField(
                        label: 'Email',
                        value: _userData?['email'] ?? '',
                        controller: _emailController,
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _buildProfileField(
                        label: 'Phone',
                        value: _userData?['phone'] ?? '',
                        controller: _phoneController,
                        icon: Icons.phone_outlined,
                        enabled: _isEditing,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (_isEditing)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppBorderRadius.medium),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Save Changes',
                                    style: AppTextStyles.button,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Connected Children
            Card(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connected Children',
                          style: AppTextStyles.heading2.copyWith(fontSize: 18),
                        ),
                        Row(
                          children: [
                            if (_childCount > 0)
                              Text(
                                '$_childCount',
                                style: AppTextStyles.small.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              tooltip: 'Add Child',
                              onPressed: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const EditChildPage()),
                                );
                                if (res == true) {
                                  _loadUserData();
                                  _loadChildCount();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('children')
                          .where('parentId',
                              isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final children = snapshot.data!.docs;
                        if (children.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Column(
                                children: [
                                  Text(
                                    'No children added yet',
                                    style: AppTextStyles.bodyLight,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final res = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const EditChildPage()),
                                      );
                                      if (res == true) {
                                        _loadUserData();
                                        _loadChildCount();
                                      }
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add First Child'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: children.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final childModel = ChildModel.fromMap(data);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  childModel.name.isNotEmpty ? childModel.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(childModel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${childModel.ageDisplay} • ${childModel.gender}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (childModel.isFlagged)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(Icons.flag, color: Colors.red, size: 18),
                                    ),
                                  const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                ],
                              ),
                              onTap: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditChildPage(child: childModel),
                                  ),
                                );
                                if (res == true) {
                                  _loadUserData();
                                  _loadChildCount();
                                }
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ✅ App Settings Section
            Card(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings & Preferences',
                      style: AppTextStyles.heading2.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Notification Preferences
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.notifications_outlined, color: Colors.blue.shade700),
                      ),
                      title: const Text('Notification Preferences'),
                      subtitle: const Text('Activity reminders and milestone updates'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Notification Settings'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SwitchListTile(
                                  title: const Text('Daily Activity Reminders'),
                                  value: true,
                                  onChanged: (val) {},
                                ),
                                SwitchListTile(
                                  title: const Text('LLG Guide Messages'),
                                  value: true,
                                  onChanged: (val) {},
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),

                    // Privacy Settings
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.lock_outline, color: Colors.green.shade700),
                      ),
                      title: const Text('Privacy Settings'),
                      subtitle: const Text('Data sharing and account privacy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Privacy Settings'),
                            content: const Text(
                              'LittleLumin protects your child\'s personal data with end-to-end cloud encryption. Only authorized caseworkers and parents can view developmental activity records.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),

                    // App Theme
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.palette_outlined, color: Colors.purple.shade700),
                      ),
                      title: const Text('App Theme'),
                      subtitle: const Text('System Light Mode'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App theme set to System Default (Light)')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ✅ Logout Button — FIXED
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout?'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final authService = Provider.of<AuthService>(context,
                        listen: false);
                    await authService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LandingPageWidget()),
                        (route) => false,
                      );
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                ),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  'Logout',
                  style: AppTextStyles.button.copyWith(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Version Info
            Center(
              child: Text(
                'LittleLumin v1.0.0',
                style: AppTextStyles.small.copyWith(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(fontSize: 18),
          ),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
            color: enabled ? AppColors.textDark : Colors.grey[600],
          ),
          validator: (v) {
            if (label == 'Full Name' && (v == null || v.isEmpty)) {
              return 'Please enter your name';
            }
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: !enabled,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }
}