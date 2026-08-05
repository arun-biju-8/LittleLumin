// lib/screens/admin/admin_home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _totalUsers = 0;
  int _totalChildren = 0;
  int _flaggedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final userSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final childSnapshot = await FirebaseFirestore.instance.collection('children').get();
    final flaggedSnapshot = await FirebaseFirestore.instance
        .collection('children')
        .where('isFlagged', isEqualTo: true)
        .get();

    setState(() {
      _totalUsers = userSnapshot.docs.length;
      _totalChildren = childSnapshot.docs.length;
      _flaggedCount = flaggedSnapshot.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Smaller heading
        Text(
          'Welcome, Admin!',
          style: AppTextStyles.heading2.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          'Platform overview',
          style: AppTextStyles.bodyLight.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 16),

        // ✅ Smaller tiles grid
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: isWeb ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _buildSmallStatCard('Users', _totalUsers, Icons.people, AppColors.primary),
            _buildSmallStatCard('Children', _totalChildren, Icons.child_care, AppColors.success),
            _buildSmallStatCard('Flagged', _flaggedCount, Icons.flag, AppColors.warning),
            _buildSmallStatCard('Total', _totalUsers + _totalChildren, Icons.analytics, AppColors.secondary),
          ],
        ),
      ],
    );
  }

  // ✅ Smaller stat card
  Widget _buildSmallStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: AppTextStyles.heading2.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: AppTextStyles.small.copyWith(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}