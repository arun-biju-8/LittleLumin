// lib/screens/admin/llg_detail_page.dart
import 'package:flutter/material.dart';

class LLGDetailPage extends StatelessWidget {
  final String llgId;
  const LLGDetailPage({super.key, required this.llgId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LLG Details')),
      body: Center(
        child: Text('LLG Details for ID: $llgId'),
      ),
    );
  }
}
