// lib/screens/parent/home/widgets/child_switcher_card.dart
import 'package:flutter/material.dart';
import '../../../../models/child_model.dart';
import '../../../../models/journey_model.dart';
import '../../../../services/journey_service.dart';
import '../../../../theme/meadow_theme.dart';

class ChildSwitcherCard extends StatelessWidget {
  final ChildModel child;
  final List<ChildModel> children;
  final ValueChanged<ChildModel> onChildSelected;
  final VoidCallback onAddChild;
  final int? level;
  final Stream<JourneyProgress?>? journeyStream;

  const ChildSwitcherCard({
    super.key,
    required this.child,
    required this.children,
    required this.onChildSelected,
    required this.onAddChild,
    this.level,
    this.journeyStream,
  });

  String _resolveAvatarAsset(ChildModel c) {
    final g = c.gender.trim().toLowerCase();
    if (g == 'female' || g == 'girl') {
      return 'assets/illustrations/avatar_girl.webp';
    }
    return 'assets/illustrations/avatar_boy.webp';
  }

  void _showChildPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
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
                      color: MeadowColors.border,
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
                      style: MeadowTypography.h2,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onAddChild();
                      },
                      icon: const Icon(Icons.add, size: 18, color: MeadowColors.primary),
                      label: Text(
                        'Add Child',
                        style: MeadowTypography.caption.copyWith(
                          color: MeadowColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: MeadowColors.borderLight, thickness: 1.0),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: children.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: MeadowColors.borderLight,
                    ),
                    itemBuilder: (context, index) {
                      final item = children[index];
                      final isSelected = item.childId == child.childId;
                      final itemAvatar = _resolveAvatarAsset(item);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? MeadowColors.primary : MeadowColors.borderLight,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              itemAvatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: MeadowColors.primarySurface,
                                alignment: Alignment.center,
                                child: Text(
                                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '👶',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: MeadowColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: MeadowTypography.bodyLarge.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? MeadowColors.primary : MeadowColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Age ${item.age} · ${item.gender}',
                          style: MeadowTypography.caption.copyWith(
                            color: MeadowColors.textSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: MeadowColors.primary)
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
    final avatarAsset = _resolveAvatarAsset(child);

    return Container(
      width: double.infinity,
      decoration: MeadowCards.standard(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MeadowRadius.lg),
          onTap: () => _showChildPicker(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with Meadow border
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: MeadowColors.borderLight, width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      avatarAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: MeadowColors.primarySurface,
                        alignment: Alignment.center,
                        child: Text(
                          child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: MeadowColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name, age and level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              style: MeadowTypography.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: MeadowColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Age ${child.age} · Level $displayLevel',
                        style: MeadowTypography.caption.copyWith(
                          color: MeadowColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Switch chip badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MeadowColors.primarySurface,
                    borderRadius: BorderRadius.circular(MeadowRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 15,
                        color: MeadowColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Switch',
                        style: MeadowTypography.caption.copyWith(
                          color: MeadowColors.primary,
                          fontWeight: FontWeight.w700,
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

  Stream<JourneyProgress?> _resolveJourneyStream() {
    if (journeyStream != null) return journeyStream!;
    try {
      return JourneyService().getJourneyProgress(child.childId);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (level != null) {
      return _buildCard(context, level!);
    }

    return StreamBuilder<JourneyProgress?>(
      stream: _resolveJourneyStream(),
      builder: (context, snapshot) {
        final currentLevel = snapshot.data?.currentLevel ?? 1;
        return _buildCard(context, currentLevel);
      },
    );
  }
}
