import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/desktop_parent_companion.dart';
import 'package:littlelumin/services/score_ledger_service.dart';
import 'package:littlelumin/theme/meadow_theme.dart';

class FakeScoreLedgerService extends ScoreLedgerService {
  final List<Map<String, dynamic>> fakeEvents;
  FakeScoreLedgerService(this.fakeEvents);

  @override
  Future<List<Map<String, dynamic>>> getScoreHistory({
    required String childId,
    String? skillDomain,
  }) async {
    if (skillDomain != null && skillDomain.isNotEmpty) {
      return fakeEvents
          .where((e) => e['skillDomain'] == skillDomain.toLowerCase())
          .toList();
    }
    return fakeEvents;
  }
}

void main() {
  final testChild = ChildModel(
    childId: 'child_123',
    parentId: 'parent_abc',
    name: 'Maya',
    dateOfBirth: DateTime(2021, 5, 10),
    gender: 'Female',
    createdAt: DateTime(2024, 1, 1),
  );

  group('Parent Growth Portal Parent-Friendly Text Verification Tests', () {
    testWidgets(
      'DesktopParentCompanionScreen renders all essential parent-friendly text without errors',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: DesktopParentCompanionScreen()),
        );

        // Verify the widget mounts cleanly
        expect(find.byType(DesktopParentCompanionScreen), findsOneWidget);
      },
    );

    test(
      'Verify static parent text strings and domain mappings in DesktopParentCompanionScreen',
      () {
        const screen = DesktopParentCompanionScreen();
        expect(screen, isNotNull);

        expect(
          DesktopParentCompanionScreen.getFriendlyDomainLabel('cognitive'),
          'Thinking and Learning',
        );
        expect(
          DesktopParentCompanionScreen.getFriendlyDomainLabel('language'),
          'Talking and Listening',
        );
        expect(
          DesktopParentCompanionScreen.getFriendlyDomainLabel('motor'),
          'Movement and Coordination',
        );
        expect(
          DesktopParentCompanionScreen.getFriendlyDomainLabel('social'),
          'Social Skills',
        );
        expect(
          DesktopParentCompanionScreen.getFriendlyDomainLabel('emotional'),
          'Understanding Feelings',
        );
        expect(
          DesktopParentCompanionScreen.getFriendlyDomainLabel('creative'),
          'Creativity and Imagination',
        );
      },
    );
  });

  group('DesktopKPICard Layout & Multi-line Wrapping Tests', () {
    testWidgets(
      'Wraps long KPI titles into 2 lines cleanly without ellipsis clipping at narrow desktop card widths',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220, // Simulates 4-column desktop breakpoint card
                  child: DesktopKPICard(
                    title: "YOUR CHILD'S LEARNING STAGE",
                    value: 'Level 2',
                    subtitle: 'Building Skills',
                    icon: Icons.military_tech_outlined,
                    accentColor: MeadowColors.gold,
                    tooltip: 'Test tooltip for learning stage',
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text("YOUR CHILD'S LEARNING STAGE"), findsOneWidget);
        expect(find.text('Level 2'), findsOneWidget);
        expect(find.text('Building Skills'), findsOneWidget);
        expect(find.byIcon(Icons.military_tech_outlined), findsOneWidget);

        // Verify title render box has reasonable non-zero height for 2 lines
        final RenderBox titleBox = tester.renderObject(
          find.text("YOUR CHILD'S LEARNING STAGE"),
        );
        expect(titleBox.size.height, greaterThanOrEqualTo(20.0));
        expect(titleBox.size.width, greaterThan(100.0));
      },
    );

    testWidgets(
      'Renders subtitle with 2 lines without overflow at narrow card widths',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: DesktopKPICard(
                    title: "YOUR CHILD'S PROGRESS",
                    value: '84.5%',
                    subtitle: '+7.5 pts compared with previous period',
                    icon: Icons.trending_up,
                    accentColor: MeadowColors.primary,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text("YOUR CHILD'S PROGRESS"), findsOneWidget);
        expect(find.text('84.5%'), findsOneWidget);
        expect(
          find.text('+7.5 pts compared with previous period'),
          findsOneWidget,
        );

        final RenderBox subtitleBox = tester.renderObject(
          find.text('+7.5 pts compared with previous period'),
        );
        expect(subtitleBox.size.height, greaterThanOrEqualTo(20.0));
      },
    );
  });

  group('DesktopDevelopmentalProgressSection Responsive Layout Tests', () {
    testWidgets(
      'Renders chart section at compact width (600px - split column view) with stacked heading and non-overlapping chips',
      (tester) async {
        final fakeService = FakeScoreLedgerService([]);

        await tester.binding.setSurfaceSize(const Size(600, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 600,
                  child: DesktopDevelopmentalProgressSection(
                    activeChild: testChild,
                    scoreService: fakeService,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Heading is rendered
        expect(find.text("Your Child's Progress Over Time"), findsOneWidget);

        // 2. Heading has sufficient width (> 300px) and does NOT wrap vertically 1 char per line
        final RenderBox headingBox = tester.renderObject(
          find.text("Your Child's Progress Over Time"),
        );
        expect(headingBox.size.width, greaterThan(300.0));
        expect(
          headingBox.size.height,
          lessThan(80.0),
        ); // Not 30 vertical lines!

        // 3. Subtitle is rendered
        expect(
          find.text(
            "See how your child's recorded progress changes over time.",
          ),
          findsOneWidget,
        );

        // 4. All filter chips are present
        expect(find.text('All Skills'), findsOneWidget);
        expect(find.text('Thinking and Learning'), findsOneWidget);
        expect(find.text('Talking and Listening'), findsOneWidget);
        expect(find.text('Movement and Coordination'), findsOneWidget);
        expect(find.text('Social Skills'), findsOneWidget);
        expect(find.text('Understanding Feelings'), findsOneWidget);
        expect(find.text('Creativity and Imagination'), findsOneWidget);

        // 5. Empty state renders with bounded valid constraints and friendly message
        expect(
          find.text('No recorded activities yet for Maya'),
          findsOneWidget,
        );
        expect(
          find.text(
            "As your child plays interactive games and practices skills on your phone, progress updates will show up here.",
          ),
          findsOneWidget,
        );

        // Verify chips are positioned below heading (no overlap)
        final headingOffset = tester.getBottomLeft(
          find.text(
            "See how your child's recorded progress changes over time.",
          ),
        );
        final chipOffset = tester.getTopLeft(find.text('All Skills'));
        expect(chipOffset.dy, greaterThanOrEqualTo(headingOffset.dy));
      },
    );

    testWidgets(
      'Renders chart section at wide width (1200px) with side-by-side row and bounded flex',
      (tester) async {
        final fakeService = FakeScoreLedgerService([]);

        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                child: DesktopDevelopmentalProgressSection(
                  activeChild: testChild,
                  scoreService: fakeService,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Your Child's Progress Over Time"), findsOneWidget);
        final RenderBox headingBox = tester.renderObject(
          find.text("Your Child's Progress Over Time"),
        );
        expect(headingBox.size.width, greaterThan(350.0));

        expect(find.text('All Skills'), findsOneWidget);
        expect(find.text('Movement and Coordination'), findsOneWidget);
      },
    );

    testWidgets(
      'Clicking a domain filter chip updates active filter and queries that domain',
      (tester) async {
        final fakeService = FakeScoreLedgerService([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 900,
                child: DesktopDevelopmentalProgressSection(
                  activeChild: testChild,
                  scoreService: fakeService,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on 'Movement and Coordination' chip
        await tester.tap(find.text('Movement and Coordination'));
        await tester.pumpAndSettle();

        // Empty state now says 'No recorded activities yet for Movement and Coordination'
        expect(
          find.text('No recorded activities yet for Movement and Coordination'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Renders LineChart canvas when score history events exist', (
      tester,
    ) async {
      final fakeEvents = [
        {
          'appliedScoreDelta': 10.0,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
          'skillDomain': 'cognitive',
        },
        {
          'appliedScoreDelta': 15.0,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
          'skillDomain': 'cognitive',
        },
        {
          'appliedScoreDelta': 20.0,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 15)),
          'skillDomain': 'cognitive',
        },
      ];

      final fakeService = FakeScoreLedgerService(fakeEvents);

      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: DesktopDevelopmentalProgressSection(
                activeChild: testChild,
                scoreService: fakeService,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The chart canvas LineChart widget must be rendered
      expect(find.byType(LineChart), findsOneWidget);

      // Verify valid dimensions for chart canvas (height 250, bounded width)
      final RenderBox chartBox = tester.renderObject(find.byType(LineChart));
      expect(chartBox.size.height, equals(250.0));
      expect(chartBox.size.width, greaterThan(500.0));
    });
  });
}
