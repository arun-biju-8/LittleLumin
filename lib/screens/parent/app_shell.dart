import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/child_model.dart';
import '../../theme/meadow_theme.dart';
import 'home/home_tab.dart';
import 'tabs/growth_tab.dart';
import 'activities/activities_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/more_tab.dart';
import 'add_child_page.dart';
import 'notifications_page.dart';

class AppShell extends StatefulWidget {
  final int initialTab;
  final ChildModel? activeChild;
  final List<ChildModel> children;
  final String parentName;
  final ValueChanged<ChildModel>? onChildSelected;
  final VoidCallback? onAddChild;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onRefresh;
  final List<Widget>? tabViews;

  const AppShell({
    super.key,
    this.initialTab = 0,
    this.activeChild,
    this.children = const [],
    this.parentName = 'Parent',
    this.onChildSelected,
    this.onAddChild,
    this.onNotificationsTap,
    this.onRefresh,
    this.tabViews,
  });

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _currentIndex;
  int _activitiesSubTabIndex = 0;

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 4);
  }

  void _selectTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void setTab(int index) {
    _selectTab(index.clamp(0, 4));
  }

  void _navigateToAddChild() async {
    if (widget.onAddChild != null) {
      widget.onAddChild!();
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildPage()),
    );
    if (result == true && mounted) {
      widget.onRefresh?.call();
    }
  }

  void _navigateToNotifications() {
    if (widget.onNotificationsTap != null) {
      widget.onNotificationsTap!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.lg)),
            title: Text('Exit LittleLumin?', style: MeadowTypography.h2),
            content: Text('Are you sure you want to close the app?', style: MeadowTypography.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Stay', style: MeadowTypography.button.copyWith(color: MeadowColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeadowColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: MeadowColors.cream,
        body: IndexedStack(
          index: _currentIndex,
          children: widget.tabViews ?? [
            // TAB 0: HOME
            HomeTab(
              parentName: widget.parentName,
              activeChild: widget.activeChild,
              children: widget.children,
              onChildSelected: (child) => widget.onChildSelected?.call(child),
              onAddChild: _navigateToAddChild,
              onNotificationsTap: _navigateToNotifications,
              onSettingsTap: () => _selectTab(4), // More
              onContinueJourney: () => _selectTab(1), // Growth
              onAIActivity: () {
                setState(() => _activitiesSubTabIndex = 2);
                _selectTab(2); // Activities
              },
              onAIStory: () => _selectTab(3), // Stories
              onAllActivities: () {
                setState(() => _activitiesSubTabIndex = 0);
                _selectTab(2); // Activities
              },
            ),

            // TAB 1: GROWTH (wraps JourneyViewScreen)
            GrowthTab(
              activeChild: widget.activeChild,
            ),

            // TAB 2: ACTIVITIES
            ActivitiesTab(
              activeChild: widget.activeChild,
              initialSubTabIndex: _activitiesSubTabIndex,
            ),

            // TAB 3: STORIES
            StoriesTab(
              activeChild: widget.activeChild,
            ),

            // TAB 4: MORE
            MoreTab(
              activeChild: widget.activeChild,
              children: widget.children,
              onChildSelected: widget.onChildSelected,
              onAddChild: _navigateToAddChild,
              onRefresh: widget.onRefresh,
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: MeadowColors.surface,
        boxShadow: MeadowShadows.card,
        border: Border(
          top: BorderSide(color: MeadowColors.borderLight, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                outlinedIcon: Icons.home_outlined,
                filledIcon: Icons.home,
              ),
              _buildNavItem(
                index: 1,
                label: 'Growth',
                outlinedIcon: Icons.trending_up_outlined,
                filledIcon: Icons.trending_up,
              ),
              _buildNavItem(
                index: 2,
                label: 'Activities',
                outlinedIcon: Icons.grid_view_outlined,
                filledIcon: Icons.grid_view,
              ),
              _buildNavItem(
                index: 3,
                label: 'Stories',
                outlinedIcon: Icons.book_outlined,
                filledIcon: Icons.book,
              ),
              _buildNavItem(
                index: 4,
                label: 'More',
                outlinedIcon: Icons.more_horiz_outlined,
                filledIcon: Icons.more_horiz,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData outlinedIcon,
    required IconData filledIcon,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? MeadowColors.primary : MeadowColors.textTertiary;
    final icon = isSelected ? filledIcon : outlinedIcon;

    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MeadowTypography.caption.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
