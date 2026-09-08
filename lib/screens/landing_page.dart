// At the top of landing_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/background_shapes.dart';
import '../widgets/logo_widget.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/signup_page.dart';
import 'llg/llg_landing_page.dart';
import '../screens/auth/splash_screen.dart';

class LandingPageWidget extends StatefulWidget {
  const LandingPageWidget({super.key});

  @override
  State<LandingPageWidget> createState() => _LandingPageWidgetState();
}

class _LandingPageWidgetState extends State<LandingPageWidget> {
  String _selectedAge = '3';

  // Developmental Insights Data
  final Map<String, Map<String, dynamic>> _ageInsights = {
    '3': {
      'title': 'Social Sparks & Emotional Foundations',
      'description':
          'At 3 years old, children are discovering their feelings and exploring simple social interactions through parallel and cooperative play.',
      'tips': [
        'Practice naming feelings aloud: "It looks like you feel excited about building that tower!"',
        'Offer simple two-choice options to help build healthy decision-making skills.',
        'Create a calm, predictable 15-minute routine before bedtime to transition peacefully.',
      ],
    },
    '4': {
      'title': 'Curiosity, Words & Imaginative Play',
      'description':
          '4-year-olds ask endless "why" questions and use creative imaginative play to understand how the world works around them.',
      'tips': [
        'Encourage open-ended curiosity by asking: "What do you think will happen next?"',
        'Validate creative storytelling and play-pretend without correcting imaginative details.',
        'Practice simple turn-taking games that build patience and empathy with peers.',
      ],
    },
    '5': {
      'title': 'Pre-School Confidence & Problem Solving',
      'description':
          '5-year-olds gain motor confidence, early pre-reading curiosity, and stronger emotional self-soothing strategies.',
      'tips': [
        'Introduce "5 Finger Breathing" as a simple sensory exercise when feeling overwhelmed.',
        'Praise effort and persistence rather than just the final outcome.',
        'Involve your child in fun family micro-chores to build a sense of pride and capability.',
      ],
    },
    '6': {
      'title': 'School Transition & Executive Functioning',
      'description':
          '6-year-olds navigate early school routines, deepening friendships, and multi-step executive planning skills.',
      'tips': [
        'Use simple visual morning routines (shoes, bag, teeth) to foster daily morning autonomy.',
        'Share a daily dinner reflection: "What was something kind or funny that happened today?"',
        'Help break larger challenges into three clear, manageable steps together.',
      ],
    },
  };

