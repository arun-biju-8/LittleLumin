import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../models/child_model.dart';
import '../../../theme/meadow_theme.dart';
import '../../../widgets/global_header.dart';
import '../profile_page.dart';
import '../children/children_tab.dart';
import '../llg_connect_page.dart';
import '../notifications_page.dart';
import '../../landing_page.dart';

class MoreTab extends StatelessWidget {
  final ChildModel? activeChild;
  final List<ChildModel> children;
  final ValueChanged<ChildModel>? onChildSelected;
  final VoidCallback? onAddChild;
  final VoidCallback? onRefresh;

  const MoreTab({
    super.key,
    this.activeChild,
    this.children = const [],
    this.onChildSelected,
    this.onAddChild,
    this.onRefresh,
  });

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  void _openChildren(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildrenTab(
          children: children,
          activeChild: activeChild,
          onChildSelected: (child) {
            onChildSelected?.call(child);
            Navigator.pop(context);
          },
          onRefresh: () => onRefresh?.call(),
          showBack: true,
        ),
      ),
    );
  }

  void _openExpertSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LLGConnectPage()),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon in an upcoming update!'),
        backgroundColor: MeadowColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoDialog(BuildContext context, {required String title, required String content}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.lg)),
        title: Text(title, style: MeadowTypography.h2),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: MeadowTypography.body.copyWith(height: 1.6, color: MeadowColors.textSecondary),
          ),
        ),
        actions: [
          ElevatedButton(
            style: MeadowButtons.primary().copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(80, 44)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.lg)),
        title: Text('Log Out?', style: MeadowTypography.h2.copyWith(color: MeadowColors.error)),
        content: Text(
          'Are you sure you want to log out of LittleLumin?',
          style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: MeadowTypography.button.copyWith(color: MeadowColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MeadowColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              if (context.mounted) {
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
    String parentName = 'Parent';
    String parentEmail = 'parent@littlelumin.com';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.displayName?.isNotEmpty == true) {
        parentName = user!.displayName!;
      }
      if (user?.email?.isNotEmpty == true) {
        parentEmail = user!.email!;
      }
    } catch (_) {}
    final initial = parentName.isNotEmpty ? parentName[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: const GlobalHeader(
        showBack: false,
        title: 'More',
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.screenH, vertical: MeadowSpacing.lg),
        children: [
          // Header
          Text('More', style: MeadowTypography.display),
          const SizedBox(height: MeadowSpacing.xs),
          Text(
            'Settings, family profiles & resources',
            style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: MeadowSpacing.xl),

          // 1. Parent Profile Card
          InkWell(
            onTap: () => _openProfile(context),
            borderRadius: BorderRadius.circular(MeadowRadius.xl),
            child: Container(
              padding: const EdgeInsets.all(MeadowSpacing.xl),
              decoration: BoxDecoration(
                color: MeadowColors.surface,
                borderRadius: BorderRadius.circular(MeadowRadius.xl),
                border: Border.all(color: MeadowColors.borderLight),
                boxShadow: MeadowShadows.card,
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [MeadowColors.primaryLight, MeadowColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: MeadowTypography.h1.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: MeadowSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parentName, style: MeadowTypography.h2),
                        const SizedBox(height: 2),
                        Text(
                          parentEmail,
                          style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MeadowColors.textTertiary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: MeadowSpacing.xxl),

          // 2. FAMILY SECTION
          _buildSectionHeader('FAMILY'),
          _buildGroupContainer([
            _buildMenuItem(
              icon: Icons.child_care_rounded,
              iconColor: MeadowColors.primary,
              iconBgColor: MeadowColors.primarySurface,
              title: 'Children',
              subtitle: '${children.length} child ${children.length == 1 ? "profile" : "profiles"}',
              onTap: () => _openChildren(context),
            ),
            const Divider(height: 1, indent: 64, color: MeadowColors.borderLight),
            _buildMenuItem(
              icon: Icons.edit_note_rounded,
              iconColor: MeadowColors.sage,
              iconBgColor: MeadowColors.surfaceAlt,
              title: 'Parent Journal',
              subtitle: 'Milestone reflections & notes',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MeadowColors.primarySurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.pill),
                ),
                child: Text(
                  'Coming Soon',
                  style: MeadowTypography.caption.copyWith(
                    color: MeadowColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              onTap: () => _showComingSoon(context, 'Parent Journal'),
            ),
          ]),

          const SizedBox(height: MeadowSpacing.xxl),

          // 3. LITTLELUMIN SECTION
          _buildSectionHeader('LITTLELUMIN'),
          _buildGroupContainer([
            _buildMenuItem(
              icon: Icons.support_agent_rounded,
              iconColor: MeadowColors.social,
              iconBgColor: MeadowColors.socialSurface,
              title: 'Expert Support',
              subtitle: 'Connect with pediatric specialists',
              onTap: () => _openExpertSupport(context),
            ),
            const Divider(height: 1, indent: 64, color: MeadowColors.borderLight),
            _buildMenuItem(
              icon: Icons.notifications_none_rounded,
              iconColor: MeadowColors.gold,
              iconBgColor: MeadowColors.goldSurface,
              title: 'Notifications',
              subtitle: 'Activity reminders & growth alerts',
              onTap: () => _openNotifications(context),
            ),
            const Divider(height: 1, indent: 64, color: MeadowColors.borderLight),
            _buildMenuItem(
              icon: Icons.palette_outlined,
              iconColor: MeadowColors.cognitive,
              iconBgColor: MeadowColors.cognitiveSurface,
              title: 'Appearance',
              trailing: Text(
                'Light (Default)',
                style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
              ),
              onTap: () => _showComingSoon(context, 'Appearance Themes'),
            ),
            const Divider(height: 1, indent: 64, color: MeadowColors.borderLight),
            _buildMenuItem(
              icon: Icons.language_rounded,
              iconColor: MeadowColors.language,
              iconBgColor: MeadowColors.languageSurface,
              title: 'Language',
              trailing: Text(
                'English',
                style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
              ),
              onTap: () => _showComingSoon(context, 'Multi-language Support'),
            ),
          ]),

          const SizedBox(height: MeadowSpacing.xxl),

          // 4. PRIVACY SECTION
          _buildSectionHeader('PRIVACY & SUPPORT'),
          _buildGroupContainer([
            _buildMenuItem(
              icon: Icons.privacy_tip_outlined,
              iconColor: MeadowColors.primaryLight,
              iconBgColor: MeadowColors.primarySurface,
              title: 'Privacy Policy',
              onTap: () => _showInfoDialog(
                context,
                title: 'Privacy Policy',
                content:
                    'LittleLumin is committed to protecting your and your child\'s personal data. All activity responses, milestone records, and feedback entries are encrypted and stored in secure HIPAA-conscious cloud infrastructure. We do not sell or monetize personal learning telemetry.',
              ),
            ),
            const Divider(height: 1, indent: 64, color: MeadowColors.borderLight),
            _buildMenuItem(
              icon: Icons.description_outlined,
              iconColor: MeadowColors.primaryLight,
              iconBgColor: MeadowColors.primarySurface,
              title: 'Terms of Service',
              onTap: () => _showInfoDialog(
                context,
                title: 'Terms of Service',
                content:
                    'By using LittleLumin, you agree to engage with screen-free parent-guided developmental activities designed for children aged 2-10. Professional recommendations from LLG specialists are supportive and do not replace formal clinical diagnostic advice.',
              ),
            ),
            const Divider(height: 1, indent: 64, color: MeadowColors.borderLight),
            _buildMenuItem(
              icon: Icons.help_outline_rounded,
              iconColor: MeadowColors.primaryLight,
              iconBgColor: MeadowColors.primarySurface,
              title: 'Help & FAQ',
              onTap: () => _showInfoDialog(
                context,
                title: 'Help & FAQ',
                content:
                    'Need assistance with your account, activities, or specialist recommendations? Contact our support care team anytime at support@littlelumin.com.',
              ),
            ),
          ]),

          const SizedBox(height: MeadowSpacing.xxl),

          // 5. LOGOUT BUTTON
          InkWell(
            onTap: () => _confirmLogout(context),
            borderRadius: BorderRadius.circular(MeadowRadius.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: MeadowSpacing.lg, horizontal: MeadowSpacing.xl),
              decoration: BoxDecoration(
                color: MeadowColors.surface,
                borderRadius: BorderRadius.circular(MeadowRadius.lg),
                border: Border.all(color: MeadowColors.error.withOpacity(0.3)),
                boxShadow: MeadowShadows.card,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: MeadowColors.error, size: 22),
                  const SizedBox(width: MeadowSpacing.sm),
                  Text(
                    'Log Out',
                    style: MeadowTypography.button.copyWith(
                      color: MeadowColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: MeadowSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: MeadowSpacing.xs, bottom: MeadowSpacing.sm),
      child: Text(
        title,
        style: MeadowTypography.caption.copyWith(
          color: MeadowColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.lg, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle, style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary))
            : null,
        trailing: trailing ??
            const Icon(
              Icons.chevron_right_rounded,
              color: MeadowColors.textTertiary,
              size: 22,
            ),
        onTap: onTap,
      ),
    );
  }
}
