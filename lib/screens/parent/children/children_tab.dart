import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/child_model.dart';
import '../../../services/child_service.dart';
import '../add_child_page.dart';
import '../edit_child_page.dart';
import '../parent_theme.dart';
import '../../../widgets/global_header.dart';
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

  void _showChildDetailSheet(ChildModel child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: ParentRadius.modal,
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
                    color: ParentColors.textTertiary.withOpacity(0.4),
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
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ParentColors.primaryGradient,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ParentColors.primary,
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
                          style: ParentTypography.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Age ${child.age} (${child.ageDisplay}) · ${child.gender}',
                          style: ParentTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: ParentColors.surfaceAlt, thickness: 1.5),
              const SizedBox(height: 14),
              Text(
                'Development & Health Overview',
                style: ParentTypography.cardTitle.copyWith(fontSize: 16),
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
                  valueColor: ParentColors.warning,
                ),
                if (child.flagReason != null)
                  _buildDetailRow(
                    'Support Reason',
                    child.flagReason!,
                    valueColor: ParentColors.warning,
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
                        foregroundColor: ParentColors.primary,
                        side: const BorderSide(color: ParentColors.primaryLight),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ParentRadius.button,
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParentColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ParentRadius.button,
                        ),
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
          Text(label, style: ParentTypography.bodyLight),
          Text(
            value,
            style: ParentTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? ParentColors.textPrimary,
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
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text(
          'Delete Child Profile?',
          style: ParentTypography.cardTitle.copyWith(
            color: ParentColors.error,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${child.name}\'s profile?',
              style: ParentTypography.body,
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently delete:',
              style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('• All activities for ${child.name}', style: ParentTypography.body.copyWith(fontSize: 13)),
            Text('• All progress data and milestones', style: ParentTypography.body.copyWith(fontSize: 13)),
            Text('• All feedback and history', style: ParentTypography.body.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: ParentTypography.caption.copyWith(
                color: ParentColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: ParentRadius.button,
              ),
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
                    backgroundColor: ParentColors.success,
                  ),
                );
                widget.onRefresh();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: ParentColors.error,
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
              decoration: BoxDecoration(
                color: ParentColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('👶', style: TextStyle(fontSize: 44)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -8, duration: 1800.ms, curve: Curves.easeInOut),
            const SizedBox(height: 20),
            Text(
              'No children yet',
              style: ParentTypography.title,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first child to start the journey and track developmental progress.',
              textAlign: TextAlign.center,
              style: ParentTypography.bodyLight,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddChild,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Add Child',
                  style: ParentTypography.button.copyWith(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParentColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ParentRadius.button,
                  ),
                ),
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
      backgroundColor: ParentColors.surfaceAlt,
      appBar: GlobalHeader(
        showBack: widget.showBack,
        scrollController: _scrollController,
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : widget.children.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  color: ParentColors.primary,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Children',
                            style: ParentTypography.title,
                          ),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddChild,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Child'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParentColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: const RoundedRectangleBorder(
                                borderRadius: ParentRadius.chip,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...widget.children.asMap().entries.map((entry) {
                        final index = entry.key;
                        final child = entry.value;
                        final isSelected = child.childId == widget.activeChild?.childId;
                        return ChildCard(
                          child: child,
                          isSelected: isSelected,
                          onSelect: () => widget.onChildSelected(child),
                          onView: () => _showChildDetailSheet(child),
                          onEdit: () => _navigateToEditChild(child),
                          onDelete: () => _confirmDelete(child),
                        )
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: 70 * index), duration: 350.ms)
                            .slideY(begin: 0.05, end: 0, duration: 350.ms);
                      }),
                      const SizedBox(height: 8),
                      // Bottom CTA
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _navigateToAddChild,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            '+ Add Another Child',
                            style: ParentTypography.button.copyWith(
                              color: ParentColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: ParentColors.primary.withOpacity(0.35),
                              width: 1.5,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: ParentRadius.button,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
