// lib/screens/parent/parent_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/child_model.dart';
import '../../services/child_service.dart';
import '../../theme/meadow_theme.dart';
import 'add_child_page.dart';
import 'notifications_page.dart';
import 'app_shell.dart';

class ParentDashboard extends StatefulWidget {
  final int initialTab;

  const ParentDashboard({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChildService _childService = ChildService();

  String? _selectedChildId;

  void _onChildSelected(ChildModel child) {
    setState(() {
      _selectedChildId = child.childId;
    });
  }

  void _navigateToAddChild() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildPage()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final parentName = user?.displayName ?? 'Parent';

    return StreamBuilder<List<ChildModel>>(
      stream: _childService.getChildren(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: MeadowColors.cream,
            body: Center(child: CircularProgressIndicator(color: MeadowColors.primary)),
          );
        }

        final children = snapshot.data ?? [];
        ChildModel? activeChild;

        if (children.isNotEmpty) {
          activeChild = children.firstWhere(
            (c) => c.childId == _selectedChildId,
            orElse: () => children.first,
          );
        }

        return AppShell(
          initialTab: widget.initialTab,
          activeChild: activeChild,
          children: children,
          parentName: parentName,
          onChildSelected: _onChildSelected,
          onAddChild: _navigateToAddChild,
          onNotificationsTap: _navigateToNotifications,
          onRefresh: () => setState(() {}),
        );
      },
    );
  }
}