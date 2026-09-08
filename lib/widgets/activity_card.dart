// lib/widgets/activity_card.dart
import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../utils/constants.dart';

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;
  final bool showAdminControls;
  final bool compact;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
    this.showAdminControls = false,
    this.compact = false,
  });

  /// Emoji icon mapping per skill type
  static String getSkillEmoji(String skillType) {
    switch (skillType.trim().toLowerCase()) {
      case 'cognitive':
        return '🧠';
      case 'language':
        return '🗣️';
      case 'motor':
        return '✋';
      case 'social':
        return '👫';
      case 'emotional':
        return '❤️';
      case 'creative':
        return '🎨';
      case 'listening':
        return '👂';
      default:
        return '⭐';
    }
  }

  /// Color palette mapping per skill type
  static Color getSkillColor(String skillType) {
    switch (skillType.trim().toLowerCase()) {
      case 'cognitive':
        return const Color(0xFF4A90D9); // Blue
      case 'language':
        return const Color(0xFF9B59B6); // Purple
      case 'motor':
        return const Color(0xFFF39C12); // Orange
      case 'social':
        return const Color(0xFF2ECC71); // Green
      case 'emotional':
        return const Color(0xFFE74C3C); // Red
      case 'creative':
        return const Color(0xFFF1C40F); // Yellow
      case 'listening':
        return const Color(0xFF1ABC9C); // Teal
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompactGridCard(context) : _buildFullListCard(context);
  }

  /// Ultra-Compact Grid Card View (~95-100px height)
  Widget _buildCompactGridCard(BuildContext context) {
    final emoji = getSkillEmoji(activity.skillType);
    final skillColor = getSkillColor(activity.skillType);
    final difficultyColor = activity.difficulty == 'Easy'
        ? AppColors.success
        : activity.difficulty == 'Medium'
            ? AppColors.primary
            : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(
          color: activity.isActive
              ? AppColors.border.withOpacity(0.7)
              : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Emoji Icon + Status + Edit/Delete
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: skillColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (showAdminControls)
                      GestureDetector(
                        onTap: onToggleStatus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: activity.isActive
                                ? AppColors.success.withOpacity(0.12)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            activity.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: activity.isActive ? AppColors.success : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (showAdminControls) ...[
                      if (onEdit != null)
                        InkWell(
                          onTap: onEdit,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.edit, size: 14, color: AppColors.primary),
                          ),
                        ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.delete_outline, size: 14, color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),

                // Title (1 line)
                Text(
                  activity.title,
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 12.5,
                    height: 1.15,
                    fontWeight: FontWeight.bold,
                    color: activity.isActive ? AppColors.textDark : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.shortDescription != null && activity.shortDescription!.trim().isNotEmpty)
                  Text(
                    activity.shortDescription!,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                // Bottom Row: Age/Duration & Difficulty
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${activity.ageGroupDisplay} · ${activity.duration}m',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: difficultyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activity.difficulty,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: difficultyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ultra-Compact Horizontal List Tile (~72-80px height)
  Widget _buildFullListCard(BuildContext context) {
    final emoji = getSkillEmoji(activity.skillType);
    final skillColor = getSkillColor(activity.skillType);
    final difficultyColor = activity.difficulty == 'Easy'
        ? AppColors.success
        : activity.difficulty == 'Medium'
            ? AppColors.primary
            : AppColors.warning;

    final hasTagline = activity.shortDescription != null && activity.shortDescription!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: activity.isActive
              ? AppColors.border.withOpacity(0.6)
              : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Skill Emoji Avatar (40x40)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: skillColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: skillColor.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Title & Metadata Subtitle Column (Left to Right)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        activity.title,
                        style: AppTextStyles.heading2.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: activity.isActive ? AppColors.textDark : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasTagline) ...[
                        const SizedBox(height: 1),
                        Text(
                          activity.shortDescription!,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (activity.isEditedFromPreset && activity.originalTitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          '✏️ Edited from: ${activity.originalTitle}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (activity.isPreset) ...[
                        const SizedBox(height: 1),
                        Text(
                          '📚 Preset Activity',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${activity.skillType}  ·  ${activity.ageGroupDisplay}  ·  ${activity.duration}m',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Difficulty Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${activity.difficultyIcon} ${activity.difficulty}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: difficultyColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Active/Inactive Status Badge (Admin/LLG View)
                if (showAdminControls) ...[
                  GestureDetector(
                    onTap: onToggleStatus,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activity.isActive
                            ? AppColors.success.withOpacity(0.12)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: activity.isActive
                              ? AppColors.success.withOpacity(0.3)
                              : Colors.grey[400]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            activity.isActive ? Icons.check_circle : Icons.pause_circle_filled,
                            size: 10,
                            color: activity.isActive ? AppColors.success : Colors.grey[600],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            activity.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: activity.isActive ? AppColors.success : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 5. Actions (Edit & Delete)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 17, color: AppColors.primary),
                          onPressed: onEdit,
                          tooltip: 'Edit Activity',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red),
                          onPressed: onDelete,
                          tooltip: 'Delete Activity',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


