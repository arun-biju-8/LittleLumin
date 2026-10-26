// lib/screens/admin/views/admin_analytics_reports_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import '../../../models/admin_models.dart';
import '../../../services/admin_service.dart';
import '../../../services/admin_report_service.dart';

class AdminAnalyticsReportsView extends StatefulWidget {
  final AdminService adminService;
  final int initialSubIndex;
  final Function(int targetGroupIndex, int targetSubIndex)? onNavigate;

  const AdminAnalyticsReportsView({
    super.key,
    required this.adminService,
    this.initialSubIndex = 0,
    this.onNavigate,
  });

  @override
  State<AdminAnalyticsReportsView> createState() => _AdminAnalyticsReportsViewState();
}

class _AdminAnalyticsReportsViewState extends State<AdminAnalyticsReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminReportService _reportService = AdminReportService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reports state
  AdminReportCategory _selectedCategory = AdminReportCategory.platformSummary;
  String _selectedDateRangePreset = 'last_30_days'; // 'last_7_days', 'last_30_days', 'last_90_days', 'all_time'
  AdminReportResult? _currentReport;
  bool _isGeneratingReport = false;

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
    if (widget.initialSubIndex >= 0 && widget.initialSubIndex <= 1) {
      initialTab = widget.initialSubIndex;
    }
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Auto-generate initial preview report
    _generateReport();
  }

  @override
  void didUpdateWidget(AdminAnalyticsReportsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubIndex != oldWidget.initialSubIndex &&
        widget.initialSubIndex >= 0 &&
        widget.initialSubIndex <= 1) {
      _tabController.animateTo(widget.initialSubIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime? get _startDate {
    final now = DateTime.now();
    switch (_selectedDateRangePreset) {
      case 'last_7_days':
        return now.subtract(const Duration(days: 7));
      case 'last_30_days':
        return now.subtract(const Duration(days: 30));
      case 'last_90_days':
        return now.subtract(const Duration(days: 90));
      case 'all_time':
      default:
        return null;
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGeneratingReport = true);
    try {
      final res = await _reportService.generateReport(
        category: _selectedCategory,
        startDate: _startDate,
        endDate: DateTime.now(),
      );
      if (mounted) {
        setState(() => _currentReport = res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlatformAnalyticsTab(),
              _buildReportsAndExportsTab(),
            ],
          ),
        ),
      ],
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
          Tab(text: 'Platform & Parent Engagement Analytics'),
          Tab(text: 'Operational Reports & Data Exports'),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. PLATFORM ANALYTICS TAB
  // =========================================================================
  Widget _buildPlatformAnalyticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, userSnap) {
        final users = userSnap.data?.docs ?? [];
        final totalUsers = users.length;
        final parentsCount = users.where((u) => u.data() is Map && (u.data() as Map)['userType'] == 'parent').length;
        final llgsCount = users.where((u) => u.data() is Map && ((u.data() as Map)['userType'] == 'llg' || (u.data() as Map)['userType'] == 'specialist')).length;
        final adminsCount = users.where((u) => u.data() is Map && (u.data() as Map)['userType'] == 'admin').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Engagement & Growth Trends', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Real-time developmental activity engagement, caseload allocation, and user distribution metrics.', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
              const SizedBox(height: 20),

              // KPI Row
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Registered Users', '$totalUsers', Icons.people_outline, colorTeal)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard('Active Parents', '$parentsCount', Icons.family_restroom, colorGreen)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard('Verified LLG Specialists', '$llgsCount', Icons.verified_user_outlined, const Color(0xFF8B5CF6))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard('System Administrators', '$adminsCount', Icons.admin_panel_settings_outlined, colorAmber)),
                ],
              ),
              const SizedBox(height: 24),

              // Charts Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pie Chart: User Distribution
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 320,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorSlate,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User Distribution by Role', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: totalUsers > 0
                                ? PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                      sections: [
                                        PieChartSectionData(
                                          value: parentsCount.toDouble(),
                                          title: '$parentsCount',
                                          color: colorTeal,
                                          radius: 50,
                                          titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        PieChartSectionData(
                                          value: llgsCount.toDouble(),
                                          title: '$llgsCount',
                                          color: const Color(0xFF8B5CF6),
                                          radius: 50,
                                          titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        PieChartSectionData(
                                          value: adminsCount.toDouble(),
                                          title: '$adminsCount',
                                          color: colorAmber,
                                          radius: 50,
                                          titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  )
                                : const Center(child: Text('No user data', style: TextStyle(color: Colors.white))),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegendItem('Parents', colorTeal),
                              const SizedBox(width: 16),
                              _buildLegendItem('Specialists', const Color(0xFF8B5CF6)),
                              const SizedBox(width: 16),
                              _buildLegendItem('Admins', colorAmber),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Bar Chart: Developmental Skill Domain Distribution
                  Expanded(
                    flex: 6,
                    child: Container(
                      height: 320,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorSlate,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activity Distribution Across Developmental Domains', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 25,
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, meta) {
                                        final titles = ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'];
                                        final idx = val.toInt();
                                        if (idx >= 0 && idx < titles.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(titles[idx], style: GoogleFonts.inter(color: colorTextMuted, fontSize: 10)),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      getTitlesWidget: (val, meta) => Text('${val.toInt()}', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 10)),
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (val) => FlLine(color: colorBorder, strokeWidth: 1),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: [
                                  _buildBarGroup(0, 16, colorTeal),
                                  _buildBarGroup(1, 16, colorGreen),
                                  _buildBarGroup(2, 16, colorAmber),
                                  _buildBarGroup(3, 16, const Color(0xFF8B5CF6)),
                                  _buildBarGroup(4, 16, Colors.pinkAccent),
                                  _buildBarGroup(5, 16, Colors.deepOrangeAccent),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
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
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. REPORTS & EXPORTS TAB
  // =========================================================================
  Widget _buildReportsAndExportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Configuration Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorSlate,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generate Administrative Report', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Category Dropdown
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Report Category', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<AdminReportCategory>(
                                isExpanded: true,
                                value: _selectedCategory,
                                dropdownColor: colorNavy,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                items: AdminReportCategory.values.map((c) {
                                  return DropdownMenuItem(value: c, child: Text(c.displayName));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Date Range Preset
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date Range Preset', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedDateRangePreset,
                                dropdownColor: colorNavy,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                items: const [
                                  DropdownMenuItem(value: 'last_7_days', child: Text('Last 7 Days')),
                                  DropdownMenuItem(value: 'last_30_days', child: Text('Last 30 Days')),
                                  DropdownMenuItem(value: 'last_90_days', child: Text('Last 90 Days')),
                                  DropdownMenuItem(value: 'all_time', child: Text('All Time History')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedDateRangePreset = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            icon: _isGeneratingReport
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 16),
                            label: const Text('Update Preview'),
                            style: ElevatedButton.styleFrom(backgroundColor: colorTeal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                            onPressed: _isGeneratingReport ? null : _generateReport,
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.table_view_outlined, color: colorGreen, size: 16),
                            label: Text('Export CSV', style: GoogleFonts.inter(color: colorGreen, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: colorGreen),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            onPressed: _currentReport != null
                                ? () {
                                    final _ = _currentReport!.toCsv();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Generated ${_currentReport!.recordsCount} row CSV export.'), backgroundColor: colorGreen),
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
                            label: const Text('Print / Export PDF'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                            onPressed: _currentReport != null
                                ? () async {
                                    final pdfBytes = await AdminReportService.generateReportPdf(_currentReport!);
                                    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live Data Preview Table
          if (_currentReport != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentReport!.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(
                            'Generated at ${DateFormat('MMM d, y HH:mm').format(_currentReport!.generatedAt)} by ${_currentReport!.generatedBy} • ${_currentReport!.recordsCount} matching records',
                            style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: colorTeal.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: colorTeal.withOpacity(0.3))),
                        child: Text('LIVE DATA PREVIEW', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colorTeal)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(colorNavy),
                      dataRowColor: MaterialStateProperty.all(colorSlate),
                      columns: _currentReport!.headers.map((h) {
                        return DataColumn(
                          label: Text(h, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorTeal)),
                        );
                      }).toList(),
                      rows: _currentReport!.rows.map((row) {
                        return DataRow(
                          cells: row.map((cell) {
                            return DataCell(
                              Text(cell, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
