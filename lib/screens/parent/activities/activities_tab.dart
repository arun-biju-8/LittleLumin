import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../widgets/global_header.dart';
import '../parent_theme.dart';
import 'tabs/all_activities_tab.dart';
import 'tabs/journey_tab.dart';
import 'tabs/ai_activity_tab.dart';
import 'tabs/story_mode_tab.dart';
import 'tabs/ai_story_tab.dart';

class ActivitiesTab extends StatefulWidget {
  final ChildModel? activeChild;
  final int initialSubTabIndex;

  const ActivitiesTab({
    super.key,
    required this.activeChild,
    this.initialSubTabIndex = 0,
  });

  @override
  State<ActivitiesTab> createState() => ActivitiesTabState();
}

class ActivitiesTabState extends State<ActivitiesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialSubTabIndex.clamp(0, 4),
    );
  }

  @override
  void didUpdateWidget(covariant ActivitiesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTabIndex != widget.initialSubTabIndex) {
      _tabController.animateTo(widget.initialSubTabIndex.clamp(0, 4));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void selectSubTab(int index) {
    if (mounted && index >= 0 && index < 5) {
      _tabController.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentColors.surfaceAlt,
      appBar: const GlobalHeader(
        showBack: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: ParentColors.primary.withOpacity(0.12),
                borderRadius: ParentRadius.chip,
                border: Border.all(
                  color: ParentColors.primary.withOpacity(0.2),
                  width: 1.2,
                ),
              ),
              labelColor: ParentColors.primary,
              unselectedLabelColor: ParentColors.textSecondary,
              labelStyle: ParentTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: ParentTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.apps_rounded, size: 18),
                  text: 'All',
                ),
                Tab(
                  icon: Icon(Icons.explore_outlined, size: 18),
                  text: 'Journey',
                ),
                Tab(
                  icon: Icon(Icons.auto_awesome_rounded, size: 18),
                  text: 'AI Act',
                ),
                Tab(
                  icon: Icon(Icons.menu_book_rounded, size: 18),
                  text: 'Story',
                ),
                Tab(
                  icon: Icon(Icons.auto_stories_rounded, size: 18),
                  text: 'AI Story',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AllActivitiesTab(activeChild: widget.activeChild),
                JourneyTab(activeChild: widget.activeChild),
                AIActivityTab(activeChild: widget.activeChild),
                StoryModeTab(onNavigateToAIStory: () => selectSubTab(4)),
                AIStoryTab(activeChild: widget.activeChild),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
