// lib/screens/admin/flagged_children_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class FlaggedChildrenPage extends StatelessWidget {
  const FlaggedChildrenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🚩 Flagged Children',
          style: AppTextStyles.heading1.copyWith(fontSize: 22),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Children who need professional review',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.lg),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('children')
                .where('isFlagged', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final children = snapshot.data!.docs;

              if (children.isEmpty) {
                return Center(
                  child: Text(
                    'No flagged children at the moment. 🎉',
                    style: AppTextStyles.bodyLight,
                  ),
                );
              }

              return ListView.builder(
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.warning,
                        child: Text(
                          child['name'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(child['name'] ?? 'Unknown'),
                      subtitle: Text(child['flagReason'] ?? 'No reason provided'),
                      trailing: Chip(
                        label: Text('${child['age']}y'),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
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