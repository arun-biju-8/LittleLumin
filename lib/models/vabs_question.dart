// lib/models/vabs_question.dart

class VABSDomain {
  static const communication = 'communication';
  static const dailyLiving = 'daily_living';
  static const socialization = 'socialization';
  static const motor = 'motor';

  static String getDisplayName(String domainKey) {
    switch (domainKey.toLowerCase()) {
      case 'communication':
        return 'Communication';
      case 'daily_living':
      case 'dailyliving':
        return 'Daily Living Skills';
      case 'socialization':
        return 'Socialization';
      case 'motor':
        return 'Motor Skills';
      default:
        return 'Developmental Domain';
    }
  }
}

class VABSQuestion {
  final String id;
  final String domain;
  final String question;
  final List<String> options;
  final List<int> scores;

  VABSQuestion({
    required this.id,
    required this.domain,
    required this.question,
    this.options = const ['Never (0)', 'Sometimes (1)', 'Often (2)', 'Always (3)'],
    this.scores = const [0, 1, 2, 3],
  });

  static List<VABSQuestion> get defaultQuestions => [
        // Communication (4 questions)
        VABSQuestion(
          id: 'c1',
          domain: VABSDomain.communication,
          question: '1. Expresses wants and needs clearly using words or gestures.',
        ),
        VABSQuestion(
          id: 'c2',
          domain: VABSDomain.communication,
          question: '2. Follows simple two-step instructions (e.g., "get your shoes and bring them here").',
        ),
        VABSQuestion(
          id: 'c3',
          domain: VABSDomain.communication,
          question: '3. Listens attentively to stories or conversation for 5+ minutes.',
        ),
        VABSQuestion(
          id: 'c4',
          domain: VABSDomain.communication,
          question: '4. Asks simple "who", "what", or "where" questions to gain information.',
        ),

        // Daily Living Skills (4 questions)
        VABSQuestion(
          id: 'd1',
          domain: VABSDomain.dailyLiving,
          question: '5. Feeds self independently using utensils with minimal spills.',
        ),
        VABSQuestion(
          id: 'd2',
          domain: VABSDomain.dailyLiving,
          question: '6. Signals need to use the restroom or handles hygiene independently.',
        ),
        VABSQuestion(
          id: 'd3',
          domain: VABSDomain.dailyLiving,
          question: '7. Assists or dresses self independently (e.g., pulling up pants, shoes).',
        ),
        VABSQuestion(
          id: 'd4',
          domain: VABSDomain.dailyLiving,
          question: '8. Helps clean up toys or put away items when prompted.',
        ),

        // Socialization (4 questions)
        VABSQuestion(
          id: 's1',
          domain: VABSDomain.socialization,
          question: '9. Shares toys and engages in turn-taking play with peers.',
        ),
        VABSQuestion(
          id: 's2',
          domain: VABSDomain.socialization,
          question: '10. Shows empathy or comforting behavior when others are upset.',
        ),
        VABSQuestion(
          id: 's3',
          domain: VABSDomain.socialization,
          question: '11. Greets familiar peers and adults appropriately.',
        ),
        VABSQuestion(
          id: 's4',
          domain: VABSDomain.socialization,
          question: '12. Adjusts to changes in routine without severe distress.',
        ),

        // Motor Skills (3 questions)
        VABSQuestion(
          id: 'm1',
          domain: VABSDomain.motor,
          question: '13. Runs, jumps, and navigates obstacles with steady balance.',
        ),
        VABSQuestion(
          id: 'm2',
          domain: VABSDomain.motor,
          question: '14. Grasps crayons or pencils to draw, color, or scribble.',
        ),
        VABSQuestion(
          id: 'm3',
          domain: VABSDomain.motor,
          question: '15. Climbs stairs up and down safely with alternating feet or support.',
        ),
      ];
}
