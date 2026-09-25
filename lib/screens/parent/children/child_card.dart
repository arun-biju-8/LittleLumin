// lib/screens/parent/children/child_card.dart
import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../services/journey_service.dart';
import '../../../theme/meadow_theme.dart';

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

  String _resolveAvatarAsset() {
    final g = child.gender.trim().toLowerCase();
    if (g == 'female' || g == 'girl') {
      return 'assets/illustrations/avatar_girl.webp';
    }
    return 'assets/illustrations/avatar_boy.webp';
  }

  Widget _buildCardContent(
    BuildContext context,
    int displayLevel,
    List<MapEntry<String, double>> topScores,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.lg),
        border: Border.all(
          color: isSelected ? MeadowColors.primary : MeadowColors.borderLight,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected ? MeadowShadows.elevated : MeadowShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MeadowRadius.lg),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar + Name/Age + Active/Support badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? MeadowColors.primary : MeadowColors.borderLight,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          _resolveAvatarAsset(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: MeadowColors.primarySurface,
                            alignment: Alignment.center,
                            child: Text(
                              child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: MeadowColors.primary,
                              ),
                            ),
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
                                  style: MeadowTypography.h2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (child.isFlagged) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MeadowColors.goldSurface,
                                    borderRadius: BorderRadius.circular(MeadowRadius.pill),
                                    border: Border.all(color: MeadowColors.gold.withOpacity(0.5)),
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
                            'Age ${child.age} · ${child.gender} · Level $displayLevel',
                            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MeadowColors.primary,
                          borderRadius: BorderRadius.circular(MeadowRadius.pill),
                        ),
                        child: Text(
                          'Active',
                          style: MeadowTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Top Scores chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: topScores.map((entry) {
                    final domainColor = MeadowDomain.colorFor(entry.key);
                    final domainSurface = MeadowDomain.surfaceFor(entry.key);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: domainSurface,
                        borderRadius: BorderRadius.circular(MeadowRadius.pill),
                        border: Border.all(color: domainColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: domainColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${entry.key} ${entry.value.round()}%',
                            style: MeadowTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: domainColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: MeadowColors.borderLight),
                const SizedBox(height: 6),

                // Action buttons: [ View ] [ Edit ] [ Delete ]
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: MeadowColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: MeadowColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: MeadowColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Stream<JourneyProgress?> _resolveJourneyStream() {
    try {
      return JourneyService().getJourneyProgress(child.childId);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topScores = _getTopDomainScores();

    if (level != null) {
      return _buildCardContent(context, level!, topScores);
    }

    return StreamBuilder<JourneyProgress?>(
      stream: _resolveJourneyStream(),
      builder: (context, snapshot) {
        final currentLevel = snapshot.data?.currentLevel ?? 1;
        return _buildCardContent(context, currentLevel, topScores);
      },
    );
  }
}
