import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../services/saved_items_service.dart';
import '../../parent_theme.dart';

class StoryModeTab extends StatefulWidget {
  final VoidCallback onNavigateToAIStory;

  const StoryModeTab({
    super.key,
    required this.onNavigateToAIStory,
  });

  @override
  State<StoryModeTab> createState() => _StoryModeTabState();
}

class _StoryModeTabState extends State<StoryModeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final SavedItemsService _service = SavedItemsService();

  void _showStoryReader(BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Story';
    final story = data['story'] ?? data['content'] ?? data['storyText'] ?? '';
    final moral = data['moral'] ?? data['moralLesson'] ?? '';
    final theme = data['theme'] ?? 'Adventure';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: ParentRadius.modal,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ParentColors.accent, Color(0xFFF59E0B)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('📖', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: ParentTypography.title.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Theme: $theme · 3 min read',
                          style: ParentTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: ParentColors.surfaceAlt, thickness: 1.5),
              const SizedBox(height: 16),
              Text(
                story,
                style: ParentTypography.body.copyWith(
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
              if (moral.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ParentColors.accent.withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🌟', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Moral of the Story',
                              style: ParentTypography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              moral,
                              style: ParentTypography.body.copyWith(
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF92400E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParentColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ParentRadius.button,
                    ),
                  ),
                  child: Text('Done Reading', style: ParentTypography.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteStory(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text('Delete Story?', style: ParentTypography.cardTitle),
        content: Text('Are you sure you want to delete "$title"?', style: ParentTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
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
              Navigator.pop(dialogCtx);
              await _service.deleteSavedStory(docId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Story removed')),
                );
              }
            },
            child: const Text('Delete'),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ParentColors.accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('📖', style: TextStyle(fontSize: 40)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -6, duration: 1600.ms),
            const SizedBox(height: 18),
            Text(
              'No Saved Stories Yet',
              style: ParentTypography.title,
            ),
            const SizedBox(height: 6),
            Text(
              'Create personalized bedtime and adventure tales with the AI Story creator and save them here.',
              textAlign: TextAlign.center,
              style: ParentTypography.bodyLight,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigateToAIStory,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text('Create an AI Story', style: ParentTypography.button),
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
    super.build(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _service.getSavedStories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = data['title'] ?? 'Story';
            final story = data['story'] ?? data['content'] ?? data['storyText'] ?? '';
            final moral = data['moral'] ?? data['moralLesson'] ?? '';
            final snippet = story.length > 85 ? '${story.substring(0, 85)}...' : story;

            String dateStr = '';
            if (data['createdAt'] is Timestamp) {
              final dt = (data['createdAt'] as Timestamp).toDate();
              dateStr = '${dt.day}/${dt.month}/${dt.year}';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: ParentRadius.card,
                border: Border.all(color: ParentColors.surfaceAlt, width: 1.2),
                boxShadow: ParentShadows.card,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: ParentRadius.card,
                  onTap: () => _showStoryReader(context, data),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ParentColors.accent.withOpacity(0.3),
                                    ParentColors.accent.withOpacity(0.1),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('📖', style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: ParentTypography.cardTitle.copyWith(fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      'Saved on $dateStr · 3 min read',
                                      style: ParentTypography.caption,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: ParentColors.error),
                              onPressed: () => _confirmDeleteStory(context, doc.id, title),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          snippet,
                          style: ParentTypography.body.copyWith(
                            fontSize: 13,
                            color: ParentColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (moral.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: ParentRadius.chip,
                              border: Border.all(color: ParentColors.accent.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🌟 ', style: TextStyle(fontSize: 11)),
                                Flexible(
                                  child: Text(
                                    moral,
                                    style: ParentTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFB45309),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              ),
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 300.ms)
                .slideY(begin: 0.05, end: 0, duration: 300.ms);
          },
        );
      },
    );
  }
}
