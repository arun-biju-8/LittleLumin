// lib/screens/llg/llg_signup_page.dart
import 'package:flutter/material.dart';
import '../../services/llg_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/background_shapes.dart';
import '../../widgets/logo_widget.dart';
import '../auth/login_page.dart';

class LLGSignUpPage extends StatefulWidget {
  const LLGSignUpPage({super.key});

  @override
  State<LLGSignUpPage> createState() => _LLGSignUpPageState();
}

class _LLGSignUpPageState extends State<LLGSignUpPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers - Account & Personal
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Controllers - Professional
  final _qualificationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specializationController = TextEditingController();
  final _organizationController = TextEditingController();
  final _bioController = TextEditingController();
  final _regionController = TextEditingController();
  final _languagesController = TextEditingController();

  // Controllers - Certificate Links
  final _qualificationCertificateController = TextEditingController();
  final _licenseCertificateController = TextEditingController();
  final _experienceCertificateController = TextEditingController();
  final _identityProofController = TextEditingController();
  final _associationController = TextEditingController();

  String _consultationMode = 'Online & In-Person';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _qualificationController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _specializationController.dispose();
    _organizationController.dispose();
    _bioController.dispose();
    _regionController.dispose();
    _languagesController.dispose();
    _qualificationCertificateController.dispose();
    _licenseCertificateController.dispose();
    _experienceCertificateController.dispose();
    _identityProofController.dispose();
    _associationController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final llgService = LLGService();
      await llgService.submitLLGApplication(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        qualification: _qualificationController.text.trim(),
        license: _licenseController.text.trim(),
        experience: _experienceController.text.trim(),
        specialization: _specializationController.text.trim(),
        organization: _organizationController.text.trim(),
        bio: _bioController.text.trim(),
        region: _regionController.text.trim(),
        languages: _languagesController.text.trim(),
        consultationMode: _consultationMode,
        qualificationCertificateLink: _qualificationCertificateController.text.trim(),
        licenseCertificateLink: _licenseCertificateController.text.trim(),
        experienceCertificateLink: _experienceCertificateController.text.trim(),
        identityProofLink: _identityProofController.text.trim(),
        professionalAssociationLink: _associationController.text.trim(),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkSlate,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppTheme.amberGold, size: 28),
                SizedBox(width: 10),
                Text(
                  'Application Submitted',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Your account has been created and is pending admin verification.\n\nOur administrative team will review your credentials and verification documents. You will be able to log in once your account is verified.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amberGold,
                  foregroundColor: AppTheme.darkSlate,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppTheme.mainGradient),
          ),
          const BackgroundShapes(animated: true),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Card(
                    color: AppTheme.darkSlate.withValues(alpha: 0.85),
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 36 : 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const Spacer(),
                                const LogoWidget(size: LogoSize.sm, animated: false),
                                const SizedBox(width: 10),
                                const Text(
                                  'LLG Guide Registration',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 32),

                            // Title & Subtitle
                            const Text(
                              'Become a Verified Guide',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fill out your credentials and verification links below for administrator review.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                            ),
                            const SizedBox(height: 24),

                            // SECTION 1: ACCOUNT & PERSONAL DETAILS
                            _buildSectionHeader('1. Personal & Account Details', Icons.person_rounded),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Full Name *', Icons.badge_outlined),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Email Address *', Icons.email_outlined),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Please enter an email';
                                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Password *', Icons.lock_outline).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.length < 6) return 'Minimum 6 characters';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Confirm Password *', Icons.lock_reset).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v != _passwordController.text) return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // SECTION 2: PROFESSIONAL QUALIFICATIONS
                            _buildSectionHeader('2. Professional Qualifications', Icons.school_rounded),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _qualificationController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Qualification * (e.g. M.Ed, Child Psychologist)', Icons.workspace_premium_outlined),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _licenseController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('License / Certification No. *', Icons.card_membership_outlined),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _experienceController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Years of Experience * (e.g. 5 Years)', Icons.history_edu_outlined),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _specializationController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Specialization * (e.g. Ages 3-6 Early Years)', Icons.psychology_outlined),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _organizationController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Organization / Affiliation *', Icons.business_outlined),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _bioController,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Short Professional Bio / Philosophy *', Icons.description_outlined),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a short bio' : null,
                            ),
                            const SizedBox(height: 28),

                            // SECTION 3: PRACTICE & LOCATION
                            _buildSectionHeader('3. Practice & Location', Icons.location_on_rounded),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _regionController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Region / City *', Icons.map_outlined),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _languagesController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Languages Spoken * (e.g. English, Spanish)', Icons.translate_outlined),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _consultationMode,
                              dropdownColor: AppTheme.darkSlate,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Consultation Mode', Icons.video_call_outlined),
                              items: const [
                                DropdownMenuItem(value: 'Online', child: Text('Online Only')),
                                DropdownMenuItem(value: 'In-Person', child: Text('In-Person Only')),
                                DropdownMenuItem(value: 'Online & In-Person', child: Text('Online & In-Person')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _consultationMode = val);
                              },
                            ),
                            const SizedBox(height: 28),

                            // SECTION 4: CERTIFICATE & VERIFICATION LINKS
                            _buildSectionHeader('4. 📎 Verification Documents (Certificate Links)', Icons.link_rounded),
                            const SizedBox(height: 6),
                            Text(
                              'Please provide accessible public links (Google Drive, DigiLocker, University, or RCI verification links) for verification.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _qualificationCertificateController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                '🎓 Qualification Certificate Link *',
                                Icons.link_rounded,
                              ).copyWith(hintText: 'Google Drive / DigiLocker / University verification link'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide qualification certificate link' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _licenseCertificateController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                '📜 License Certificate Link *',
                                Icons.link_rounded,
                              ).copyWith(hintText: 'RCI / State board / Professional license verification link'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide license certificate link' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _experienceCertificateController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                '💼 Experience Certificate Link *',
                                Icons.link_rounded,
                              ).copyWith(hintText: 'Employer verification link / LinkedIn profile'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide experience proof link' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _identityProofController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                '🪪 Identity Proof Link *',
                                Icons.link_rounded,
                              ).copyWith(hintText: 'Aadhaar / PAN / Passport link (masked)'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide identity proof link' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _associationController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                '🤝 Professional Association Link (Optional)',
                                Icons.link_rounded,
                              ).copyWith(hintText: 'IPA / APA membership verification link'),
                            ),
                            const SizedBox(height: 32),

                            // SUBMIT BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitApplication,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.amberGold,
                                  foregroundColor: AppTheme.darkSlate,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 6,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppTheme.darkSlate,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Application for Verification',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.amberGold, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.amberGold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.white60, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.amberGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
