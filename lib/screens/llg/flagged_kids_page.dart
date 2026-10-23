import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/specialist_case_service.dart';
import '../../models/specialist_case_model.dart';

class FlaggedKidsPage extends StatelessWidget {
  const FlaggedKidsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final caseService = SpecialistCaseService();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Assigned Cases')),
        body: const Center(child: Text('Authentication required as a specialist.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Cases'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SpecialistCaseModel>>(
        stream: caseService.getSpecialistCasesStream(specialistId: user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data ?? [];
          final activeCases = cases.where((c) => c.canAccessChildData).toList();

          if (activeCases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: Colors.purple.shade300),
                  const SizedBox(height: 16),
                  const Text('No Active Assigned Cases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Cases appear here only when parents grant explicit DPDP consent.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeCases.length,
            itemBuilder: (context, index) {
              final c = activeCases[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Icon(Icons.support_agent, color: Colors.purple.shade700),
                  ),
                  title: Text(c.childName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Purpose: ${c.purpose} • Age: ${c.childAgeYears} yrs'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: c.authorizedDataCategories.map((category) => Chip(
                          label: Text(category),
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
      ),
    );
  }
}
