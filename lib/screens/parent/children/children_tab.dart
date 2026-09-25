// lib/screens/parent/children/children_tab.dart
import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../services/child_service.dart';
import '../../../theme/meadow_theme.dart';
import '../../../widgets/global_header.dart';
import '../add_child_page.dart';
import '../edit_child_page.dart';
import 'child_card.dart';

class ChildrenTab extends StatefulWidget {
  final List<ChildModel> children;
  final ChildModel? activeChild;
  final ValueChanged<ChildModel> onChildSelected;
  final VoidCallback onRefresh;
  final bool showBack;

  const ChildrenTab({
    super.key,
    required this.children,
    required this.activeChild,
    required this.onChildSelected,
    required this.onRefresh,
    this.showBack = false,
  });

  @override
  State<ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends State<ChildrenTab> {
  final ChildService _childService = ChildService();
  final ScrollController _scrollController = ScrollController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToAddChild() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildPage()),
    );
    if (result == true || mounted) {
      widget.onRefresh();
    }
  }

  void _navigateToEditChild(ChildModel child) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditChildPage(child: child)),
    );
    if (result == true || mounted) {
      widget.onRefresh();
    }
  }

  String _resolveAvatarAsset(ChildModel c) {
    final g = c.gender.trim().toLowerCase();
    if (g == 'female' || g == 'girl') {
      return 'assets/illustrations/avatar_girl.webp';
    }
    return 'assets/illustrations/avatar_boy.webp';
  }

  void _showChildDetailSheet(ChildModel child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: MeadowColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: MeadowColors.primary, width: 2.0),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _resolveAvatarAsset(child),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: MeadowColors.primarySurface,
                          alignment: Alignment.center,
                          child: Text(
                            child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: MeadowColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: MeadowTypography.h2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Age ${child.age} (${child.ageDisplay}) · ${child.gender}',
                          style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: MeadowColors.borderLight, thickness: 1.0),
              const SizedBox(height: 14),
              Text(
                'Development & Health Overview',
                style: MeadowTypography.h3,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Birth Order',
                child.birthOrder != null ? '#${child.birthOrder}' : 'Not specified',
              ),
              _buildDetailRow('Delivery Type', child.deliveryType ?? 'Not specified'),
              _buildDetailRow('Sleep Habit', child.sleepHabit ?? 'Not specified'),
              _buildDetailRow('Profile Completion', '${child.profileCompletion}%'),
              if (child.isFlagged) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Status',
                  'Flagged for Support',
                  valueColor: const Color(0xFFB45309),
                ),
                if (child.flagReason != null)
                  _buildDetailRow(
                    'Support Reason',
                    child.flagReason!,
                    valueColor: const Color(0xFFB45309),
                  ),
              ],
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToEditChild(child);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MeadowColors.primary,
                        side: const BorderSide(color: MeadowColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MeadowRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onChildSelected(child);
                      },
                      style: MeadowButtons.primary().copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                      ),
                      child: const Text('Set as Active'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary)),
          Text(
            value,
            style: MeadowTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? MeadowColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ChildModel child) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.lg)),
        title: Text(
          'Delete Child Profile?',
          style: MeadowTypography.h2.copyWith(color: MeadowColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${child.name}\'s profile?',
              style: MeadowTypography.body,
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently delete:',
              style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('• All activities for ${child.name}', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
            Text('• All progress data and milestones', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
            Text('• All feedback and history', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: MeadowTypography.caption.copyWith(
                color: MeadowColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: MeadowTypography.button.copyWith(color: MeadowColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MeadowColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isDeleting = true);

              final error = await _childService.deleteChild(child.childId);

              if (!mounted) return;
              setState(() => _isDeleting = false);

              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Child profile deleted successfully'),
                    backgroundColor: MeadowColors.primary,
                  ),
                );
                widget.onRefresh();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: MeadowColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: MeadowColors.primarySurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('👶', style: TextStyle(fontSize: 44)),
            ),
            const SizedBox(height: 20),
            Text('No children yet', style: MeadowTypography.h2),
            const SizedBox(height: 8),
            Text(
              'Add your first child to start the journey and track developmental progress.',
              textAlign: TextAlign.center,
              style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddChild,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Child'),
                style: MeadowButtons.primary(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: GlobalHeader(
        showBack: widget.showBack,
        scrollController: _scrollController,
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator(color: MeadowColors.primary))
          : widget.children.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  color: MeadowColors.primary,
                  backgroundColor: MeadowColors.surface,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Your Children', style: MeadowTypography.h1),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddChild,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Child'),
                            style: MeadowButtons.small(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...widget.children.asMap().entries.map((entry) {
                        final child = entry.value;
                        final isSelected = child.childId == widget.activeChild?.childId;
                        return ChildCard(
                          child: child,
                          isSelected: isSelected,
                          onSelect: () => widget.onChildSelected(child),
                          onView: () => _showChildDetailSheet(child),
                          onEdit: () => _navigateToEditChild(child),
                          onDelete: () => _confirmDelete(child),
                        );
                      }),
                      const SizedBox(height: 8),
                      // Bottom CTA
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _navigateToAddChild,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            '+ Add Another Child',
                            style: MeadowTypography.button.copyWith(color: MeadowColors.primary),
                          ),
                          style: MeadowButtons.secondary(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
