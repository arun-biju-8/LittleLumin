import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FlaggedKidsPage extends StatelessWidget {
  const FlaggedKidsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flagged Children'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('children')
            .where('isFlagged', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text('No flagged children', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('All children are on track!', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final flagged = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: flagged.length,
            itemBuilder: (context, index) {
              final data = flagged[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Icon(Icons.flag, color: Colors.red.shade700),
                  ),
                  title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Reason: ${data['flagReason'] ?? 'N/A'}'),
                      if (data['flagDomain'] != null) ...[
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(data['flagDomain']),
                          backgroundColor: Colors.amber.shade100,
                          labelStyle: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Child detail action
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
