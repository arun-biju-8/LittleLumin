// lib/screens/admin/user_directory_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class UserDirectoryPage extends StatelessWidget {
  const UserDirectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Directory',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Directory of all platform users (Parents, LLG Guides, Admins).',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No users found in directory.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final userType = data['userType'] ?? 'parent';

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: userType == 'admin'
                              ? Colors.purple
                              : (userType == 'llg' ? AppColors.primary : Colors.teal),
                          child: Icon(
                            userType == 'admin'
                                ? Icons.admin_panel_settings
                                : (userType == 'llg' ? Icons.badge : Icons.person),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(data['name'] ?? 'User'),
                        subtitle: Text(data['email'] ?? ''),
                        trailing: Chip(
                          label: Text(
                            userType.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
