// lib/screens/parent/tabs/stories_tab.dart
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
            child: const Icon(Icons.book_rounded, color: MeadowColors.gold, size: 22),
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
    final kidName = widget.activeChild?.name ?? 'your child';

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: GlobalHeader(
        showBack: false,
        scrollController: _scrollController,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.screenH, vertical: MeadowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Text('Stories', style: MeadowTypography.display),
          const SizedBox(height: MeadowSpacing.xs),
          Text(
            'Stories that bring learning to life',
            style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: MeadowSpacing.xl),

          // Top Card: "✨ Create a Story" with story_reading.webp illustration
          Container(
            padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
            decoration: MeadowCards.hero(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Create a Story',
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Illustration
                ClipRRect(
                  borderRadius: BorderRadius.circular(MeadowRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      'assets/illustrations/story_reading.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: MeadowColors.primarySurface,
                        child: const Icon(Icons.menu_book_rounded, color: MeadowColors.primary, size: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Personalized stories for $kidName',
                  style: MeadowTypography.h2,
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate magical stories featuring values, themes, and characters designed for $kidName.',
                  style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openStoryCreator,
                    style: MeadowButtons.primary(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Open AI Story Creator →',
                          style: MeadowTypography.button.copyWith(color: MeadowColors.textInverse),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: MeadowSpacing.xxl),

          // Section Title: My Saved Stories
          Text(
            'My Saved Stories',
            style: MeadowTypography.caption.copyWith(
              color: MeadowColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
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
                  decoration: MeadowCards.standard(),
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
                separatorBuilder: (context, index) => const SizedBox(height: MeadowSpacing.md),
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
    ),
  );
}
}
