import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'parent_theme.dart';
import 'activity_view.dart';

class NotificationsPage extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const NotificationsPage({super.key, this.auth, this.firestore});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  FirebaseAuth? get _auth {
    if (widget.auth != null) return widget.auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    if (widget.firestore != null) return widget.firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  bool _isMarkingAllAsRead = false;

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'Recently';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final firestore = _firestore;
    if (_isMarkingAllAsRead || docs.isEmpty || firestore == null) return;
    setState(() => _isMarkingAllAsRead = true);

    try {
      final batch = firestore.batch();
      int unreadCount = 0;
      for (final doc in docs) {
        if (doc.data()['isRead'] != true) {
          batch.update(doc.reference, {'isRead': true});
          unreadCount++;
        }
      }

      if (unreadCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: ParentColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ParentColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAllAsRead = false);
    }
  }

  Future<bool?> _confirmDismiss(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text('Delete Notification', style: ParentTypography.cardTitle),
        content: Text(
          'Are you sure you want to dismiss this notification?',
          style: ParentTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final activityId = data['activityId'] as String?;
    final actionRoute = data['actionRoute'] as String?;
    final childId = data['childId'] as String?;

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

    if (actionRoute != null && actionRoute.isNotEmpty) {
      if (actionRoute == '/home' || actionRoute == '/activities' || actionRoute == '/profile') {
        Navigator.pop(context);
        return;
      }
      Navigator.pushNamed(context, actionRoute);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: ParentColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🔔', style: TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: ParentTypography.title,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll notify you when new activities, milestone celebrations, or specialist notes are ready.',
              textAlign: TextAlign.center,
              style: ParentTypography.bodyLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = data['title'] as String? ?? 'Notification';
    final message = data['message'] as String? ?? '';
    final iconText = data['icon'] as String? ?? '🎉';
    final isRead = data['isRead'] as bool? ?? false;
    final activityId = data['activityId'] as String?;
    final actionRoute = data['actionRoute'] as String?;
    final hasAction = (activityId != null && activityId.isNotEmpty) ||
        (actionRoute != null && actionRoute.isNotEmpty);

    DateTime? createdAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (dir) => _confirmDismiss(context, title),
      onDismissed: (_) {
        doc.reference.delete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: ParentColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFBF8FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? ParentColors.surfaceAlt : ParentColors.primaryLight.withOpacity(0.3),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (!isRead) {
                doc.reference.update({'isRead': true});
              }
              _handleNotificationTap(data);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isRead
                          ? ParentColors.surfaceAlt
                          : ParentColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(iconText, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 14),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: ParentTypography.body.copyWith(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                  color: ParentColors.textPrimary,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6, top: 4),
                                decoration: const BoxDecoration(
                                  color: ParentColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: ParentTypography.caption.copyWith(
                              color: ParentColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimestamp(createdAt),
                              style: ParentTypography.caption.copyWith(
                                color: ParentColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                            if (hasAction)
                              ElevatedButton(
                                onPressed: () {
                                  if (!isRead) {
                                    doc.reference.update({'isRead': true});
                                  }
                                  _handleNotificationTap(data);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ParentColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: ParentRadius.chip,
                                  ),
                                ),
                                child: const Text(
                                  'View',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth?.currentUser?.uid ?? '';
    final firestore = _firestore;

    if (currentUserId.isEmpty || firestore == null) {
      return Scaffold(
        backgroundColor: ParentColors.surfaceAlt,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ParentColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Notifications',
            style: ParentTypography.title.copyWith(fontSize: 19),
          ),
        ),
        body: _buildEmptyState(),
      );
    }

    return Scaffold(
      backgroundColor: ParentColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ParentColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: ParentTypography.title.copyWith(fontSize: 19),
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore
                .collection('notifications')
                .where('userId', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final hasUnread = docs.any((d) => d.data()['isRead'] != true);

              if (!hasUnread) return const SizedBox.shrink();

              return TextButton(
                onPressed: _isMarkingAllAsRead ? null : () => _markAllAsRead(docs),
                child: Text(
                  _isMarkingAllAsRead ? 'Marking...' : 'Mark all as read',
                  style: ParentTypography.caption.copyWith(
                    color: ParentColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading notifications: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Sort docs descending by createdAt in memory
                final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
                  ..sort((a, b) {
                    DateTime? timeA;
                    DateTime? timeB;
                    final rawA = a.data()['createdAt'];
                    final rawB = b.data()['createdAt'];
                    if (rawA is Timestamp) timeA = rawA.toDate();
                    if (rawB is Timestamp) timeB = rawB.toDate();
                    if (timeA == null && timeB == null) return 0;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    return timeB.compareTo(timeA);
                  });

                // Group by Today, This Week, Earlier
                final now = DateTime.now();
                final todayDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final thisWeekDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final earlierDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                for (final doc in sortedDocs) {
                  final rawDate = doc.data()['createdAt'];
                  DateTime date = now;
                  if (rawDate is Timestamp) {
                    date = rawDate.toDate();
                  }

                  final diff = now.difference(date);
                  final isToday = now.year == date.year && now.month == date.month && now.day == date.day;

                  if (isToday) {
                    todayDocs.add(doc);
                  } else if (diff.inDays < 7) {
                    thisWeekDocs.add(doc);
                  } else {
                    earlierDocs.add(doc);
                  }
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    if (todayDocs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                        child: Text(
                          'Today',
                          style: ParentTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ParentColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...todayDocs.map(_buildNotificationCard),
                    ],
                    if (thisWeekDocs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
                        child: Text(
                          'This Week',
                          style: ParentTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ParentColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...thisWeekDocs.map(_buildNotificationCard),
                    ],
                    if (earlierDocs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
                        child: Text(
                          'Earlier',
                          style: ParentTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ParentColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...earlierDocs.map(_buildNotificationCard),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
