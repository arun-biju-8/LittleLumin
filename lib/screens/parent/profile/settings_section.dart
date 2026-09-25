import 'package:flutter/material.dart';
import '../parent_theme.dart';

class SettingsSection extends StatelessWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final bool darkModeEnabled;
  final ValueChanged<bool> onDarkModeChanged;
  final String currentLanguage;
  final VoidCallback onLanguageTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;
  final VoidCallback onHelpTap;
  final VoidCallback onRateTap;

  const SettingsSection({
    super.key,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.darkModeEnabled,
    required this.onDarkModeChanged,
    required this.currentLanguage,
    required this.onLanguageTap,
    required this.onPrivacyTap,
    required this.onTermsTap,
    required this.onHelpTap,
    required this.onRateTap,
  });

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        boxShadow: ParentShadows.card,
        border: Border.all(color: ParentColors.surfaceAlt, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Settings Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            '⚙️ Settings',
            style: ParentTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: ParentColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildCard(
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              secondary: _buildIconContainer(Icons.notifications_none_rounded, ParentColors.primary),
              title: Text('Notifications', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Activity reminders and milestone updates', style: ParentTypography.caption),
              activeColor: ParentColors.primary,
              value: notificationsEnabled,
              onChanged: onNotificationsChanged,
            ),
            Divider(height: 1, indent: 68, color: ParentColors.surfaceAlt),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              secondary: _buildIconContainer(Icons.dark_mode_outlined, ParentColors.primary),
              title: Text('Dark Mode', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Night reading theme', style: ParentTypography.caption),
              activeColor: ParentColors.primary,
              value: darkModeEnabled,
              onChanged: onDarkModeChanged,
            ),
            Divider(height: 1, indent: 68, color: ParentColors.surfaceAlt),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: _buildIconContainer(Icons.language_rounded, ParentColors.primary),
              title: Text('Language', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLanguage,
                    style: ParentTypography.caption.copyWith(color: ParentColors.primary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: ParentColors.textTertiary),
                ],
              ),
              onTap: onLanguageTap,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // About Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'ℹ️ About & Support',
            style: ParentTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: ParentColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildCard(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: _buildIconContainer(Icons.privacy_tip_outlined, const Color(0xFF06B6D4)),
              title: Text('Privacy Policy', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ParentColors.textTertiary),
              onTap: onPrivacyTap,
            ),
            Divider(height: 1, indent: 68, color: ParentColors.surfaceAlt),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: _buildIconContainer(Icons.description_outlined, const Color(0xFF3B82F6)),
              title: Text('Terms of Service', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ParentColors.textTertiary),
              onTap: onTermsTap,
            ),
            Divider(height: 1, indent: 68, color: ParentColors.surfaceAlt),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: _buildIconContainer(Icons.help_outline_rounded, ParentColors.warning),
              title: Text('Help & Support', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ParentColors.textTertiary),
              onTap: onHelpTap,
            ),
            Divider(height: 1, indent: 68, color: ParentColors.surfaceAlt),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: _buildIconContainer(Icons.star_outline_rounded, ParentColors.accent),
              title: Text('Rate the App', style: ParentTypography.body.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ParentColors.textTertiary),
              onTap: onRateTap,
            ),
          ],
        ),
      ],
    );
  }
}
