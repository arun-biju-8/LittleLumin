// lib/screens/admin/views/admin_communication_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/admin_models.dart';
import '../../../services/admin_service.dart';
import '../../../services/email_service.dart';
import '../../../services/notification_router.dart';

class AdminCommunicationView extends StatefulWidget {
  final AdminService adminService;
  final int initialSubIndex;
  final Function(int targetGroupIndex, int targetSubIndex)? onNavigate;

  const AdminCommunicationView({
    super.key,
    required this.adminService,
    this.initialSubIndex = 0,
    this.onNavigate,
  });

  @override
  State<AdminCommunicationView> createState() => _AdminCommunicationViewState();
}

class _AdminCommunicationViewState extends State<AdminCommunicationView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final EmailService _emailService;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorGreen = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _emailService = EmailService(firestore: _firestore);
    int initialTab = 0;
    if (widget.initialSubIndex >= 0 && widget.initialSubIndex <= 2) {
      initialTab = widget.initialSubIndex;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AdminCommunicationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubIndex != oldWidget.initialSubIndex &&
        widget.initialSubIndex >= 0 &&
        widget.initialSubIndex <= 2) {
      _tabController.animateTo(widget.initialSubIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsTab(),
              _buildEmailHistoryTab(),
              _buildSupportRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HEADER & TAB BAR
  // =========================================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration: const BoxDecoration(
        color: colorNavy,
        border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search communications, emails, recipients...',
                  hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: colorTextMuted, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: colorTextMuted, size: 16),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: colorNavy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: colorTeal,
        indicatorWeight: 3,
        labelColor: colorTeal,
        unselectedLabelColor: colorTextMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Administrative Notification Center'),
          Tab(text: 'Transactional Email History'),
          Tab(text: 'User Support Inquiries'),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. NOTIFICATIONS TAB
  // =========================================================================
  Widget _buildNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('notifications').orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 48, color: colorTextMuted.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('No administrative notifications.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Notification';
            final body = data['body'] ?? data['message'] ?? '';
            final isRead = data['read'] == true;
            final ts = (data['timestamp'] as Timestamp?)?.toDate();
            final tsStr = ts != null ? DateFormat('MMM d, y HH:mm').format(ts) : 'Recently';

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                try {
                  await _firestore.collection('notifications').doc(doc.id).update({'read': true, 'isRead': true});
                } catch (_) {}
                final type = data['type'] as String? ?? '';
                final actionRoute = data['actionRoute'] as String? ?? '';
                if (type == 'new_parent_complaint' || actionRoute == '/admin-complaints') {
                  widget.onNavigate?.call(2, 5);
                } else if (type == 'new_llg_appeal' || actionRoute == '/admin-appeals') {
                  widget.onNavigate?.call(2, 6);
                } else if (type == 'verification_request' || type == 'specialist_verification_request') {
                  widget.onNavigate?.call(2, 1);
                } else if (type == 'recovery_request') {
                  widget.onNavigate?.call(1, 5);
                } else {
                  NotificationRouter.handleNotificationTap(context, data, notificationId: doc.id, currentUserRole: 'admin');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorSlate,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isRead ? colorBorder : colorTeal.withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isRead ? colorBorder : colorTeal.withOpacity(0.2),
                      child: Icon(Icons.notifications_active, color: isRead ? colorTextMuted : colorTeal, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text(tsStr, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(body, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                        ],
                      ),
                    ),
                    if (!isRead)
                      IconButton(
                        icon: const Icon(Icons.done_all, color: colorTeal, size: 18),
                        tooltip: 'Mark as read',
                        onPressed: () => _firestore.collection('notifications').doc(doc.id).update({'read': true}),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 2. TRANSACTIONAL EMAIL HISTORY TAB
  // =========================================================================
  Widget _buildEmailHistoryTab() {
    return StreamBuilder<List<AdminEmailLogModel>>(
      stream: _emailService.getEmailLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        List<AdminEmailLogModel> logs = snapshot.data ?? [];

        if (_searchQuery.isNotEmpty) {
          logs = logs.where((l) {
            return l.recipientEmail.toLowerCase().contains(_searchQuery) ||
                l.recipientName.toLowerCase().contains(_searchQuery) ||
                l.subject.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 48, color: colorTextMuted.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('No transactional email logs on record.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            final dateStr = DateFormat('MMM d, y HH:mm').format(log.timestamp);

            Color statusColor = colorGreen;
            if (log.status == 'failed') statusColor = Colors.redAccent;
            if (log.status == 'queued') statusColor = colorAmber;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(
                      log.status == 'sent' ? Icons.outgoing_mail : (log.status == 'failed' ? Icons.error_outline : Icons.schedule),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.subject, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          'To: ${log.recipientName} (${log.recipientEmail}) • Category: ${log.category.toUpperCase()}',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                        if (log.providerMessageId != null)
                          Text('ID: ${log.providerMessageId}', style: GoogleFonts.inter(fontSize: 10, color: colorTeal)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(log.status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                  if (log.status == 'failed') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: colorTeal, size: 20),
                      tooltip: 'Retry Sending',
                      onPressed: () async {
                        final ok = await _emailService.retryFailedEmail(log.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Email retry sent!' : 'Retry failed.'),
                              backgroundColor: ok ? colorGreen : Colors.redAccent,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 3. SUPPORT REQUESTS TAB
  // =========================================================================
  Widget _buildSupportRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('supportRequests').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.support_agent, size: 48, color: colorGreen),
                const SizedBox(height: 12),
                Text('All support inquiries resolved!', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('No unresolved inquiries currently pending.', style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final userName = data['userName'] ?? 'User';
            final userEmail = data['userEmail'] ?? '';
            final subject = data['subject'] ?? 'Support Inquiry';
            final message = data['message'] ?? '';
            final status = data['status'] ?? 'open';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(subject, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorAmber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colorAmber.withOpacity(0.3)),
                        ),
                        child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colorAmber)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('From: $userName ($userEmail)', style: GoogleFonts.inter(fontSize: 12, color: colorTeal)),
                  const SizedBox(height: 8),
                  Text(message, style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
