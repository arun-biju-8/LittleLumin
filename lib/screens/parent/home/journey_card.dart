import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../services/journey_service.dart';
import '../parent_theme.dart';

class JourneyCard extends StatelessWidget {
  final ChildModel child;
  final VoidCallback onContinueJourney;

  const JourneyCard({
    super.key,
    required this.child,
    required this.onContinueJourney,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JourneyProgress?>(
      stream: JourneyService().getJourneyProgress(child.childId),
      builder: (context, snapshot) {
        final journey = snapshot.data;
        final level = journey?.currentLevel ?? 1;
        final lvlProg = journey?.currentLevelProgress ?? LevelProgress(completed: []);

        final completedCount = lvlProg.completed.length;
        final totalCount = lvlProg.total > 0 ? lvlProg.total : 6;
        final progressFraction = (completedCount / totalCount).clamp(0.0, 1.0);
        final percent = (progressFraction * 100).round();

        const defaultDomains = [
          'Cognitive',
          'Language',
          'Motor',
          'Social',
          'Emotional',
          'Creative',
        ];

        String nextDomain = 'Level Completed! 🏆';
        for (final domain in defaultDomains) {
          if (!lvlProg.completed.contains(domain)) {
            nextDomain = domain;
            break;
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: ParentColors.primaryGradient,
            borderRadius: ParentRadius.card,
            boxShadow: ParentShadows.gradient,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Caption & Level badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('📈', style: TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'JOURNEY PROGRESS',
                        style: ParentTypography.caption.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: ParentRadius.chip,
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Level $level',
                      style: ParentTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Level & skills completed with percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level $level · $completedCount/$totalCount skills',
                    style: ParentTypography.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ParentColors.accent.withOpacity(0.25),
                      borderRadius: ParentRadius.chip,
                    ),
                    child: Text(
                      '$percent%',
                      style: ParentTypography.caption.copyWith(
                        color: ParentColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Enhanced Progress Bar with gradient & rounded edges
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: ParentRadius.chip,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressFraction > 0 ? progressFraction : 0.02,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ParentColors.accent, Color(0xFFFDE68A)],
                      ),
                      borderRadius: ParentRadius.chip,
                      boxShadow: [
                        BoxShadow(
                          color: ParentColors.accent.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Next Domain chip
              Row(
                children: [
                  Text(
                    'Next: ',
                    style: ParentTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      nextDomain,
                      style: ParentTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Full-width Continue Journey button (56px) with tap animation
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onContinueJourney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ParentColors.primary,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ParentRadius.button,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue Journey',
                        style: ParentTypography.button.copyWith(
                          color: ParentColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: ParentColors.primary,
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveX(begin: 0, end: 4, duration: 800.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
