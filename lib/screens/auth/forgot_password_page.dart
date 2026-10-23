import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_loading_overlay.dart';

/// Screen allowing users to securely request a password reset email via Firebase Authentication.
class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;
  final AuthService? authService;

  const ForgotPasswordPage({
    super.key,
    this.initialEmail,
    this.authService,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Brand color palette matching AuthPage
  static const Color brandPurple = Color(0xFF8B00D6);
  static const Color brandPurpleLight = Color(0xFFB84AF5);
  static const Color brandPurpleDark = Color(0xFF65009E);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  AuthService? _authServiceInstance;
  AuthService get _authService =>
      widget.authService ?? (_authServiceInstance ??= AuthService());

  bool _isLoading = false;
  bool _emailSent = false;
  String _lastSentEmail = '';

  // Resend cooldown timer
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 30]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSendResetLink() async {
    if (_isLoading || _cooldownSeconds > 0) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(email: email);

      if (mounted) {
        setState(() {
          _emailSent = true;
          _lastSentEmail = email;
        });
        _startCooldown(30);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResendResetLink() async {
    if (_isLoading || _cooldownSeconds > 0) return;

    final email = _lastSentEmail.isNotEmpty
        ? _lastSentEmail
        : _emailController.text.trim();

    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(email: email);

      if (mounted) {
        _startCooldown(30);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _returnToLogin() {
    final email = _lastSentEmail.isNotEmpty
        ? _lastSentEmail
        : _emailController.text.trim();
    Navigator.of(context).pop(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          if (_isLoading)
            const AuthLoadingOverlay(
              message: 'Sending password reset link...',
            ),
        ],
      ),
    );
  }

  // ============ DESKTOP LAYOUT (> 800px) ============

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brandPurpleDark, brandPurple, brandPurpleLight],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _buildDesktopBrandContent(),
                ),
              ),
            ),
          ),
        ),

        // Right form panel
        Expanded(
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _emailSent
                        ? _buildSuccessView(key: const ValueKey('desktop_success'))
                        : _buildFormView(key: const ValueKey('desktop_form')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBrandContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'LittleLumin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Password\nRecovery',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'We will send a secure password reset link to your email so you can safely regain access to your account.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 16,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 36),
        _buildBrandSecurityPoint(
          icon: Icons.lock_outline,
          text: 'Official Firebase secure authentication',
        ),
        _buildBrandSecurityPoint(
          icon: Icons.mark_email_read_outlined,
          text: 'Verified reset link sent directly to your inbox',
        ),
        _buildBrandSecurityPoint(
          icon: Icons.shield_outlined,
          text: 'Safeguarding your family profile & child data',
        ),
      ],
    );
  }

  Widget _buildBrandSecurityPoint({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ MOBILE LAYOUT (< 800px) ============

  Widget _buildMobileLayout() {
    return Container(
      color: const Color(0xFFF8F9FD),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const ValueKey('forgot_password_back_icon_btn'),
                  icon: const Icon(Icons.arrow_back),
                  color: const Color(0xFF1E1E2D),
                  tooltip: 'Back to Sign In',
                  onPressed: _returnToLogin,
                ),
              ),
              const SizedBox(height: 4),

              // Brand header
              _buildMobileBrandHeader(),
              const SizedBox(height: 20),

              // Card containing form or success
              Card(
                elevation: 6,
                color: Colors.white,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _emailSent
                        ? _buildSuccessView(key: const ValueKey('mobile_success'))
                        : _buildFormView(key: const ValueKey('mobile_form')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBrandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandPurpleDark, brandPurple, brandPurpleLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandPurple.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_reset,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LittleLumin Account Security',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ FORM VIEW ============

  Widget _buildFormView({Key? key}) {
    return Form(
      key: _formKey,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your account's email address and we'll send you a link to reset your password.",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),

          // Email field
          TextFormField(
            key: const ValueKey('forgot_password_email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => _handleSendResetLink(),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'example@email.com',
              prefixIcon: const Icon(Icons.email_outlined),
              suffixIcon: _emailController.text.isNotEmpty && !_isLoading
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _emailController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandPurple, width: 2),
              ),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 24),

          // Send Reset Link button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('send_reset_link_btn'),
              onPressed: _isLoading ? null : _handleSendResetLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Return to Sign In button
          Center(
            child: TextButton.icon(
              key: const ValueKey('back_to_login_btn'),
              onPressed: _returnToLogin,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Sign In'),
              style: TextButton.styleFrom(
                foregroundColor: brandPurple,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ SUCCESS VIEW ============

  Widget _buildSuccessView({Key? key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: brandPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: brandPurple,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        const Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E2D),
          ),
        ),
        const SizedBox(height: 10),

        // Subtitle
        Text(
          'If an account is associated with $_lastSentEmail, a password reset link has been sent.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        // Instructions container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: brandPurple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please check both your inbox and your spam or junk folder.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Follow the link in the email to choose a new password. For security, the link will expire after a short period.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Return to Sign In button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            key: const ValueKey('back_to_login_btn'),
            onPressed: _returnToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Return to Sign In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Resend button with cooldown
        Center(
          child: TextButton(
            key: const ValueKey('resend_reset_link_btn'),
            onPressed: (_isLoading || _cooldownSeconds > 0)
                ? null
                : _handleResendResetLink,
            style: TextButton.styleFrom(
              foregroundColor: brandPurple,
              disabledForegroundColor: Colors.grey.shade500,
            ),
            child: Text(
              _cooldownSeconds > 0
                  ? 'Resend email in ${_cooldownSeconds}s'
                  : "Didn't receive an email? Resend",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),

        // Option to edit email
        Center(
          child: TextButton(
            key: const ValueKey('change_email_btn'),
            onPressed: () {
              setState(() {
                _emailSent = false;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: const Text(
              'Use a different email address',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
