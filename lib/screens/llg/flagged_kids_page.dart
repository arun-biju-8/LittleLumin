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
            .collection('flagState')
            .where('hasApprovedFlag', isEqualTo: true)
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
                  const Text('No pending review cases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('All parent-consented cases are reviewed!', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final flagged = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: flagged.length,
            itemBuilder: (context, index) {
              final doc = flagged[index];
              final data = doc.data() as Map<String, dynamic>;
              final childId = doc.id;
              final domains = (data['domains'] as Map<String, dynamic>?) ?? {};
              final approvedDomains = domains.entries
                  .where((e) => e.value is Map && e.value['parentResponse'] == 'approved')
                  .map((e) => e.key)
                  .toList();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('children').doc(childId).get(),
                builder: (context, childSnap) {
                  final cData = childSnap.data?.data() as Map<String, dynamic>?;
                  final childName = cData?['name'] ?? 'Child ($childId)';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Icon(Icons.support_agent, color: Colors.purple.shade700),
                      ),
                      title: Text(childName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Parent Approved: ${approvedDomains.join(', ')}'),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: approvedDomains.map((d) => Chip(
                              label: Text(d),
                              backgroundColor: Colors.amber.shade100,
                              labelStyle: const TextStyle(fontSize: 11),
                            )).toList(),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {},
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
