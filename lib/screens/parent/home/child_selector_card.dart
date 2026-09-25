import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../services/journey_service.dart';
import '../parent_theme.dart';

class ChildSelectorCard extends StatelessWidget {
  final ChildModel child;
  final List<ChildModel> children;
  final ValueChanged<ChildModel> onChildSelected;
  final VoidCallback onAddChild;
  final int? level;

  const ChildSelectorCard({
    super.key,
    required this.child,
    required this.children,
    required this.onChildSelected,
    required this.onAddChild,
    this.level,
  });

  void _showChildPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: ParentRadius.modal,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Active Child',
                      style: ParentTypography.cardTitle,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onAddChild();
                      },
                      icon: const Icon(Icons.add, size: 18, color: ParentColors.primary),
                      label: Text(
                        'Add Child',
                        style: ParentTypography.caption.copyWith(
                          color: ParentColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: ParentColors.surfaceAlt, thickness: 1.5),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: children.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: ParentColors.surfaceAlt,
                    ),
                    itemBuilder: (context, index) {
                      final item = children[index];
                      final isSelected = item.childId == child.childId;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? ParentColors.primaryGradient
                                : LinearGradient(
                                    colors: [
                                      ParentColors.surfaceAlt,
                                      ParentColors.surfaceAlt,
                                    ],
                                  ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text(
                              item.name.isNotEmpty ? item.name[0].toUpperCase() : '👶',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? ParentColors.primary
                                    : ParentColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: ParentTypography.body.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? ParentColors.primary
                                : ParentColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Age ${item.age} · ${item.gender}',
                          style: ParentTypography.caption,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: ParentColors.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!isSelected) {
                            onChildSelected(item);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, int displayLevel) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ParentColors.surfaceAlt, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: ParentRadius.card,
        boxShadow: ParentShadows.card,
        border: Border.all(
          color: ParentColors.primary.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: ParentRadius.card,
          onTap: () => _showChildPicker(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Left avatar with gradient ring
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ParentColors.primaryGradient,
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ParentColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Center name + age/level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              style: ParentTypography.cardTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: ParentColors.primary,
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(begin: 0, end: 2, duration: 900.ms),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Age ${child.age} · Level $displayLevel',
                        style: ParentTypography.caption,
                      ),
                    ],
                  ),
                ),

                // Right Switch badge with subtle animation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ParentColors.primary.withOpacity(0.08),
                    borderRadius: ParentRadius.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 15,
                        color: ParentColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Switch',
                        style: ParentTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ParentColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (level != null) {
      return _buildCard(context, level!);
    }

    return StreamBuilder<JourneyProgress?>(
      stream: JourneyService().getJourneyProgress(child.childId),
      builder: (context, snapshot) {
        final currentLevel = snapshot.data?.currentLevel ?? 1;
        return _buildCard(context, currentLevel);
      },
    );
  }
}