  void _openSplashDemo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SplashScreenWidget(
          progress: 0.0,
          onComplete: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // When user clicks "Get Started" or "Create Account"
  void _openGetStartedDialog({bool isCreateAccount = false}) {
    if (isCreateAccount) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignUpPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _openInfoDialog({
    required String title,
    required String content,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.slateBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(icon, color: AppTheme.amberGold, size: 24),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppTheme.amberGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Animated Gradient Canvas
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppTheme.mainGradient),
          ),

          // Floating Geometric Shapes Background
          const BackgroundShapes(animated: true),

          // Main Scrollable Page Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // HEADER NAVIGATION
                  _buildHeader(isDesktop),

                  // SECTION 1: HERO
                  _buildHeroSection(isDesktop),

                  const SizedBox(height: 40),

                  // SECTION 2: EMPOWERING PARENTS
                  _buildEmpoweringSection(isDesktop),

                  const SizedBox(height: 40),

                  // SECTION 3: HOW LITTLELUMIN SUPPORTS YOU
                  _buildPillarsSection(isDesktop),

                  const SizedBox(height: 40),

                  // SECTION 4: STAGE EXPLORER (AGES 3-6)
                  _buildStageExplorerSection(isDesktop),

                  const SizedBox(height: 40),

                  // SECTION 5: CALL TO ACTION BANNER
                  _buildCtaSection(isDesktop),

                  const SizedBox(height: 40),

                  // SECTION 6: FOOTER
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 // HEADER WIDGET — Complete Professional Version
Widget _buildHeader(bool isDesktop) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isDesktop ? 48.0 : 16.0,
      vertical: isDesktop ? 20.0 : 12.0,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo & Brand Name
        Row(
          children: [
            const LogoWidget(size: LogoSize.sm, animated: false),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '    LittleLumin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 24 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isDesktop)
                  const Text(
                    'Growing Children, Growing Parents',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // ✅ Professional Header Actions
        isDesktop
            ? _buildDesktopActions()
            : _buildMobileActions(),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut);
}

// ✅ Professional Desktop Header Actions
Widget _buildDesktopActions() {
  return Row(
    children: [
      OutlinedButton(
        onPressed: () => _openGetStartedDialog(isCreateAccount: true),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
        child: const Text(
          'Create Account',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 12),
      ElevatedButton(
        onPressed: () => _openGetStartedDialog(isCreateAccount: false),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.amberGold,
          foregroundColor: AppTheme.darkSlate,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
        child: const Row(
          children: [
            Text(
              'Get Started',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    ],
  );
}

// ✅ Professional Mobile Header Actions
Widget _buildMobileActions() {
  return Row(
    children: [
      // "Get Started" button
      ElevatedButton(
        onPressed: () => _openGetStartedDialog(isCreateAccount: false),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.amberGold,
          foregroundColor: AppTheme.darkSlate,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          minimumSize: const Size(0, 38),
        ),
        child: const Text(
          'Get Started',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(width: 8),
      // Icon button for Create Account
      IconButton(
        onPressed: () => _openGetStartedDialog(isCreateAccount: true),
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
          color: Colors.white,
          size: 24,
        ),
        tooltip: 'Create Account',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ],
  );
}
  // HERO SECTION
  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1280),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 20.0,
        vertical: isDesktop ? 40.0 : 20.0,
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Content
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Column(
              crossAxisAlignment: isDesktop
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                // AI Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: AppTheme.glassBox(
                    opacity: 0.15,
                    borderOpacity: 0.3,
                    borderRadius: 30,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppTheme.amberGold,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AI-Powered Parenting Guidance Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tagline
                const Text(
                  'GROWING CHILDREN, GROWING PARENTS',
                  style: TextStyle(
                    color: AppTheme.lightAmber,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Headline
                Text(
                  'Personalized, Screen-Free Guidance for Your Child\'s Journey',
                  textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 48 : 32,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Subhead
                Text(
                  'Personalized, screen-free, and AI-driven support for your child\'s developmental journey.',
                  textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                // Hero Buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: isDesktop
                      ? WrapAlignment.start
                      : WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _openGetStartedDialog(isCreateAccount: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amberGold,
                        foregroundColor: AppTheme.darkSlate,
                        elevation: 8,
                        shadowColor: Colors.black45,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 18,
                        ),
                      ),
                      icon: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      label: const Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _openGetStartedDialog(isCreateAccount: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 18,
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Trust Badges
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  alignment: isDesktop
                      ? WrapAlignment.start
                      : WrapAlignment.center,
                  children: const [
                    _TrustItem(text: '100% Screen-Free for Kids'),
                    _TrustItem(text: 'Gentle & Science-Backed'),
                    _TrustItem(text: 'Tailored for Ages 3-6'),
                  ],
                ),
              ],
            ),
          ),

          if (!isDesktop) const SizedBox(height: 40),

          // Right Hero Card Visual
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.glassBox(
                opacity: 0.15,
                borderOpacity: 0.25,
                borderRadius: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoWidget(size: LogoSize.xl, animated: true),
                  const SizedBox(height: 20),
                  const Text(
                    'LittleLumin Companion',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Empowering parents with real-time AI stage suggestions, milestone trackers, and positive routines.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openSplashDemo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: AppTheme.amberGold,
                      ),
                      label: const Text(
                        'To be used by T87',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut);
  }

  // SECTION 2: EMPOWERING PARENTS
  Widget _buildEmpoweringSection(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1280),
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 20.0),
      padding: EdgeInsets.all(isDesktop ? 48.0 : 24.0),
      decoration: AppTheme.glassBox(
        opacity: 0.10,
        borderOpacity: 0.2,
        borderRadius: 32,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: AppTheme.glassBox(opacity: 0.15, borderRadius: 20),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: AppTheme.amberGold,
                ),
                SizedBox(width: 6),
                Text(
                  'SUPPORTIVE & POSITIVE FOCUS',
                  style: TextStyle(
                    color: AppTheme.lightAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Parenting Is a Journey — We\'re Here to Help',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'LittleLumin gives you the tools, insights, and confidence to support your child\'s unique growth.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 36),

          // 3 Grid Cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 768) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildPointCard(
                        Icons.sentiment_satisfied_alt_rounded,
                        'Celebrate Every Pace',
                        'Every child develops at their own pace — we help you understand and celebrate that journey.',
                        AppTheme.amberGold,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPointCard(
                        Icons.verified_user_rounded,
                        'Build Confidence',
                        'You already have what it takes to be a great parent. We just help you feel more confident and prepared.',
                        AppTheme.lightAmber,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPointCard(
                        Icons.auto_awesome_rounded,
                        'Zero Guilt & Pressure',
                        'No guilt, no pressure — just gentle, science-backed guidance that fits into your daily life.',
                        AppTheme.amberGold,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildPointCard(
                      Icons.sentiment_satisfied_alt_rounded,
                      'Celebrate Every Pace',
                      'Every child develops at their own pace — we help you understand and celebrate that journey.',
                      AppTheme.amberGold,
                    ),
                    const SizedBox(height: 16),
                    _buildPointCard(
                      Icons.verified_user_rounded,
                      'Build Confidence',
                      'You already have what it takes to be a great parent. We just help you feel more confident and prepared.',
                      AppTheme.lightAmber,
                    ),
                    const SizedBox(height: 16),
                    _buildPointCard(
                      Icons.auto_awesome_rounded,
                      'Zero Guilt & Pressure',
                      'No guilt, no pressure — just gentle, science-backed guidance that fits into your daily life.',
                      AppTheme.amberGold,
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _buildPointCard(
    IconData icon,
    String title,
    String desc,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassBox(
        opacity: 0.10,
        borderOpacity: 0.15,
        borderRadius: 20,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // SECTION 3: PILLARS
  Widget _buildPillarsSection(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1280),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 20.0),
      child: Column(
        children: [
          const Text(
            'CORE PLATFORM PILLARS',
            style: TextStyle(
              color: AppTheme.lightAmber,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How LittleLumin Supports You',
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: isDesktop ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: isDesktop ? 2.6 : 2.2,
            children: [
              _buildPillarCard(
                Icons.tv_rounded,
                'Screen-Free Learning',
                'Every activity is parent-guided. Zero screen time for your child.',
              ),
              _buildPillarCard(
                Icons.psychology_rounded,
                'AI-Powered Personalization',
                'Activities adapt to your child\'s unique developmental pace.',
              ),
              _buildPillarCard(
                Icons.trending_up_rounded,
                'Parent Growth Companion',
                'We support you too — track your parenting confidence.',
              ),
              _buildPillarCard(
                Icons.bar_chart_rounded,
                'Progress Tracking',
                'Monitor your child\'s growth across 6 developmental domains.',
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _buildPillarCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassBox(
        opacity: 0.12,
        borderOpacity: 0.2,
        borderRadius: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.amberGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.amberGold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SECTION 4: STAGE EXPLORER
  Widget _buildStageExplorerSection(bool isDesktop) {
    final insights = _ageInsights[_selectedAge]!;

    return Container(
      constraints: const BoxConstraints(maxWidth: 1280),
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 20.0),
      padding: EdgeInsets.all(isDesktop ? 40.0 : 24.0),
      decoration: BoxDecoration(
        color: AppTheme.darkSlate.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text(
            'STAGE EXPLORER (AGES 3-6)',
            style: TextStyle(
              color: AppTheme.amberGold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Understanding Your Child\'s Growth',
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore general developmental milestones and parenting insights for children aged 3-6',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 28),

          // Age Selector Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['3', '4', '5', '6'].map((age) {
              final isSelected = _selectedAge == age;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: ChoiceChip(
                  label: Text(
                    '$age Yrs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.darkSlate : const Color.fromARGB(255, 67, 67, 67),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.amberGold,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedAge = age);
                  },
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Age Insights Card Container
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Container(
              key: ValueKey(_selectedAge),
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.glassBox(
                opacity: 0.1,
                borderOpacity: 0.15,
                borderRadius: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STAGE THEME',
                    style: TextStyle(
                      color: AppTheme.amberGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insights['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insights['description'],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'KEY STAGE INSIGHTS & TIPS:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(insights['tips'] as List<String>).asMap().entries.map((
                    entry,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassBox(
                          opacity: 0.08,
                          borderOpacity: 0.1,
                          borderRadius: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.amberGold,
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: AppTheme.darkSlate,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'These are general developmental guidelines. Every child develops at their own pace.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  // SECTION 5: CTA BANNER
  Widget _buildCtaSection(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 20.0),
      padding: EdgeInsets.all(isDesktop ? 48.0 : 28.0),
      decoration: AppTheme.glassBox(
        opacity: 0.15,
        borderOpacity: 0.25,
        borderRadius: 32,
      ),
      child: Column(
        children: [
          Text(
            'Ready to Start Your Journey?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 40 : 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Join thousands of parents raising confident children',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _openGetStartedDialog(isCreateAccount: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amberGold,
              foregroundColor: AppTheme.darkSlate,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
            ),
            icon: const Text(
              'Get Started Now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            label: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  // SECTION 6: FOOTER
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Text(
            'Growing Children, Growing Parents • LittleLumin Platform',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openInfoDialog(
                  title: 'Privacy Policy',
                  icon: Icons.lock_rounded,
                  content:
                      'At LittleLumin, we prioritize family privacy above all else. Our AI-powered parenting platform is designed with zero child screen-time and strict data protection standards.\n\n1. Parent First: All interactions occur solely through the parent\'s interface.\n2. Data Encryption: Personal notes and developmental milestone observations are encrypted securely.\n3. Encouraging Focus: We provide positive, supportive developmental guidance backed by early childhood research.',
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('•', style: TextStyle(color: Colors.white54)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _openInfoDialog(
                  title: 'Terms of Service',
                  icon: Icons.description_rounded,
                  content:
                      'Welcome to LittleLumin! By using our platform, you agree to our terms. LittleLumin provides stage-based educational suggestions for parents. Our recommendations are for informational and developmental support, not a replacement for professional pediatric advice.',
                ),
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('•', style: TextStyle(color: Colors.white54)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LLGLandingPage()),
                  );
                },
                child: const Text(
                  'Are you a professional? Become an LLG Guide',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// HELPER TRUST ITEM
class _TrustItem extends StatelessWidget {
  final String text;
  const _TrustItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: AppTheme.amberGold,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ACCOUNT / GET STARTED DIALOG
class _AccountFormDialog extends StatefulWidget {
  final bool isCreateAccount;
  const _AccountFormDialog({required this.isCreateAccount});

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.slateBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 420),
        child: _submitted
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Welcome to LittleLumin!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your stage guidance companion is ready.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            LogoWidget(size: LogoSize.sm, animated: false),
                            SizedBox(width: 8),
                            Text(
                              'LittleLumin',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isCreateAccount
                          ? 'Create Your Account'
                          : 'Start Your Free Trial',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Positive, screen-free AI guidance tailored for your child.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: _inputDeco('Parent\'s Name'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: _inputDeco('Child\'s Name (Optional)'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: _inputDeco('Email Address'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      validator: (val) => val == null || !val.contains('@')
                          ? 'Please enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _submitted = true);
                            final navigator = Navigator.of(context);
                            Future.delayed(
                              const Duration(milliseconds: 1200),
                              () {
                                if (mounted) navigator.pop();
                              },
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.amberGold,
                          foregroundColor: AppTheme.darkSlate,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Continue to App',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.amberGold),
      ),
    );
  }
}
