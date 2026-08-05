// lib/screens/admin/manage_users_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class ManageUsersPage extends StatelessWidget {
  const ManageUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '👥 Manage Users',
          style: AppTextStyles.heading1.copyWith(fontSize: 22),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'View and manage all users on the platform',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.lg),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final users = snapshot.data!.docs;

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: data['userType'] == 'admin'
                            ? AppColors.primary
                            : data['userType'] == 'llg'
                                ? AppColors.secondary
                                : AppColors.success,
                        child: Text(
                          data['name']?[0]?.toUpperCase() ?? '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Text(data['email'] ?? 'No email'),
                      trailing: Chip(
                        label: Text(data['userType'] ?? 'unknown'),
                        backgroundColor: data['userType'] == 'admin'
                            ? AppColors.primary.withOpacity(0.2)
                            : data['userType'] == 'llg'
                                ? AppColors.secondary.withOpacity(0.2)
                                : AppColors.success.withOpacity(0.2),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}