import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity_model.dart';
import '../../services/journey_service.dart';
import '../../services/activity_state_service.dart';
import '../../widgets/global_header.dart';
import '../../widgets/activity_origin_badge.dart';
import '../../widgets/specialist_contextual_action.dart';
import 'activities/activity_library_screen.dart';
import 'feedback_form.dart';

class JourneyActivityDetailPage extends StatefulWidget {
  final String activityId;
  final String childId;
  final ActivityModel? initialActivity;
  final VoidCallback? onActivityCompleted;

  const JourneyActivityDetailPage({
    super.key,
    required this.activityId,
    required this.childId,
    this.initialActivity,
    this.onActivityCompleted,
  });

  @override
  State<JourneyActivityDetailPage> createState() => _JourneyActivityDetailPageState();
}

class _JourneyActivityDetailPageState extends State<JourneyActivityDetailPage> {
  ActivityModel? _activity;
  bool _isLoading = true;
  bool _isCompleting = false;
  final JourneyService _journeyService = JourneyService();

  @override
  void initState() {
    super.initState();
    if (widget.initialActivity != null) {
      _activity = widget.initialActivity;
      _isLoading = false;
    } else {
      _loadActivity();
    }
  }

  Future<void> _loadActivity() async {
    try {
      // 1. Try authoritative activities collection
      final doc = await FirebaseFirestore.instance
          .collection('activities')
          .doc(widget.activityId)
          .get();

      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _activity = ActivityModel.fromMap(doc.id, doc.data()!);
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Check cached recommendedActivities if activityId is a domain key or custom id
      final domainDoc = await FirebaseFirestore.instance
          .collection('recommendedActivities')
          .doc(widget.childId)
          .collection('domains')
          .doc(widget.activityId.toLowerCase())
          .get();

      if (domainDoc.exists && domainDoc.data() != null) {
        final actData = domainDoc.data()!['activityData'];
        if (actData is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _activity = ActivityModel.fromMap(domainDoc.id, actData);
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 3. Fallback: query activities where skillType matches activityId
      final snap = await FirebaseFirestore.instance
          .collection('activities')
          .where('skillType', isEqualTo: widget.activityId.toLowerCase())
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _activity = ActivityModel.fromMap(snap.docs.first.id, snap.docs.first.data());
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading activity: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onComplete() async {
    if (_activity == null || _isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      // Mark activity as complete in journey and state machine
      await _journeyService.markActivityComplete(
        widget.childId,
        widget.activityId,
        _activity!.skillType,
      );

      try {
        await ActivityStateService().markCompleted(widget.childId);
      } catch (e) {
        debugPrint('Warning: ActivityStateService.markCompleted error: $e');
      }

      if (!mounted) return;

      // Show feedback form and await result
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackForm(
            childId: widget.childId,
            activityId: widget.activityId,
            activityTitle: _activity!.title,
          ),
        ),
      );

      if (!mounted) return;

      if (completed == true) {
        widget.onActivityCompleted?.call();
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
    } catch (e, stack) {
      debugPrint('Error completing activity: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not complete activity: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: GlobalHeader(
          showBack: true,
          title: _activity?.title ?? 'Activity Details',
          onBackTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _activity == null
                ? _buildErrorState()
                : _buildActivityContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Activity Unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We could not load this activity. You can choose another fun activity from the library to continue learning!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivityLibraryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.explore),
                  label: const Text('Browse Library'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Content Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skill badge & Origin badge
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text(
                          _activity!.skillType.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                        backgroundColor: Colors.purple.shade100,
                      ),
                      ActivityOriginBadge(activity: _activity!),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _activity!.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  if (_activity!.shortDescription != null && _activity!.shortDescription!.isNotEmpty) ...[
                    Text(
                      _activity!.shortDescription!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Learning Goals
                  if (_activity!.learningGoals.isNotEmpty) ...[
                    const Text(
                      '🎯 Learning Goals',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ..._activity!.learningGoals.map((goal) => Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                          child: Text('• $goal'),
                        )),
                    const SizedBox(height: 12),
                  ],
                  // Materials
                  if (_activity!.materials.isNotEmpty) ...[
                    const Text(
                      '📦 Materials',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ..._activity!.materials.map((material) => Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                          child: Text('• $material'),
                        )),
                    const SizedBox(height: 12),
                  ],
                  // Instructions
                  if (_activity!.instructions.isNotEmpty) ...[
                    const Text(
                      '📝 Instructions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ..._activity!.instructions.map((inst) => Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                          child: Text('• $inst'),
                        )),
                    const SizedBox(height: 12),
                  ],
                  // Duration
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 18, color: Colors.purple),
                      const SizedBox(width: 6),
                      Text(
                        'Duration: ${_activity!.duration} mins',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Contextual Specialist Support for LLG-recommended activities
          SpecialistContextualAction(
            childId: widget.childId,
            activity: _activity,
          ),
          const SizedBox(height: 16),
          // Complete Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isCompleting ? null : _onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCompleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      '✅ Complete Activity & Give Feedback',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
