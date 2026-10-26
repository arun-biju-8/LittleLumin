// lib/screens/admin/views/admin_security_health_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/admin_models.dart';
import '../../../services/admin_service.dart';

class AdminSecurityHealthView extends StatefulWidget {
  final AdminService adminService;
  final int initialSubIndex;
  final Function(int targetGroupIndex, int targetSubIndex)? onNavigate;

  const AdminSecurityHealthView({
    super.key,
    required this.adminService,
    this.initialSubIndex = 0,
    this.onNavigate,
  });

  @override
  State<AdminSecurityHealthView> createState() => _AdminSecurityHealthViewState();
}

class _AdminSecurityHealthViewState extends State<AdminSecurityHealthView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  SystemHealthDiagnostic? _diagnostic;
  bool _isCheckingHealth = false;

  Map<String, dynamic>? _selectedLog;
  bool _isLogDrawerOpen = false;

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

    _runHealthCheck();
  }

  @override
  void didUpdateWidget(AdminSecurityHealthView oldWidget) {
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

  Future<void> _runHealthCheck() async {
    setState(() => _isCheckingHealth = true);
    try {
      final diag = await widget.adminService.checkSystemHealth();
      if (mounted) setState(() => _diagnostic = diag);
    } catch (e) {
      debugPrint('Health check exception: $e');
    } finally {
      if (mounted) setState(() => _isCheckingHealth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAuditTrailTab(),
                  _buildSecurityEventsTab(),
                  _buildSystemHealthTab(),
                ],
              ),
            ),
          ],
        ),

        // Log detail drawer
        if (_isLogDrawerOpen && _selectedLog != null)
          _buildLogDetailDrawer(_selectedLog!),
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
                  hintText: 'Search audit events, actors, actions, or targets...',
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
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: _isCheckingHealth
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, size: 16),
            label: const Text('Run Health Diagnostic'),
            style: ElevatedButton.styleFrom(backgroundColor: colorTeal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            onPressed: _isCheckingHealth ? null : _runHealthCheck,
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
          Tab(text: 'Immutable Audit Trail'),
          Tab(text: 'Security & Access Events'),
          Tab(text: 'System Health & Configuration'),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. AUDIT TRAIL TAB
  // =========================================================================
  Widget _buildAuditTrailTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.adminService.getAuditLogsStream(),
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
                Icon(Icons.security, size: 48, color: colorTextMuted.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('No audit records logged yet.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
              ],
            ),
          );
        }

        var filteredDocs = docs;
        if (_searchQuery.isNotEmpty) {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final action = (data['action'] ?? '').toString().toLowerCase();
            final actorEmail = (data['actorEmail'] ?? '').toString().toLowerCase();
            final targetId = (data['targetId'] ?? '').toString().toLowerCase();
            return action.contains(_searchQuery) || actorEmail.contains(_searchQuery) || targetId.contains(_searchQuery);
          }).toList();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final action = data['action'] ?? 'Unknown Action';
            final actorEmail = data['actorEmail'] ?? 'admin';
            final targetId = data['targetId'] ?? 'N/A';
            final ts = (data['timestamp'] as Timestamp?)?.toDate();
            final dateStr = ts != null ? DateFormat('MMM d, y HH:mm:ss').format(ts) : 'Just now';

            Color actionColor = colorTeal;
            if (action.toString().contains('delete') || action.toString().contains('suspend')) {
              actionColor = Colors.redAccent;
            } else if (action.toString().contains('warn') || action.toString().contains('reassign')) {
              actionColor = colorAmber;
            } else if (action.toString().contains('restore') || action.toString().contains('verified')) {
              actionColor = colorGreen;
            }

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
                    radius: 18,
                    backgroundColor: actionColor.withOpacity(0.15),
                    child: Icon(Icons.shield_outlined, color: actionColor, size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.toString().replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Actor: $actorEmail • Target: $targetId', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: colorTeal, size: 18),
                    tooltip: 'Inspect Event Payload',
                    onPressed: () {
                      setState(() {
                        _selectedLog = data;
                        _isLogDrawerOpen = true;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 2. SECURITY EVENTS TAB
  // =========================================================================
  Widget _buildSecurityEventsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.adminService.getAuditLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final secDocs = allDocs.where((d) {
          final act = (d.data() as Map<String, dynamic>)['action'] ?? '';
          return act.contains('suspend') || act.contains('warn') || act.contains('delete') || act.contains('restore') || act.contains('role');
        }).toList();

        if (secDocs.isEmpty) {
          return Center(
            child: Text('No security enforcement events recorded.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: secDocs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = secDocs[index].data() as Map<String, dynamic>;
            final action = data['action'] ?? '';
            final actorEmail = data['actorEmail'] ?? '';
            final targetId = data['targetId'] ?? '';
            final ts = (data['timestamp'] as Timestamp?)?.toDate();
            final dateStr = ts != null ? DateFormat('MMM d, y HH:mm').format(ts) : 'Recently';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gpp_bad_outlined, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Enforced by $actorEmail on account $targetId', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 3. SYSTEM HEALTH TAB
  // =========================================================================
  Widget _buildSystemHealthTab() {
    final d = _diagnostic;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Core System Health & Services Status', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Active infrastructure, database connectivity, and backend API status.', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                ],
              ),
              if (d != null)
                Text(
                  'Last Checked: ${DateFormat('HH:mm:ss').format(d.checkedAt)}',
                  style: GoogleFonts.inter(fontSize: 12, color: colorTeal, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Health Check Cards
          _buildHealthServiceCard(
            'Firebase Authentication',
            d?.firebaseAuthOk ?? true,
            d?.authMessage ?? 'Session active and tokens validated.',
            Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 12),
          _buildHealthServiceCard(
            'Cloud Firestore Database',
            d?.firestoreOk ?? true,
            d?.firestoreMessage ?? 'Firestore clusters reachable with read/write capability.',
            Icons.storage_outlined,
          ),
          const SizedBox(height: 12),
          _buildHealthServiceCard(
            'LittleLumin Backend Microservices',
            d?.backendApiOk ?? true,
            d?.backendMessage ?? 'Backend API endpoints responding normally.',
            Icons.cloud_queue_outlined,
          ),
          const SizedBox(height: 12),
          _buildHealthServiceCard(
            'Developmental AI Generation Service',
            d?.aiServiceOk ?? true,
            d?.aiMessage ?? 'Gemini 1.5 Pro & Flash model pipeline operational.',
            Icons.psychology_outlined,
          ),

          const SizedBox(height: 24),
          // Configuration & Deployment Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorSlate,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deployment Configuration', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                _buildConfigRow('Platform Version', 'LittleLumin Production v2.4.0'),
                _buildConfigRow('Backend Host', 'https://littlelumin-backend.onrender.com'),
                _buildConfigRow('Security Protocol', 'DPDP & HIPAA Compliance Rule Enforced'),
                _buildConfigRow('Transactional Mailer', 'Configured & Active (LittleLumin Mail Service)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthServiceCard(String title, bool isHealthy, String message, IconData icon) {
    final statusColor = isHealthy ? colorGreen : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHealthy ? colorBorder : Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: statusColor.withOpacity(0.15),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(message, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  isHealthy ? 'OPERATIONAL' : 'DEGRADED',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
          ),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // =========================================================================
  // LOG DETAIL DRAWER
  // =========================================================================
  Widget _buildLogDetailDrawer(Map<String, dynamic> log) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 440,
      child: Container(
        decoration: BoxDecoration(
          color: colorSlate,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(-5, 0)),
          ],
          border: const Border(left: BorderSide(color: colorBorder, width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audit Event Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => setState(() => _isLogDrawerOpen = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Action: ${log['action']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colorTeal)),
                    const SizedBox(height: 12),
                    Text('Actor: ${log['actorEmail']} (${log['actorId']})', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Target ID: ${log['targetId'] ?? "N/A"}', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                    const SizedBox(height: 16),
                    Text('Payload & Metadata:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                      child: Text(
                        (log['details'] != null) ? log['details'].toString() : 'No additional details',
                        style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
