import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Activity Chaining Navigation Flow Tests', () {
    testWidgets('Chain: Activities -> Activity A -> Feedback Form -> Next Activity B -> Back returns to Activities Tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  children: [
                    const Text('Activities Tab'),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctxA) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Activity A Screen'),
                                leading: BackButton(onPressed: () => Navigator.pop(ctxA)),
                              ),
                              body: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    ctxA,
                                    MaterialPageRoute(
                                      builder: (ctxFeedback) => Scaffold(
                                        appBar: AppBar(title: const Text('Feedback Form')),
                                        body: ElevatedButton(
                                          onPressed: () {
                                            // Navigation fix applied in feedback_form.dart
                                            Navigator.pushAndRemoveUntil(
                                              ctxFeedback,
                                              MaterialPageRoute(
                                                builder: (ctxB) => Scaffold(
                                                  appBar: AppBar(
                                                    title: const Text('Activity B Screen'),
                                                    leading: BackButton(onPressed: () => Navigator.pop(ctxB)),
                                                  ),
                                                  body: const Text('Activity B Details'),
                                                ),
                                              ),
                                              (route) => route.isFirst,
                                            );
                                          },
                                          child: const Text('Submit Feedback & Open Next Activity'),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Complete Activity A'),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Activity A'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Initial State: Activities Tab is visible
      expect(find.text('Activities Tab'), findsOneWidget);
      expect(find.text('Activity A Screen'), findsNothing);

      // 2. Tap to open Activity A
      await tester.tap(find.text('Open Activity A'));
      await tester.pumpAndSettle();
      expect(find.text('Activity A Screen'), findsOneWidget);

      // 3. Complete Activity A -> Feedback Form
      await tester.tap(find.text('Complete Activity A'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback Form'), findsOneWidget);

      // 4. Submit Feedback -> Proceeds to Next Activity B via pushAndRemoveUntil((route) => route.isFirst)
      await tester.tap(find.text('Submit Feedback & Open Next Activity'));
      await tester.pumpAndSettle();
      expect(find.text('Activity B Screen'), findsOneWidget);
      expect(find.text('Feedback Form'), findsNothing);
      expect(find.text('Activity A Screen'), findsNothing);

      // 5. Press Back on Activity B
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 6. Expected: Back lands directly on Activities Tab (route.isFirst), NEVER Activity A
      expect(find.text('Activities Tab'), findsOneWidget);
      expect(find.text('Activity A Screen'), findsNothing);
      expect(find.text('Activity B Screen'), findsNothing);
    });

    testWidgets('Single: Activities -> Activity A -> Back returns to Activities Tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctxA) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Activity A Screen'),
                            leading: BackButton(onPressed: () => Navigator.pop(ctxA)),
                          ),
                          body: const Text('Activity A Details'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Activity A'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Activity A'));
      await tester.pumpAndSettle();
      expect(find.text('Activity A Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open Activity A'), findsOneWidget);
      expect(find.text('Activity A Screen'), findsNothing);
    });

    testWidgets('Feedback cancel: Activities -> Activity A -> Feedback -> Back returns to Activity A', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctxA) => Scaffold(
                          appBar: AppBar(title: const Text('Activity A Screen')),
                          body: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                ctxA,
                                MaterialPageRoute(
                                  builder: (ctxFeedback) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Feedback Form'),
                                      leading: BackButton(onPressed: () => Navigator.pop(ctxFeedback)),
                                    ),
                                    body: const Text('Feedback Form Content'),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Complete Activity A'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Activity A'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Activity A'));
      await tester.pumpAndSettle();
      expect(find.text('Activity A Screen'), findsOneWidget);

      await tester.tap(find.text('Complete Activity A'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback Form'), findsOneWidget);

      // Cancel feedback by pressing Back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Returns to Activity A
      expect(find.text('Activity A Screen'), findsOneWidget);
      expect(find.text('Feedback Form'), findsNothing);
    });

    testWidgets('Feedback with no next activity pops back to Activities Tab (route.isFirst)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: const Text('Activities Tab'),
            ),
          ),
        ),
      );

      final navContext = tester.element(find.text('Activities Tab'));

      // Push Activity A
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (ctxA) => Scaffold(
            body: const Text('Activity A Screen'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Activity A Screen'), findsOneWidget);

      // Push Feedback
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (ctxFeedback) => Scaffold(
            body: const Text('Feedback Form'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Feedback Form'), findsOneWidget);

      // When no next activity: Navigator.of(context).popUntil((route) => route.isFirst)
      Navigator.of(navContext).popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();

      expect(find.text('Activities Tab'), findsOneWidget);
      expect(find.text('Activity A Screen'), findsNothing);
      expect(find.text('Feedback Form'), findsNothing);
    });

    testWidgets('Level complete dialog dismiss pops back to Activities Tab (route.isFirst)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: const Text('Activities Tab'),
            ),
          ),
        ),
      );

      final navContext = tester.element(find.text('Activities Tab'));

      // Push Activity A
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (ctxA) => Scaffold(
            body: const Text('Activity A Screen'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push Feedback Form
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (ctxFeedback) => Scaffold(
            body: const Text('Feedback Form'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Show level complete dialog
      showDialog(
        context: navContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Level Complete!'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.of(navContext).popUntil((route) => route.isFirst);
              },
              child: const Text('Continue Journey'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Level Complete!'), findsOneWidget);

      // Tap dialog action
      await tester.tap(find.text('Continue Journey'));
      await tester.pumpAndSettle();

      expect(find.text('Activities Tab'), findsOneWidget);
      expect(find.text('Activity A Screen'), findsNothing);
      expect(find.text('Feedback Form'), findsNothing);
      expect(find.text('Level Complete!'), findsNothing);
    });
  });
}
