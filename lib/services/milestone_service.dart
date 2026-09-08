// lib/services/milestone_service.dart
import '../models/milestone_model.dart';

class MilestoneService {
  // ✅ VABS-II Domain Milestones by Age
  final Map<int, List<MilestoneModel>> _ageMilestones = {
    3: const [
      MilestoneModel(
        id: 'm3_comm',
        title: 'First Sentences',
        description: 'Speaks in 3-4 word sentences',
        domain: 'Communication',
        icon: '🗣️',
        targetAge: 3,
        requiredScore: 60.0,
        skillDomain: 'Language',
      ),
      MilestoneModel(
        id: 'm3_daily',
        title: 'Self-Feeding',
        description: 'Feeds self with spoon independently',
        domain: 'Daily Living',
        icon: '🥄',
        targetAge: 3,
        requiredScore: 50.0,
        skillDomain: 'Motor',
      ),
      MilestoneModel(
        id: 'm3_social',
        title: 'Parallel Play',
        description: 'Plays alongside other children cooperatively',
        domain: 'Socialization',
        icon: '🤝',
        targetAge: 3,
        requiredScore: 50.0,
        skillDomain: 'Social',
      ),
      MilestoneModel(
        id: 'm3_motor',
        title: 'Stair Climber',
        description: 'Walks up stairs with alternating feet',
        domain: 'Motor Skills',
        icon: '🧗',
        targetAge: 3,
        requiredScore: 50.0,
        skillDomain: 'Motor',
      ),
    ],
    4: const [
      MilestoneModel(
        id: 'm4_comm',
        title: 'Curiosity Explorer',
        description: 'Asks "why" and "how" questions',
        domain: 'Communication',
        icon: '❓',
        targetAge: 4,
        requiredScore: 70.0,
        skillDomain: 'Language',
      ),
      MilestoneModel(
        id: 'm4_daily',
        title: 'Independent Dresser',
        description: 'Puts on shoes and simple clothing',
        domain: 'Daily Living',
        icon: '👟',
        targetAge: 4,
        requiredScore: 60.0,
        skillDomain: 'Motor',
      ),
      MilestoneModel(
        id: 'm4_social',
        title: 'Sharing Skills',
        description: 'Shares toys with peers during play',
        domain: 'Socialization',
        icon: '🧸',
        targetAge: 4,
        requiredScore: 60.0,
        skillDomain: 'Social',
      ),
      MilestoneModel(
        id: 'm4_motor',
        title: 'Hopper',
        description: 'Hops on one foot with balance',
        domain: 'Motor Skills',
        icon: '🦘',
        targetAge: 4,
        requiredScore: 65.0,
        skillDomain: 'Motor',
      ),
    ],
    5: const [
      MilestoneModel(
        id: 'm5_comm',
        title: 'Storyteller',
        description: 'Tells simple stories and describes daily events',
        domain: 'Communication',
        icon: '📖',
        targetAge: 5,
        requiredScore: 80.0,
        skillDomain: 'Language',
      ),
      MilestoneModel(
        id: 'm5_daily',
        title: 'Tooth Brusher',
        description: 'Brushes teeth independently',
        domain: 'Daily Living',
        icon: '🪥',
        targetAge: 5,
        requiredScore: 70.0,
        skillDomain: 'Motor',
      ),
      MilestoneModel(
        id: 'm5_social',
        title: 'Turn-Taker',
        description: 'Takes turns gracefully in group games',
        domain: 'Socialization',
        icon: '🎲',
        targetAge: 5,
        requiredScore: 70.0,
        skillDomain: 'Social',
      ),
      MilestoneModel(
        id: 'm5_motor',
        title: 'Ball Catcher',
        description: 'Catches a bounced ball with two hands',
        domain: 'Motor Skills',
        icon: '⚽',
        targetAge: 5,
        requiredScore: 75.0,
        skillDomain: 'Motor',
      ),
    ],
    6: const [
      MilestoneModel(
        id: 'm6_comm',
        title: 'Early Reader',
        description: 'Reads simple words and sight words',
        domain: 'Communication',
        icon: '📚',
        targetAge: 6,
        requiredScore: 85.0,
        skillDomain: 'Language',
      ),
      MilestoneModel(
        id: 'm6_daily',
        title: 'Independent Dresser',
        description: 'Fastens buttons, snaps, and zippers',
        domain: 'Daily Living',
        icon: '🧥',
        targetAge: 6,
        requiredScore: 80.0,
        skillDomain: 'Motor',
      ),
      MilestoneModel(
        id: 'm6_social',
        title: 'Friend Maker',
        description: 'Makes and maintains friendships with peers',
        domain: 'Socialization',
        icon: '👫',
        targetAge: 6,
        requiredScore: 80.0,
        skillDomain: 'Social',
      ),
      MilestoneModel(
        id: 'm6_motor',
        title: 'Bike Rider',
        description: 'Rides a bicycle or balance bike smoothly',
        domain: 'Motor Skills',
        icon: '🚲',
        targetAge: 6,
        requiredScore: 85.0,
        skillDomain: 'Motor',
      ),
    ],
  };

  // ✅ Get Milestones for Age (defaults to age 3 or closest bracket)
  List<MilestoneModel> getMilestonesForAge(int age) {
    final clampedAge = age.clamp(3, 6);
    return _ageMilestones[clampedAge] ?? _ageMilestones[3]!;
  }

  // ✅ Check if Milestone is Achieved based on child's skill scores
  bool isMilestoneAchieved(Map<String, double> skills, MilestoneModel milestone) {
    final currentScore = skills[milestone.skillDomain] ?? 0.0;
    return currentScore >= milestone.requiredScore;
  }
}
