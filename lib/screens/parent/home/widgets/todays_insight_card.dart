// lib/screens/parent/home/widgets/todays_insight_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../theme/meadow_theme.dart';

class TodaysInsightCard extends StatefulWidget {
  final Future<String>? tipFuture;

  const TodaysInsightCard({
    super.key,
    this.tipFuture,
  });

  @override
  State<TodaysInsightCard> createState() => _TodaysInsightCardState();
}

class _TodaysInsightCardState extends State<TodaysInsightCard> {
  late Future<String> _future;

  static const List<String> _fallbackTips = [
    'Praise effort, not just outcome. It builds a growth mindset.',
    'Every child develops at their own pace. Celebrate small wins!',
    'Reading together for just 10 minutes a day builds vocabulary and emotional connection.',
    'Turn everyday chores into playful learning games.',
    'Allow space for unstructured play — it sparks imagination and self-regulation.',
    'When your child feels big feelings, name the emotion to help them tame it.',
    'Ask open-ended questions like "What was the most surprising part of your day?"',
    'Model curiosity. Saying "I wonder why that happens, let us find out!" inspires lifelong learning.',
    'Small, repeated daily moments of warm connection matter more than perfect milestones.',
    'Listen actively when they speak — it teaches empathy and self-worth.',
  ];

  @override
  void initState() {
    super.initState();
    _loadTip();
  }

  @override
  void didUpdateWidget(covariant TodaysInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tipFuture != widget.tipFuture) {
      _loadTip();
    }
  }

  void _loadTip() {
    if (widget.tipFuture != null) {
      _future = widget.tipFuture!;
      return;
    }
    _future = _fetchDailyTip();
  }

  Future<String> _fetchDailyTip() async {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    try {
      final snapshot = await FirebaseFirestore.instance.collection('tips').get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs[dayOfYear % snapshot.docs.length];
        final text = (doc.data()['message'] ?? doc.data()['tip'] ?? '').toString();
        if (text.trim().isNotEmpty) return text.trim();
      }
    } catch (_) {
      // Fall through to hardcoded fallback
    }

    return _fallbackTips[dayOfYear % _fallbackTips.length];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        final tip = snapshot.data ?? _fallbackTips[0];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: MeadowColors.goldSurface,
            borderRadius: BorderRadius.circular(MeadowRadius.lg),
            border: Border.all(
              color: MeadowColors.goldLight.withOpacity(0.7),
              width: 1.0,
            ),
            boxShadow: MeadowShadows.soft,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'TODAY\'S INSIGHT',
                    style: MeadowTypography.caption.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '"$tip"',
                style: MeadowTypography.bodyLarge.copyWith(
                  fontStyle: FontStyle.italic,
                  color: MeadowColors.textPrimary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
