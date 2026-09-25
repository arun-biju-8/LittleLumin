import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/child_model.dart';
import '../../../theme/meadow_theme.dart';
import '../../../widgets/global_header.dart';
import '../../../services/saved_items_service.dart';
import '../activities/tabs/ai_story_tab.dart';

class StoriesTab extends StatefulWidget {
  final ChildModel? activeChild;
  final Stream<QuerySnapshot>? storiesStream;
  final SavedItemsService? savedItemsService;

  const StoriesTab({
    super.key,
    this.activeChild,
    this.storiesStream,
    this.savedItemsService,
  });

  @override
  State<StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<StoriesTab> {
  SavedItemsService? _service;
  SavedItemsService get _savedItemsService =>
      widget.savedItemsService ?? (_service ??= SavedItemsService());
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openStoryCreator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: GlobalHeader(
            showBack: true,
            title: 'Create Story',
            onBackTap: () => Navigator.pop(context),
          ),
          body: AIStoryTab(activeChild: widget.activeChild),
        ),
      ),
    );
  }

  Future<void> _deleteStory(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.lg)),
        title: Text('Delete Story?', style: MeadowTypography.h3),
        content: Text('Are you sure you want to remove this story?', style: MeadowTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: MeadowTypography.button.copyWith(color: MeadowColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MeadowColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _savedItemsService.deleteSavedStory(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story deleted'),
            backgroundColor: MeadowColors.primary,
          ),
        );
      }
    }
  }

  Widget _buildStoryCard(String id, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Story';
    final story = data['story'] ?? '';
    final moral = data['moral']?.toString();
    final readingTime = data['readingTime']?.toString() ?? '5-7 minutes';

    return Container(
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.lg),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.cardPadding, vertical: MeadowSpacing.sm),
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: MeadowColors.goldSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.book, color: MeadowColors.gold, size: 22),
          ),
          title: Text(
            title,
            style: MeadowTypography.h3,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: MeadowColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  readingTime,
                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MeadowSpacing.cardPadding,
                0,
                MeadowSpacing.cardPadding,
                MeadowSpacing.cardPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: MeadowColors.borderLight),
                  const SizedBox(height: MeadowSpacing.sm),
                  Text(
                    story,
                    style: MeadowTypography.body.copyWith(
                      color: MeadowColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (moral != null && moral.isNotEmpty) ...[
                    const SizedBox(height: MeadowSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(MeadowSpacing.md),
                      decoration: BoxDecoration(
                        color: MeadowColors.goldSurface,
                        borderRadius: BorderRadius.circular(MeadowRadius.md),
                        border: Border.all(color: MeadowColors.gold.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 ', style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Text(
                              'Moral: $moral',
                              style: MeadowTypography.caption.copyWith(
                                color: MeadowColors.textPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: MeadowSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _deleteStory(id),
                      icon: const Icon(Icons.delete_outline, color: MeadowColors.error, size: 18),
                      label: Text(
                        'Delete Story',
                        style: MeadowTypography.caption.copyWith(
                          color: MeadowColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Stream<QuerySnapshot> _resolveStream() {
    if (widget.storiesStream != null) return widget.storiesStream!;
    try {
      return _savedItemsService.getSavedStories(childId: widget.activeChild?.childId);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: GlobalHeader(
        showBack: false,
        scrollController: _scrollController,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.screenH, vertical: MeadowSpacing.lg),
        children: [
          // Header
          Text('Stories', style: MeadowTypography.display),
          const SizedBox(height: MeadowSpacing.xs),
          Text(
            'Stories that bring learning to life',
            style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: MeadowSpacing.xl),

          // Top Card: "✨ Create a Story"
          Container(
            padding: const EdgeInsets.all(MeadowSpacing.xl),
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(MeadowRadius.xl),
              border: Border.all(color: MeadowColors.borderLight),
              boxShadow: MeadowShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: MeadowColors.goldSurface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('✨', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: MeadowSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create a Story', style: MeadowTypography.h2),
                          const SizedBox(height: 2),
                          Text(
                            'Personalized AI adventures tailored for your child',
                            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MeadowSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openStoryCreator,
                    icon: const Icon(Icons.auto_stories, size: 20),
                    label: const Text('Start Creating'),
                    style: MeadowButtons.primary(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: MeadowSpacing.xxl),

          // Section Title: My Saved Stories
          Row(
            children: [
              Text('My Saved Stories', style: MeadowTypography.h2),
              const Spacer(),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Saved stories stream
          StreamBuilder<QuerySnapshot>(
            stream: _resolveStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(MeadowSpacing.xxl),
                  child: Center(
                    child: CircularProgressIndicator(color: MeadowColors.primary),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.xl, vertical: MeadowSpacing.xxxl),
                  decoration: BoxDecoration(
                    color: MeadowColors.surface,
                    borderRadius: BorderRadius.circular(MeadowRadius.lg),
                    border: Border.all(color: MeadowColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(MeadowSpacing.lg),
                        decoration: const BoxDecoration(
                          color: MeadowColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.book_outlined,
                          size: 40,
                          color: MeadowColors.primary,
                        ),
                      ),
                      const SizedBox(height: MeadowSpacing.md),
                      Text('No Saved Stories Yet', style: MeadowTypography.h3),
                      const SizedBox(height: MeadowSpacing.xs),
                      Text(
                        'Generate stories with your child and tap save to read them here anytime.',
                        textAlign: TextAlign.center,
                        style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: MeadowSpacing.md),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildStoryCard(doc.id, data);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
