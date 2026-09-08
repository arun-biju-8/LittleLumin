// lib/screens/admin/admin_llg_verification_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/llg_service.dart';
import '../../utils/constants.dart';
import '../../theme/app_theme.dart';

class AdminLLGVerificationPage extends StatefulWidget {
  const AdminLLGVerificationPage({super.key});

  @override
  State<AdminLLGVerificationPage> createState() => _AdminLLGVerificationPageState();
}

class _AdminLLGVerificationPageState extends State<AdminLLGVerificationPage> {
  final LLGService _llgService = LLGService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatusTab = 'pending'; // 'pending', 'approved', 'rejected', 'all'
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // URL Launcher Helper with Error SnackBar
  Future<void> _launchUrl(String url) async {
    if (url.trim().isEmpty) return;
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final Uri uri = Uri.parse(formattedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open link. Please copy and paste manually.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please copy and paste manually.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Confirm Approve Dialog
  void _confirmApprove(String uid, [BuildContext? parentContext]) {
    final ctx = parentContext ?? context;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Approve LLG Guide?'),
          ],
        ),
        content: const Text(
          'This applicant will receive a Verified LLG Guide badge and gain full access to guide parents on the LittleLumin platform.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final error = await _llgService.approveLLG(uid);
              if (mounted) {
                if (error == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('✅ LLG approved successfully! Account is now verified.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error approving applicant: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Approval', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Show Reject Dialog
  void _showRejectDialog(String uid, [BuildContext? parentContext]) {
    final ctx = parentContext ?? context;
    final reasonController = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Reject Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please state the official reason for rejection:'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Invalid license link, missing identity proof...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              final error = await _llgService.rejectLLG(uid, reason: reason);
              if (mounted) {
                if (error == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('❌ LLG application rejected.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Rejection', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Open Full Dossier Inspection Modal (Web-Optimized)
  void _openCandidateModal(Map<String, dynamic> llg) {
    showDialog(
      context: context,
      builder: (modalCtx) {
        final isDesktop = MediaQuery.of(modalCtx).size.width >= 900;
        final status = llg['verificationStatus'] ?? 'pending';

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 80 : 16,
            vertical: isDesktop ? 40 : 20,
          ),
          child: Container(
            width: isDesktop ? 960 : double.infinity,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(modalCtx).size.height * 0.9),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _getStatusColor(status).withValues(alpha: 0.15),
                      child: Icon(
                        status == 'approved'
                            ? Icons.verified_rounded
                            : (status == 'rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
                        color: _getStatusColor(status),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                llg['name'] ?? 'Unknown LLG',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${llg['qualification'] ?? 'N/A'} • ${llg['email'] ?? 'No Email'} • Phone: ${llg['phone'] ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 28),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Scrollable Body Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Professional Credentials Section
                        _buildSectionTitle('1. Professional Credentials'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            _buildDetailCard('Qualification', llg['qualification'], Icons.school_outlined),
                            _buildDetailCard('License / Cert No.', llg['license'], Icons.badge_outlined),
                            _buildDetailCard('Experience', llg['experience'], Icons.history_edu_outlined),
                            _buildDetailCard('Specialization', llg['specialization'], Icons.psychology_outlined),
                            _buildDetailCard('Organization', llg['organization'], Icons.business_outlined),
                            _buildDetailCard('Region / City', llg['region'], Icons.map_outlined),
                            _buildDetailCard('Languages Spoken', llg['languages'], Icons.translate_outlined),
                            _buildDetailCard('Consultation Mode', llg['consultationMode'], Icons.video_call_outlined),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Bio & Philosophy
                        if (llg['bio'] != null && llg['bio'].toString().isNotEmpty) ...[
                          _buildSectionTitle('2. Professional Bio & Statement'),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.slateBg.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              llg['bio'],
                              style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Verification Document Cards (Attention Seeking!)
                        _buildSectionTitle('3. 📎 Verification Documents (Click to Inspect)'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 16,
                          runSpacing: 14,
                          children: [
                            _buildWebDocumentCard(
                              title: '🎓 Qualification Certificate',
                              link: llg['qualificationCertificateLink'],
                              color: Colors.blue,
                            ),
                            _buildWebDocumentCard(
                              title: '📜 License Certificate',
                              link: llg['licenseCertificateLink'],
                              color: Colors.amber[800]!,
                            ),
                            _buildWebDocumentCard(
                              title: '💼 Experience Certificate',
                              link: llg['experienceCertificateLink'],
                              color: Colors.purple,
                            ),
                            _buildWebDocumentCard(
                              title: '🪪 Identity Proof',
                              link: llg['identityProofLink'],
                              color: Colors.green,
                            ),
                            if (llg['professionalAssociationLink'] != null && llg['professionalAssociationLink'].toString().isNotEmpty)
                              _buildWebDocumentCard(
                                title: '🤝 Professional Association',
                                link: llg['professionalAssociationLink'],
                                color: Colors.teal,
                              ),
                          ],
                        ),

                        if (status == 'rejected' && llg['rejectionReason'] != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Rejection Reason: ${llg['rejectionReason']}',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Modal Sticky Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(modalCtx),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalCtx);
                        _showRejectDialog(llg['uid']);
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                      label: const Text('Reject Application', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalCtx);
                        _confirmApprove(llg['uid']);
                      },
                      icon: const Icon(Icons.verified_rounded, size: 20),
                      label: const Text('Approve & Verify Guide', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isDesktop ? AppSpacing.lg : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LLG Applications & Verification Portal',
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: isDesktop ? 22 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Review, inspect certificate documents, and approve or reject guide candidates.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Streamed Statistics Summary Cards (Attention Seeking Web Banner)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _llgService.getAllLLGProfilesStream(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final pendingCount = docs.where((d) => (d.data()['verificationStatus'] ?? 'pending') == 'pending').length;
              final approvedCount = docs.where((d) => (d.data()['verificationStatus'] ?? '') == 'approved').length;
              final rejectedCount = docs.where((d) => (d.data()['verificationStatus'] ?? '') == 'rejected').length;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isDesktop ? 3.4 : 2.0,
                children: [
                  _buildSummaryCard(
                    title: 'PENDING VERIFICATION',
                    count: '$pendingCount',
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.amber[800]!,
                    active: _selectedStatusTab == 'pending',
                    onTap: () => setState(() => _selectedStatusTab = 'pending'),
                  ),
                  _buildSummaryCard(
                    title: 'VERIFIED GUIDES',
                    count: '$approvedCount',
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                    active: _selectedStatusTab == 'approved',
                    onTap: () => setState(() => _selectedStatusTab = 'approved'),
                  ),
                  _buildSummaryCard(
                    title: 'REJECTED',
                    count: '$rejectedCount',
                    icon: Icons.cancel_rounded,
                    color: Colors.redAccent,
                    active: _selectedStatusTab == 'rejected',
                    onTap: () => setState(() => _selectedStatusTab = 'rejected'),
                  ),
                  _buildSummaryCard(
                    title: 'TOTAL APPLICANTS',
                    count: '${docs.length}',
                    icon: Icons.folder_shared_rounded,
                    color: AppColors.primary,
                    active: _selectedStatusTab == 'all',
                    onTap: () => setState(() => _selectedStatusTab = 'all'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Controls Row: Search & Status Dropdown
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by candidate name, email, qualification, city...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatusTab,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('⏳ Pending Verification')),
                      DropdownMenuItem(value: 'approved', child: Text('✅ Approved LLGs')),
                      DropdownMenuItem(value: 'rejected', child: Text('❌ Rejected')),
                      DropdownMenuItem(value: 'all', child: Text('📋 All Applications')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatusTab = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // StreamBuilder for Applications List / Grid
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _llgService.getAllLLGProfilesStream(
              statusFilter: _selectedStatusTab == 'all' ? null : _selectedStatusTab,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading applications: ${snapshot.error}'),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              final filteredDocs = docs.where((doc) {
                final data = doc.data();
                if (_searchQuery.isEmpty) return true;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final qualification = (data['qualification'] ?? '').toString().toLowerCase();
                final organization = (data['organization'] ?? '').toString().toLowerCase();
                final region = (data['region'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    email.contains(_searchQuery) ||
                    qualification.contains(_searchQuery) ||
                    organization.contains(_searchQuery) ||
                    region.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatusTab == 'pending'
                              ? 'No pending LLG applications to verify.'
                              : 'No matching applications found.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // On Web: Render Compact Grid of Candidates; On Mobile: Render List
              if (isDesktop) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 215,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final llgData = filteredDocs[index].data();
                    llgData['uid'] = llgData['uid'] ?? filteredDocs[index].id;
                    return _buildWebCandidateCard(llgData);
                  },
                );
              } else {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final llgData = filteredDocs[index].data();
                    llgData['uid'] = llgData['uid'] ?? filteredDocs[index].id;
                    return _buildLLGVerificationTile(llgData);
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Web High-Visibility Compact Card Dossier
  Widget _buildWebCandidateCard(Map<String, dynamic> llg) {
    final status = llg['verificationStatus'] ?? 'pending';
    final color = _getStatusColor(status);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1.2),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Card Top Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    status == 'approved'
                        ? Icons.verified_rounded
                        : (status == 'rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        llg['name'] ?? 'Unknown LLG',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        llg['email'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const Divider(height: 10),

            // Key Info Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('🎓 ${llg['qualification'] ?? 'N/A'}'),
                  const SizedBox(width: 6),
                  _buildChip('📜 Lic: ${llg['license'] ?? 'N/A'}'),
                  const SizedBox(width: 6),
                  _buildChip('💼 ${llg['experience'] ?? 'N/A'} Exp'),
                  const SizedBox(width: 6),
                  _buildChip('📍 ${llg['region'] ?? 'N/A'}'),
                ],
              ),
            ),

            // Document Count Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Verification Proofs: ${_countDocuments(llg)} Certificates Provided',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openCandidateModal(llg),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Inspect Dossier', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Approve Guide',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.success.withValues(alpha: 0.15),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  onPressed: () => _confirmApprove(llg['uid']),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Reject Application',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                  ),
                  icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                  onPressed: () => _showRejectDialog(llg['uid']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Mobile / Tile Layout
  Widget _buildLLGVerificationTile(Map<String, dynamic> llg) {
    final status = llg['verificationStatus'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            status == 'approved'
                ? Icons.verified_rounded
                : (status == 'rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
            color: statusColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                llg['name'] ?? 'Unknown LLG',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(status),
          ],
        ),
        subtitle: Text(
          '${llg['qualification'] ?? 'N/A'} • ${llg['email'] ?? 'No email'}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Personal Details'),
                _buildDetailRow('Name', llg['name']),
                _buildDetailRow('Email', llg['email']),
                _buildDetailRow('Phone', llg['phone']),

                const Divider(height: 24),

                _buildSectionTitle('Professional Details'),
                _buildDetailRow('Qualification', llg['qualification']),
                _buildDetailRow('License', llg['license']),
                _buildDetailRow('Experience', llg['experience']),
                _buildDetailRow('Specialization', llg['specialization']),
                _buildDetailRow('Organization', llg['organization']),
                _buildDetailRow('Bio', llg['bio'], maxLines: 3),
                _buildDetailRow('Region', llg['region']),
                _buildDetailRow('Languages', llg['languages']),
                _buildDetailRow('Consultation Mode', llg['consultationMode']),

                const Divider(height: 24),

                _buildSectionTitle('📎 Verification Documents'),
                _buildLinkTile('🎓 Qualification Certificate', llg['qualificationCertificateLink']),
                _buildLinkTile('📜 License Certificate', llg['licenseCertificateLink']),
                _buildLinkTile('💼 Experience Certificate', llg['experienceCertificateLink']),
                _buildLinkTile('🪪 Identity Proof', llg['identityProofLink']),
                if (llg['professionalAssociationLink'] != null && llg['professionalAssociationLink'].toString().isNotEmpty)
                  _buildLinkTile('🤝 Professional Association', llg['professionalAssociationLink']),

                if (status == 'rejected' && llg['rejectionReason'] != null && llg['rejectionReason'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Rejection Reason: ${llg['rejectionReason']}',
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmApprove(llg['uid']),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve & Verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(llg['uid']),
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Attention-Seeking Web Document Badge Card
  Widget _buildWebDocumentCard({
    required String title,
    required String? link,
    required Color color,
  }) {
    final hasLink = link != null && link.trim().isNotEmpty;

    return Container(
      width: 270,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasLink ? color.withValues(alpha: 0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasLink ? color.withValues(alpha: 0.3) : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hasLink ? Icons.verified_rounded : Icons.link_off_rounded, color: hasLink ? color : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: hasLink ? AppColors.textDark : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasLink)
            ElevatedButton.icon(
              onPressed: () => _launchUrl(link!),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Inspect Link ↗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            Text(
              'Not Provided',
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  // Summary Metrics Header Card
  Widget _buildSummaryCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.grey[200]!,
            width: active ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: active ? color : AppColors.textDark,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  Widget _buildDetailCard(String label, String? value, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (value != null && value.isNotEmpty) ? value : 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    String text = 'PENDING VERIFICATION';
    if (status == 'approved') text = 'VERIFIED LLG';
    if (status == 'rejected') text = 'REJECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {int maxLines = 1}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(String title, String? link) {
    if (link == null || link.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.link, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _launchUrl(link),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
            onPressed: () => _launchUrl(link),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  int _countDocuments(Map<String, dynamic> llg) {
    int count = 0;
    if (llg['qualificationCertificateLink']?.toString().isNotEmpty ?? false) count++;
    if (llg['licenseCertificateLink']?.toString().isNotEmpty ?? false) count++;
    if (llg['experienceCertificateLink']?.toString().isNotEmpty ?? false) count++;
    if (llg['identityProofLink']?.toString().isNotEmpty ?? false) count++;
    if (llg['professionalAssociationLink']?.toString().isNotEmpty ?? false) count++;
    return count;
  }

  Color _getStatusColor(String status) {
    if (status == 'approved') return AppColors.success;
    if (status == 'rejected') return Colors.red;
    return Colors.amber[800]!;
  }
}
