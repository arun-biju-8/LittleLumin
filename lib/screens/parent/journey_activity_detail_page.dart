import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity_model.dart';
import '../../services/journey_service.dart';
import 'feedback_form.dart';

class JourneyActivityDetailPage extends StatefulWidget {
  final String activityId;
  final String childId;
  final VoidCallback? onActivityCompleted;

  const JourneyActivityDetailPage({
    super.key,
    required this.activityId,
    required this.childId,
    this.onActivityCompleted,
  });

  @override
  State<JourneyActivityDetailPage> createState() => _JourneyActivityDetailPageState();
}

class _JourneyActivityDetailPageState extends State<JourneyActivityDetailPage> {
  ActivityModel? _activity;
  bool _isLoading = true;
  final JourneyService _journeyService = JourneyService();

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('activities')
          .doc(widget.activityId)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _activity = ActivityModel.fromMap(doc.id, doc.data()!);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity not found')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading activity: $e');
    }
  }

  void _onComplete() async {
    if (_activity == null) return;

    // Mark activity as complete in journey
    await _journeyService.markActivityComplete(
      widget.childId,
      widget.activityId,
      _activity!.skillType,
    );

    if (!mounted) return;

    // Show feedback form
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackForm(
          childId: widget.childId,
          activityId: widget.activityId,
          activityTitle: _activity!.title,
        ),
      ),
    ).then((_) {
      widget.onActivityCompleted?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Not Found')),
        body: const Center(child: Text('This activity could not be loaded.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_activity!.title),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                    // Skill badge
                    Chip(
                      label: Text(
                        _activity!.skillType.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                      backgroundColor: Colors.purple.shade100,
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
            const SizedBox(height: 24),
            // Complete Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '✅ Complete Activity & Give Feedback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
