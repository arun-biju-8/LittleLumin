// lib/services/notification_router.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/parent/activity_view.dart';
import '../screens/parent/llg_connect_page.dart';
import '../screens/llg/suspended_account_screen.dart';

class NotificationDestination {
  final String routeName;
  final int? targetTab;
  final Map<String, dynamic>? arguments;

  const NotificationDestination({
    required this.routeName,
    this.targetTab,
    this.arguments,
  });
}

class NotificationRouter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Pure resolver for testing and routing decision inspection
  static NotificationDestination? resolveDestination(
    Map<String, dynamic> data, {
    String? currentUserRole,
  }) {
    if (data.isEmpty) return null;

    final type = data['type'] as String? ?? '';
    final actionRoute = data['actionRoute'] as String?;
    final reportId = data['reportId'] as String?;
    final complaintId = data['complaintId'] as String?;
    final appealId = data['appealId'] as String?;
    final activityId = data['activityId'] as String?;
    final caseId = data['caseId'] as String?;
    final assignmentId = data['assignmentId'] as String?;
    final targetRole = data['targetRole'] as String? ?? currentUserRole;

    if (activityId != null && activityId.isNotEmpty) {
      return NotificationDestination(
        routeName: '/activity-view',
        arguments: {'activityId': activityId, 'childId': data['childId']},
      );
    }

    if (type == 'specialist_report' ||
        type == 'specialist_report_shared' ||
        (reportId != null && reportId.isNotEmpty)) {
      return NotificationDestination(
        routeName: '/llg-connect',
        targetTab: 1,
        arguments: {'reportId': reportId},
      );
    }

    if (type == 'account_suspended' ||
        type == 'account_suspension' ||
        type == 'suspension_notice') {
      return const NotificationDestination(routeName: '/suspended-account');
    }

    if (type == 'user_warning_issued' ||
        type == 'warning_notice' ||
        type == 'account_warning') {
      return const NotificationDestination(routeName: '/llg-dashboard', targetTab: 0);
    }

    if (type == 'new_parent_complaint' ||
        type == 'complaint_status_update' ||
        type == 'parent_complaint' ||
        (complaintId != null && complaintId.isNotEmpty)) {
      if (targetRole == 'admin' || actionRoute == '/admin-complaints') {
        return const NotificationDestination(routeName: '/admin-dashboard', targetTab: 5);
      }
      return const NotificationDestination(routeName: '/llg-connect', targetTab: 2);
    }

    if (type == 'new_llg_appeal' ||
        type == 'appeal_decision' ||
        (appealId != null && appealId.isNotEmpty)) {
      if (targetRole == 'admin' || actionRoute == '/admin-appeals') {
        return const NotificationDestination(routeName: '/admin-dashboard', targetTab: 6);
      }
      return const NotificationDestination(routeName: '/suspended-account');
    }

    if (type == 'chat' || type == 'message') {
      return NotificationDestination(
        routeName: '/consultation-chat',
        arguments: {'caseId': caseId},
      );
    }

    if (type == 'new_assignment' ||
        type == 'assignment' ||
        (assignmentId != null && assignmentId.isNotEmpty)) {
      return const NotificationDestination(routeName: '/llg-dashboard');
    }

    if (type == 'case_update' ||
        type == 'new_case_request' ||
        (caseId != null && caseId.isNotEmpty)) {
      if (currentUserRole == 'specialist' || currentUserRole == 'learning_guide') {
        return const NotificationDestination(routeName: '/llg-dashboard');
      }
      return const NotificationDestination(routeName: '/llg-connect', targetTab: 0);
    }

    if (actionRoute != null && actionRoute.isNotEmpty) {
      return NotificationDestination(routeName: actionRoute);
    }

    return null;
  }

  /// Mark notification as read in Firestore
  static Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning marking notification as read: $e');
    }
  }

  /// Centralized handler for routing when a notification is tapped
  static Future<void> handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> data, {
    String? notificationId,
    String? currentUserRole,
  }) async {
    if (notificationId != null && notificationId.isNotEmpty) {
      await markAsRead(notificationId);
    }

    final type = data['type'] as String? ?? '';
    final actionRoute = data['actionRoute'] as String?;
    final reportId = data['reportId'] as String?;
    final complaintId = data['complaintId'] as String?;
    final appealId = data['appealId'] as String?;
    final activityId = data['activityId'] as String?;
    final childId = data['childId'] as String?;
    final caseId = data['caseId'] as String?;

    // 1. Activity Notification
    if (activityId != null && activityId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityView(
            activityId: activityId,
            childId: childId,
          ),
        ),
      );
      return;
    }

    // 2. Specialist Report Shared
    if (type == 'specialist_report_shared' || (reportId != null && reportId.isNotEmpty)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LLGConnectPage(initialTabIndex: 1), // Reports tab
        ),
      );
      return;
    }

    // 3. Account Suspension Notice
    if (type == 'account_suspended' || type == 'account_suspension' || type == 'suspension_notice') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SuspendedAccountScreen(),
        ),
      );
      return;
    }

    // 4. Warning Notice
    if (type == 'user_warning_issued' || type == 'warning_notice') {
      _showWarningNoticeDialog(context, data);
      return;
    }

    // 5. Parent Complaint Updates / Admin Complaint Alerts
    if (type == 'new_parent_complaint' || type == 'complaint_status_update' || (complaintId != null && complaintId.isNotEmpty)) {
      if (currentUserRole == 'admin' || actionRoute == '/admin-complaints') {
        Navigator.pushNamed(context, '/admin');
      } else {
        // Parent view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LLGConnectPage(initialTabIndex: 2), // Complaints / consultations tab
          ),
        );
      }
      return;
    }

    // 6. Suspension Appeal Updates / Admin Appeal Alerts
    if (type == 'new_llg_appeal' || type == 'appeal_decision' || (appealId != null && appealId.isNotEmpty)) {
      if (currentUserRole == 'admin' || actionRoute == '/admin-appeals') {
        Navigator.pushNamed(context, '/admin');
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SuspendedAccountScreen(),
          ),
        );
      }
      return;
    }

    // 7. Case consultation / Chat
    if (type == 'case_update' || type == 'new_case_request' || (caseId != null && caseId.isNotEmpty)) {
      if (currentUserRole == 'specialist' || currentUserRole == 'learning_guide') {
        Navigator.pushNamed(context, '/llg-dashboard');
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LLGConnectPage(initialTabIndex: 0),
          ),
        );
      }
      return;
    }

    // 8. General Action Route fallback
    if (actionRoute != null && actionRoute.isNotEmpty) {
      if (actionRoute == '/home' || actionRoute == '/activities' || actionRoute == '/profile') {
        Navigator.pop(context);
        return;
      }
      try {
        Navigator.pushNamed(context, actionRoute);
      } catch (e) {
        debugPrint('Warning routing to actionRoute "$actionRoute": $e');
      }
    }
  }

  /// Displays warning detail modal with acknowledgement action
  static void _showWarningNoticeDialog(BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Administrative Warning';
    final body = data['body'] as String? ?? 'You have received an administrative warning regarding platform policy.';
    final category = data['category'] as String? ?? 'Policy Compliance';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Category: $category',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              body,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            const Text(
              'Please acknowledge this notice and ensure strict compliance with LittleLumin platform safety guidelines.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('I Acknowledge'),
          ),
        ],
      ),
    );
  }
}
