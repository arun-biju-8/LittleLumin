import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../services/journey_service.dart';
import '../parent_theme.dart';

class ChildCard extends StatelessWidget {
  final ChildModel child;
  final int? level;
  final bool isSelected;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const ChildCard({
    super.key,
    required this.child,
    this.level,
    this.isSelected = false,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
  });

  List<MapEntry<String, double>> _getTopDomainScores() {
    if (child.vabsScores != null && child.vabsScores!.isNotEmpty) {
      final entries = child.vabsScores!.entries.toList();
      entries.sort((a, b) => b.value.compareTo(a.value));
      return entries.take(2).toList();
    }
    return const [
      MapEntry('Cognitive', 65.0),
      MapEntry('Language', 70.0),
    ];
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return ParentColors.success;
    if (score >= 50) return ParentColors.primary;
    return ParentColors.warning;
  }

  Widget _buildCardContent(
    BuildContext context,
    int level,
    List<MapEntry<String, double>> topScores,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        boxShadow: isSelected ? ParentShadows.elevated : ParentShadows.card,
        border: Border.all(
          color: isSelected ? ParentColors.primary : ParentColors.surfaceAlt,
          width: isSelected ? 2.0 : 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: ParentRadius.card,
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar (56x56) with gradient ring + Info + Active badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? ParentColors.primaryGradient
                            : LinearGradient(
                                colors: [
                                  ParentColors.primary.withOpacity(0.3),
                                  ParentColors.primaryLight.withOpacity(0.3),
                                ],
                              ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ParentColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  child.name,
                                  style: ParentTypography.cardTitle.copyWith(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (child.isFlagged) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: ParentRadius.chip,
                                    border: Border.all(
                                      color: ParentColors.warning.withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    '⚠️ Support',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Age ${child.age} · ${child.gender} · Level $level',
                            style: ParentTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          gradient: ParentColors.primaryGradient,
                          borderRadius: ParentRadius.chip,
                        ),
                        child: Text(
                          'Active',
                          style: ParentTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Domain progress chips colored by score band
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: topScores.map((entry) {
                    final color = _getScoreColor(entry.value);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: ParentRadius.chip,
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${entry.key}: ${entry.value.round()}%',
                            style: ParentTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: ParentColors.surfaceAlt),
                const SizedBox(height: 12),

                // Actions Row: [ View ] [ Edit ] [ Delete ]
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility_outlined, size: 17),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: ParentColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: ParentColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: ParentColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    final topScores = _getTopDomainScores();

    if (level != null) {
      return _buildCardContent(context, level!, topScores);
    }

    return StreamBuilder<JourneyProgress?>(
      stream: JourneyService().getJourneyProgress(child.childId),
      builder: (context, snapshot) {
        final currentLevel = snapshot.data?.currentLevel ?? 1;
        return _buildCardContent(context, currentLevel, topScores);
      },
    );
  }
}
