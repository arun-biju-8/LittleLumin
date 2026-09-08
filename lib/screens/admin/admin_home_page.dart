// lib/screens/admin/admin_home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import 'create_llg_page.dart';
import 'llg_detail_page.dart';

class AdminHomePage extends StatefulWidget {
  final Function(int)? onNavigate;

  const AdminHomePage({super.key, this.onNavigate});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  void _openCreateLLGModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
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
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '👨‍🏫 Register New LLG Guide',
                  style: AppTextStyles.heading2.copyWith(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const Expanded(child: CreateLLGPage()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(context, isWeb),
          const SizedBox(height: AppSpacing.lg),

          // Stats Cards
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('userType', isEqualTo: 'llg')
                .snapshots(),
            builder: (context, llgSnapshot) {
              final llgCount = llgSnapshot.data?.docs.length ?? 0;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('children').snapshots(),
                builder: (context, childSnapshot) {
                  final totalChildren = childSnapshot.data?.docs.length ?? 0;
                  final flaggedCount = childSnapshot.data?.docs
                          .where((doc) => doc['isFlagged'] == true)
                          .length ??
                      0;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('activities').snapshots(),
                    builder: (context, activitySnapshot) {
                      final activityCount = activitySnapshot.data?.docs.length ?? 0;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isWeb ? 4 : 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: isWeb ? 1.7 : 1.3,
                        children: [
                          _buildStatCard(
                            title: 'REGISTERED LLGS',
                            value: '$llgCount',
                            subtitle: 'Active LittleLumin Guides',
                            icon: Icons.supervisor_account_rounded,
                            color: AppColors.primary,
                            onTap: () => widget.onNavigate?.call(1),
                          ),
                          _buildStatCard(
                            title: 'TOTAL CHILDREN',
                            value: '$totalChildren',
                            subtitle: 'Enrolled Parent Profiles',
                            icon: Icons.child_care_rounded,
                            color: AppColors.success,
                            onTap: () => widget.onNavigate?.call(2),
                          ),
                          _buildStatCard(
                            title: 'PRIORITY FLAGGED',
                            value: '$flaggedCount',
                            subtitle: 'Requires Casework Review',
                            icon: Icons.flag_rounded,
                            color: AppColors.warning,
                            onTap: () => widget.onNavigate?.call(3),
                          ),
                          _buildStatCard(
                            title: 'ACTIVITIES HUB',
                            value: '$activityCount',
                            subtitle: 'Global Learning Library',
                            icon: Icons.auto_stories_rounded,
                            color: Colors.purple,
                            onTap: () => widget.onNavigate?.call(5),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Quick Actions
          Text(
            '⚡ Admin Quick Actions',
            style: AppTextStyles.heading2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                _buildQuickActionCard(
                  title: 'Register LLG Guide',
                  subtitle: 'Create & onboard a new LLG Guide practitioner account',
                  icon: Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  buttonText: '+ Register Guide',
                  onTap: () => _openCreateLLGModal(context),
                ),
                _buildQuickActionCard(
                  title: 'User Directory',
                  subtitle: 'Inspect all registered parents, guides, and admin accounts',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.secondary,
                  buttonText: 'View Directory',
                  onTap: () => widget.onNavigate?.call(2),
                ),
                _buildQuickActionCard(
                  title: 'Flagged Cases',
                  subtitle: 'Review flagged child developmental profiles & intervention logs',
                  icon: Icons.flag_rounded,
                  color: AppColors.warning,
                  buttonText: 'Review Cases',
                  onTap: () => widget.onNavigate?.call(3),
                ),
              ];

              return isWide
                  ? Row(
                      children: cards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.md),
                                  child: c,
                                ),
                              ))
                          .toList(),
                    )
                  : Column(
                      children: cards
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: c,
                              ))
                          .toList(),
                    );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Recent LLG List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '👨‍🏫 Registered LLG Guides',
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
              ),
              TextButton.icon(
                onPressed: () => widget.onNavigate?.call(1),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All LLGs'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('userType', isEqualTo: 'llg')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.supervisor_account_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No LLG Guides Registered Yet',
                        style: AppTextStyles.heading2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Register your first LittleLumin Guide to start assigning casework.',
                        style: AppTextStyles.bodyLight,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () => _openCreateLLGModal(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Register First LLG Guide'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length > 5 ? 5 : docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final llgId = docs[index].id;
                    final name = data['name'] ?? 'Unknown LLG';
                    final email = data['email'] ?? 'No email';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'L',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(email, style: AppTextStyles.small),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LLGDetailPage(llgId: llgId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chevron_right, size: 16),
                        label: const Text('View Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.08),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // Hero Banner
  Widget _buildHeroBanner(BuildContext context, bool isWeb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 700;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroText(isMobile),
                    const SizedBox(height: AppSpacing.md),
                    _buildHeroActions(context, isMobile),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildHeroText(isMobile)),
                    const SizedBox(width: AppSpacing.lg),
                    _buildHeroActions(context, isMobile),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHeroText(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '🛡️ LittleLumin Executive Portal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Platform Administration & Governance',
          style: AppTextStyles.heading1.copyWith(
            color: Colors.white,
            fontSize: isMobile ? 20 : 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Monitor registered guides, child developmental progress, system activity, and user management.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: isMobile ? 12 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroActions(BuildContext context, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => _openCreateLLGModal(context),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('+ Register Guide'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: isMobile ? 10 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // Stat Card
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
              ],
            ),
            Text(
              value,
              style: AppTextStyles.heading1.copyWith(
                fontSize: 28,
                color: AppColors.textDark,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.small.copyWith(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Quick Action Card — Fixed (No context parameter)
  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.small.copyWith(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}