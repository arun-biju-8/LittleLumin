// lib/screens/llg/llg_landing_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/background_shapes.dart';
import '../../widgets/logo_widget.dart';
import 'llg_signup_page.dart';
import '../auth/login_page.dart';

class LLGLandingPage extends StatefulWidget {
  const LLGLandingPage({super.key});

  @override
  State<LLGLandingPage> createState() => _LLGLandingPageState();
}

class _LLGLandingPageState extends State<LLGLandingPage> {
  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LLGSignUpPage()),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
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

          // Background floating shapes
          const BackgroundShapes(animated: true),

          // Scrollable Landing Page Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // HEADER NAVIGATION
                  _buildHeader(isDesktop),

                  // 1. HERO SECTION
                  _buildHeroSection(isDesktop),

                  const SizedBox(height: 40),

                  // 2. WHO IS AN LLG SECTION
                  _buildWhoIsLLGSection(isDesktop),

                  const SizedBox(height: 40),

                  // 3. LLG RESPONSIBILITIES (4 CARDS)
                  _buildResponsibilitiesSection(isDesktop),

                  const SizedBox(height: 40),

                  // 4. REQUIREMENTS TO BECOME AN LLG
                  _buildRequirementsSection(isDesktop),

                  const SizedBox(height: 40),

                  // 5. HOW TO APPLY (3 STEPS)
                  _buildHowToApplySection(isDesktop),

                  const SizedBox(height: 40),

                  // 6. POLICIES & CODE OF CONDUCT
                  _buildPoliciesSection(isDesktop),

                  const SizedBox(height: 40),

                  // 7. CALL TO ACTION SECTION
                  _buildCtaSection(isDesktop),

                  const SizedBox(height: 40),

                  // FOOTER
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HEADER NAVIGATION
  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 16.0,
        vertical: isDesktop ? 20.0 : 12.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo
          Row(
            children: [
              const LogoWidget(size: LogoSize.sm, animated: false),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LittleLumin Guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 22 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'LLG Professional Portal',
                    style: TextStyle(
                      color: AppTheme.amberGold.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action Buttons
          Row(
            children: [
              TextButton(
                onPressed: _navigateToLogin,
                child: const Text(
                  'Guide Login',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _navigateToSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amberGold,
                  foregroundColor: AppTheme.darkSlate,
                  elevation: 4,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 14,
                    vertical: isDesktop ? 14 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Apply Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // HERO SECTION
  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0, vertical: 20),
      padding: EdgeInsets.all(isDesktop ? 48.0 : 24.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.amberGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.amberGold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: AppTheme.amberGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Join the LittleLumin Guide Network',
                  style: TextStyle(
                    color: AppTheme.amberGold,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Empower Parents.\nGuide Early Childhood Development.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 42 : 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'Become a verified LittleLumin Guide (LLG) to deliver evidence-based early childhood guidance, monitor development milestones, and support parents with compassionate expertise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: isDesktop ? 16 : 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _navigateToSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amberGold,
              foregroundColor: AppTheme.darkSlate,
              elevation: 8,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 36 : 24,
                vertical: isDesktop ? 18 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.badge_rounded),
            label: const Text(
              'Apply to Become an LLG',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  // WHO IS AN LLG SECTION
  Widget _buildWhoIsLLGSection(bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0),
      child: Column(
        children: [
          const Text(
            'Who Is a LittleLumin Guide (LLG)?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              'A LittleLumin Guide (LLG) is a verified early childhood specialist, educator, counselor, or pediatrician who collaborates with parents to nurture developmental growth, review flagged milestones, and recommend tailored screen-free activities.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // LLG RESPONSIBILITIES (4 CARDS)
  Widget _buildResponsibilitiesSection(bool isDesktop) {
    final responsibilities = [
      {
        'icon': Icons.insights_rounded,
        'title': 'Milestone Analysis',
        'desc': 'Review child milestone progress and identify areas needing positive encouragement or extra guidance.',
      },
      {
        'icon': Icons.auto_stories_rounded,
        'title': 'Tailored Recommendations',
        'desc': 'Suggest customized, screen-free developmental activities designed for children aged 3 to 6.',
      },
      {
        'icon': Icons.family_restroom_rounded,
        'title': 'Parent Consultation',
        'desc': 'Offer online or in-person advisory support to empower parents with practical behavioral strategies.',
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Ethical Safeguarding',
        'desc': 'Maintain strict confidentiality and follow professional code of conduct standards at all times.',
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0),
      child: Column(
        children: [
          const Text(
            'Core LLG Responsibilities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: responsibilities.map((item) {
              return Container(
                width: isDesktop ? 260 : double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.amberGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: AppTheme.amberGold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['desc'] as String,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // REQUIREMENTS TO BECOME AN LLG
  Widget _buildRequirementsSection(bool isDesktop) {
    final reqs = [
      'Recognized degree or certification in Early Childhood Education, Child Psychology, or related field.',
      'Active professional license or verified institutional affiliation.',
      'Minimum 2+ years of hands-on experience supporting young children and families.',
      'Commitment to LittleLumin screen-free, evidence-based developmental principles.',
      'Clear background verification and compliance with child safety policies.',
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.darkSlate.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.amberGold, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Requirements to Become an LLG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: reqs.map((req) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.amberGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        req,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // HOW TO APPLY (3 STEPS)
  Widget _buildHowToApplySection(bool isDesktop) {
    final steps = [
      {
        'step': '01',
        'title': 'Submit Professional Form',
        'desc': 'Fill out your contact, qualification, license, and specialization details in the application form.',
      },
      {
        'step': '02',
        'title': 'Admin Verification',
        'desc': 'Our administrator team reviews your credentials and verifies your professional status.',
      },
      {
        'step': '03',
        'title': 'Start Guiding Parents',
        'desc': 'Once approved, log into your LLG Dashboard to send recommendations and assist parents.',
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0),
      child: Column(
        children: [
          const Text(
            'How to Apply (3 Easy Steps)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: steps.map((item) {
              return Container(
                width: isDesktop ? 260 : double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.amberGold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['step'] as String,
                      style: const TextStyle(
                        color: AppTheme.amberGold,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['desc'] as String,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // POLICIES & CODE OF CONDUCT
  Widget _buildPoliciesSection(bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: AppTheme.amberGold, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Policies & Code of Conduct',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All LittleLumin Guides operate strictly through parent-facing consultations. No direct contact with children is permitted. All guidance must be non-diagnostic, supportive, and privacy-compliant.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CALL TO ACTION SECTION
  Widget _buildCtaSection(bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0),
      padding: EdgeInsets.all(isDesktop ? 40 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.amberGold.withValues(alpha: 0.9),
            AppTheme.amberGold,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.amberGold.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Make a Difference for Growing Families?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkSlate,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Complete your application today and join our network of verified early childhood guides.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkSlate,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkSlate,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Apply Now as an LLG Guide',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // FOOTER
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Text(
            'LittleLumin Guide Network • Professional Verification Portal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© LittleLumin Platform. All Rights Reserved.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
