// lib/screens/admin/admin_analytics_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Platform Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Overview Metric Cards
            _buildStatsGrid(isWeb),
            const SizedBox(height: AppSpacing.lg),

            // Middle Section: User Distribution & Role Breakdown
            if (isWeb)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildUserTypeChart()),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 4, child: _buildPlatformHealthCard()),
                ],
              )
            else ...[
              _buildUserTypeChart(),
              const SizedBox(height: AppSpacing.md),
              _buildPlatformHealthCard(),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Bottom Section: Real-time Activity & Feedback Feed
            _buildActivityStats(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. STATS METRICS GRID
  // ===========================================================================

  Widget _buildStatsGrid(bool isWeb) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, userSnap) {
        final totalUsers = userSnap.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('children').snapshots(),
          builder: (context, childSnap) {
            final totalChildren = childSnap.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('feedback').snapshots(),
              builder: (context, feedbackSnap) {
                final totalFeedback = feedbackSnap.data?.docs.length ?? 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('activities').snapshots(),
                  builder: (context, activitySnap) {
                    final totalActivities = activitySnap.data?.docs.length ?? 0;

                    final cards = [
                      _buildMetricCard(
                        title: 'TOTAL USERS',
                        value: '$totalUsers',
                        subtitle: 'Registered accounts',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF4F46E5),
                      ),
                      _buildMetricCard(
                        title: 'ENROLLED CHILDREN',
                        value: '$totalChildren',
                        subtitle: 'Developmental profiles',
                        icon: Icons.child_care_rounded,
                        color: const Color(0xFF059669),
                      ),
                      _buildMetricCard(
                        title: 'ACTIVITY FEEDBACK',
                        value: '$totalFeedback',
                        subtitle: 'Completed sessions',
                        icon: Icons.reviews_rounded,
                        color: const Color(0xFFD97706),
                      ),
                      _buildMetricCard(
                        title: 'CURATED ACTIVITIES',
                        value: '$totalActivities',
                        subtitle: 'Learning catalog',
                        icon: Icons.auto_stories_rounded,
                        color: const Color(0xFF9333EA),
                      ),
                    ];

                    return GridView.count(
                      crossAxisCount: isWeb ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: isWeb ? 1.7 : 1.35,
                      children: cards,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade600,
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. USER TYPE DISTRIBUTION BREAKDOWN
  // ===========================================================================

  Widget _buildUserTypeChart() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCardWrapper(
            title: '👥 User Distribution',
            subtitle: 'Breakdown of platform participants by role',
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final total = docs.length;

        int parentCount = 0;
        int llgCount = 0;
        int pendingCount = 0;
        int adminCount = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['userType'] ?? 'parent';
          switch (type) {
            case 'llg':
              llgCount++;
              break;
            case 'llg_pending':
              pendingCount++;
              break;
            case 'admin':
              adminCount++;
              break;
            case 'parent':
            default:
              parentCount++;
              break;
          }
        }

        return _buildCardWrapper(
          title: '👥 User Distribution',
          subtitle: '$total total platform participants across 4 role categories',
          child: Column(
            children: [
              _buildDistributionRow(
                label: 'Parents',
                count: parentCount,
                total: total,
                color: const Color(0xFF3B82F6),
                icon: Icons.family_restroom_rounded,
              ),
              const SizedBox(height: 14),
              _buildDistributionRow(
                label: 'Verified LLG Guides',
                count: llgCount,
                total: total,
                color: const Color(0xFF10B981),
                icon: Icons.verified_user_rounded,
              ),
              const SizedBox(height: 14),
              _buildDistributionRow(
                label: 'Pending LLG Applications',
                count: pendingCount,
                total: total,
                color: const Color(0xFFF59E0B),
                icon: Icons.pending_actions_rounded,
              ),
              const SizedBox(height: 14),
              _buildDistributionRow(
                label: 'System Administrators',
                count: adminCount,
                total: total,
                color: const Color(0xFFEF4444),
                icon: Icons.admin_panel_settings_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDistributionRow({
    required String label,
    required int count,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final double percent = total > 0 ? (count / total) : 0.0;
    final int percentInt = (percent * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              ' ($percentInt%)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. PLATFORM HEALTH CARD
  // ===========================================================================

  Widget _buildPlatformHealthCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('children').snapshots(),
      builder: (context, childSnap) {
        final totalChildren = childSnap.data?.docs.length ?? 0;
        final flaggedCount = childSnap.data?.docs
                .where((doc) => (doc.data() as Map<String, dynamic>)['isFlagged'] == true)
                .length ??
            0;

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .where('userType', isEqualTo: 'llg_pending')
              .snapshots(),
          builder: (context, pendingSnap) {
            final pendingApprovals = pendingSnap.data?.docs.length ?? 0;

            return _buildCardWrapper(
              title: '⚡ System Highlights',
              subtitle: 'Key attention & triage indicators',
              child: Column(
                children: [
                  _buildHealthItem(
                    title: 'Pending LLG Approvals',
                    value: '$pendingApprovals',
                    status: pendingApprovals > 0 ? 'Action Needed' : 'All Clear',
                    isAlert: pendingApprovals > 0,
                    icon: Icons.hourglass_top_rounded,
                  ),
                  const Divider(height: 24),
                  _buildHealthItem(
                    title: 'Flagged Child Cases',
                    value: '$flaggedCount',
                    status: flaggedCount > 0 ? '$flaggedCount under review' : 'No Flags',
                    isAlert: flaggedCount > 0,
                    icon: Icons.flag_rounded,
                  ),
                  const Divider(height: 24),
                  _buildHealthItem(
                    title: 'Children with Profiles',
                    value: '$totalChildren',
                    status: 'Active learners',
                    isAlert: false,
                    icon: Icons.child_friendly_rounded,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHealthItem({
    required String title,
    required String value,
    required String status,
    required bool isAlert,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isAlert ? Colors.orange.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isAlert ? Colors.orange.shade800 : Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: isAlert ? Colors.orange.shade800 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isAlert ? Colors.orange.shade800 : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. REAL-TIME ACTIVITY & FEEDBACK FEED
  // ===========================================================================

  Widget _buildActivityStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('feedback')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCardWrapper(
            title: '💬 Recent Activity Feedback Feed',
            subtitle: 'Live stream of completed parent & child sessions',
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildCardWrapper(
            title: '💬 Recent Activity Feedback Feed',
            subtitle: 'Live stream of completed parent & child sessions',
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.feedback_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No feedback submitted yet',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Parent activity completions will stream here in real time',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildCardWrapper(
          title: '💬 Recent Activity Feedback Feed',
          subtitle: 'Live stream of the latest ${docs.length} completed sessions',
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final childResponse = data['childResponse']?.toString() ?? 'completed';
              final engagement = data['engagement']?.toString() ?? 'standard';
              final difficulty = data['difficulty']?.toString() ?? 'appropriate';
              final notes = data['notes']?.toString() ?? '';
              final createdAt = data['createdAt'];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _getResponseColor(childResponse).withOpacity(0.15),
                      child: Icon(
                        _getResponseIcon(childResponse),
                        size: 18,
                        color: _getResponseColor(childResponse),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Response: ${childResponse.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatRelativeTime(createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip('Engagement: $engagement', Colors.purple),
                              _buildChip('Difficulty: $difficulty', Colors.teal),
                            ],
                          ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                '"$notes"',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }

  Color _getResponseColor(String response) {
    switch (response.toLowerCase()) {
      case 'positive':
      case 'loved_it':
      case 'engaged':
        return Colors.green;
      case 'challenging':
      case 'frustrated':
        return Colors.red;
      case 'neutral':
        return Colors.blue;
      default:
        return Colors.deepPurple;
    }
  }

  IconData _getResponseIcon(String response) {
    switch (response.toLowerCase()) {
      case 'positive':
      case 'loved_it':
      case 'engaged':
        return Icons.sentiment_very_satisfied_rounded;
      case 'challenging':
      case 'frustrated':
        return Icons.sentiment_dissatisfied_rounded;
      case 'neutral':
        return Icons.sentiment_neutral_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  String _formatRelativeTime(dynamic timestamp) {
    if (timestamp == null) return 'Recent';
    try {
      final date = (timestamp as Timestamp).toDate();
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  // ===========================================================================
  // HELPER CARD WRAPPER
  // ===========================================================================

  Widget _buildCardWrapper({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }
}
