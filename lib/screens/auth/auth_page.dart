import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_loading_overlay.dart';
import '../admin/admin_dashboard.dart';
import '../llg/llg_dashboard.dart';
import '../parent/parent_dashboard.dart';

enum AuthMode { login, signup }

class AuthPage extends StatefulWidget {
  final AuthMode initialMode;
  final AuthService? authService;

  const AuthPage({
    super.key,
    this.initialMode = AuthMode.login,
    this.authService,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  // Brand color palette
  static const Color brandPurple = Color(0xFF8B00D6);
  static const Color brandPurpleLight = Color(0xFFB84AF5);
  static const Color brandPurpleDark = Color(0xFF65009E);

  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late AuthMode _currentMode;

  AuthService? _authServiceInstance;
  AuthService get _authService =>
      widget.authService ?? (_authServiceInstance ??= AuthService());
  bool _isLoading = false;

  // Login form controllers & state
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscureLoginPassword = true;

  // Signup form controllers & state
  final _signupFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureSignupPassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = true;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    if (_currentMode == AuthMode.signup) {
      _controller.value = 1.0;
    }

    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _controller.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _signupEmailController.dispose();
    _phoneController.dispose();
    _signupPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============ MODE TOGGLE & URL SYNC ============

  void _toggleMode() {
    setState(() {
      _currentMode = _currentMode == AuthMode.login
          ? AuthMode.signup
          : AuthMode.login;

      // Smart pre-fill: if user typed email in login, carry it to signup and vice-versa
      if (_currentMode == AuthMode.signup &&
          _loginEmailController.text.isNotEmpty &&
          _signupEmailController.text.isEmpty) {
        _signupEmailController.text = _loginEmailController.text;
      } else if (_currentMode == AuthMode.login &&
          _signupEmailController.text.isNotEmpty &&
          _loginEmailController.text.isEmpty) {
        _loginEmailController.text = _signupEmailController.text;
      }
    });

    if (_currentMode == AuthMode.login) {
      _controller.reverse();
    } else {
      _controller.forward();
    }

    _updateUrlHash();
  }

  void _updateUrlHash() {
    if (kIsWeb) {
      final newHash = _currentMode == AuthMode.login ? '#/login' : '#/signup';
      try {
        SystemNavigator.routeInformationUpdated(location: newHash);
      } catch (_) {
        // Fallback or no-op if unsupported on target platform
      }
    }
  }

  // ============ REMEMBER ME ============

  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remembered_email');
      final remembered = prefs.getBool('remember_me') ?? false;
      if (email != null && remembered && mounted) {
        setState(() {
          _loginEmailController.text = email;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading remembered email: $e');
    }
  }

  Future<void> _saveRememberedEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_email', email);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('remembered_email');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      debugPrint('Error saving email: $e');
    }
  }

  // ============ AUTH ACTIONS ============

  Future<void> _handleEmailLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithEmail(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );

      if (user == null) {
        throw Exception('Invalid credentials');
      }

      await _saveRememberedEmail(_loginEmailController.text.trim());

      if (mounted) {
        _showSuccess('Login successful!');
        _navigateBasedOnUserType(user);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignUp() async {
    if (!_signupFormKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      _showError('Please accept the Terms of Service to continue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (user == null) {
        throw Exception('User creation failed');
      }

      if (mounted) {
        _showSuccess('Account created successfully!');
        _navigateBasedOnUserType(user);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();

      if (user == null) {
        // User cancelled
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        _showSuccess('Login successful!');
        _navigateBasedOnUserType(user);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateBasedOnUserType(UserModel user) {
    Widget destination;
    switch (user.userType) {
      case 'llg':
      case 'llg_pending':
        destination = const LLGDashboard();
        break;
      case 'admin':
        destination = const AdminDashboard();
        break;
      default:
        destination = const ParentDashboard();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============ MAIN BUILD ============

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
              message: 'Authenticating your account...',
            ),
        ],
      ),
    );
  }

  // ============ DESKTOP LAYOUT (> 800px) ============

  Widget _buildDesktopLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = constraints.maxWidth / 2;

        return Stack(
          children: [
            // Brand panel — slides left -> right on toggle
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                final position = _slideAnimation.value * halfWidth;
                final transitionDepth =
                    math.sin(_slideAnimation.value * math.pi);

                return Positioned(
                  left: position,
                  width: halfWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.08 + (0.12 * transitionDepth),
                          ),
                          blurRadius: 18 + (16 * transitionDepth),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildBrandPanel(),
                  ),
                );
              },
            ),

            // Form panel — slides right -> left on toggle
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                final position =
                    halfWidth - (_slideAnimation.value * halfWidth);
                final transitionDepth =
                    math.sin(_slideAnimation.value * math.pi);

                return Positioned(
                  left: position,
                  width: halfWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.06 + (0.10 * transitionDepth),
                          ),
                          blurRadius: 16 + (14 * transitionDepth),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildFormPanel(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ============ BRAND PANEL ============

  Widget _buildBrandPanel() {
    return Stack(
      children: [
        // Decorative rotating background layer
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * math.pi,
                alignment: Alignment.center,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [brandPurpleDark, brandPurple, brandPurpleLight],
                    ),
                  ),
                  child: CustomPaint(
                    painter: _BrandDecorativePainter(),
                  ),
                ),
              );
            },
          ),
        ),

        // Brand content layer: stays perfectly upright and cross-fades smoothly
        Positioned.fill(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _currentMode == AuthMode.login
                      ? _buildBrandLoginContent(
                          key: const ValueKey('brand_login'))
                      : _buildBrandSignupContent(
                          key: const ValueKey('brand_signup')),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandLoginContent({Key? key}) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo & Brand Name
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
          'Growing Children,\nGrowing Parents',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AI-powered, screen-free activities and personalized stories for children aged 3-6.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 17,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 40),
        _buildFeaturePoint(
          icon: Icons.auto_awesome,
          text: '✨ AI-Generated Activities',
        ),
        _buildFeaturePoint(
          icon: Icons.book_outlined,
          text: '📖 Personalized Stories',
        ),
        _buildFeaturePoint(
          icon: Icons.trending_up,
          text: '📈 Skill Progress Tracking',
        ),
      ],
    );
  }

  Widget _buildBrandSignupContent({Key? key}) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo & Brand Name
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
                  'Join LittleLumin',
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
          'Create Your\nFamily Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Create your family\'s profile in under a minute.\nFree to start. No credit card required.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 17,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 36),
        _buildFeaturePoint(
          icon: Icons.child_care,
          text: '✨ Personalized for each child',
        ),
        _buildFeaturePoint(
          icon: Icons.all_inclusive,
          text: '📖 Unlimited activity access',
        ),
        _buildFeaturePoint(
          icon: Icons.track_changes,
          text: '🎯 Track progress over time',
        ),
        _buildFeaturePoint(
          icon: Icons.medical_services_outlined,
          text: '👨‍⚕️ Optional specialist support',
        ),
      ],
    );
  }

  Widget _buildFeaturePoint({required IconData icon, required String text}) {
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
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ FORM PANEL (DESKTOP) ============

  Widget _buildFormPanel() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _currentMode == AuthMode.login
                  ? _buildLoginForm(key: const ValueKey('desktop_login'))
                  : _buildSignupForm(key: const ValueKey('desktop_signup')),
            ),
          ),
        ),
      ),
    );
  }

  // ============ MOBILE LAYOUT (< 800px) ============

  Widget _buildMobileLayout() {
    return Container(
      color: const Color(0xFFF8F9FD),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              _buildBrandHeader(),
              const SizedBox(height: 20),
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
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _currentMode == AuthMode.login
                        ? _buildLoginForm(key: const ValueKey('mobile_login'))
                        : _buildSignupForm(
                            key: const ValueKey('mobile_signup')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
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
              Icons.auto_awesome,
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _currentMode == AuthMode.login
                        ? 'LittleLumin'
                        : 'Join LittleLumin',
                    key: ValueKey(_currentMode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _currentMode == AuthMode.login
                        ? 'Growing Children, Growing Parents'
                        : 'Create your family profile in 1 min',
                    key: ValueKey('${_currentMode}_sub'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ LOGIN FORM ============

  Widget _buildLoginForm({Key? key}) {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue your journey',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),

          // Email field
          TextFormField(
            key: const ValueKey('login_email_field'),
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'example@email.com',
              prefixIcon: const Icon(Icons.email_outlined),
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
          const SizedBox(height: 16),

          // Password field
          TextFormField(
            key: const ValueKey('login_password_field'),
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                  () => _obscureLoginPassword = !_obscureLoginPassword,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandPurple, width: 2),
              ),
            ),
            validator: Validators.loginPassword,
          ),
          const SizedBox(height: 12),

          // Remember me checkbox
          Row(
            children: [
              Checkbox(
                key: const ValueKey('remember_me_checkbox'),
                value: _rememberMe,
                activeColor: brandPurple,
                onChanged: (val) => setState(() => _rememberMe = val ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Text(
                'Remember me',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sign In button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('login_submit_btn'),
              onPressed: _isLoading ? null : _handleEmailLogin,
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
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 22),

          // OR divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 22),

          // Google sign-in
          _buildGoogleButton(),
          const SizedBox(height: 26),

          // Toggle link
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              TextButton(
                key: const ValueKey('toggle_to_signup_btn'),
                onPressed: _toggleMode,
                style: TextButton.styleFrom(
                  foregroundColor: brandPurple,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ SIGNUP FORM ============

  Widget _buildSignupForm({Key? key}) {
    return Form(
      key: _signupFormKey,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Create Your Account',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start your parenting journey today',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Full Name
          TextFormField(
            key: const ValueKey('signup_name_field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandPurple, width: 2),
              ),
            ),
            validator: Validators.name,
          ),
          const SizedBox(height: 14),

          // Email
          TextFormField(
            key: const ValueKey('signup_email_field'),
            controller: _signupEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'example@email.com',
              prefixIcon: const Icon(Icons.email_outlined),
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
          const SizedBox(height: 14),

          // Phone
          TextFormField(
            key: const ValueKey('signup_phone_field'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '10-digit mobile number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandPurple, width: 2),
              ),
            ),
            validator: Validators.phone,
          ),
          const SizedBox(height: 14),

          // Password (strong)
          TextFormField(
            key: const ValueKey('signup_password_field'),
            controller: _signupPasswordController,
            obscureText: _obscureSignupPassword,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Min 8 chars, 1 uppercase, 1 number',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignupPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                  () => _obscureSignupPassword = !_obscureSignupPassword,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandPurple, width: 2),
              ),
              helperText:
                  'At least 8 characters with 1 uppercase letter and 1 number',
              helperMaxLines: 2,
            ),
            validator: Validators.strongPassword,
            onChanged: (_) => setState(() {}),
          ),
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 14),

          // Confirm Password
          TextFormField(
            key: const ValueKey('signup_confirm_password_field'),
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandPurple, width: 2),
              ),
            ),
            validator: (v) =>
                Validators.confirmPassword(v, _signupPasswordController.text),
          ),
          const SizedBox(height: 10),

          // Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: const ValueKey('terms_checkbox'),
                value: _agreeToTerms,
                activeColor: brandPurple,
                onChanged: (val) =>
                    setState(() => _agreeToTerms = val ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Text(
                  'I agree to the Terms of Service and Privacy Policy',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Create Account Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('signup_submit_btn'),
              onPressed: _isLoading ? null : _handleEmailSignUp,
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
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // OR divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),

          // Google sign-in
          _buildGoogleButton(),
          const SizedBox(height: 22),

          // Toggle link
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              TextButton(
                key: const ValueKey('toggle_to_login_btn'),
                onPressed: _toggleMode,
                style: TextButton.styleFrom(
                  foregroundColor: brandPurple,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // LLG / Specialist notice
          Center(
            child: Text(
              '📚 Are you an LLG or Specialist? Contact us to get started',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ============ SHARED COMPONENTS ============

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        key: const ValueKey('google_sign_in_btn'),
        onPressed: _isLoading ? null : _handleGoogleLogin,
        icon: Image.asset(
          'assets/images/google_logo.png',
          height: 22,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.g_mobiledata,
            size: 28,
            color: Color(0xFFDB4437),
          ),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _signupPasswordController.text;

    if (password.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    Color color;
    String label;

    switch (strength) {
      case 0:
      case 1:
        color = Colors.red;
        label = 'Weak';
        break;
      case 2:
      case 3:
        color = Colors.orange;
        label = 'Medium';
        break;
      case 4:
      case 5:
        color = Colors.green;
        label = 'Strong';
        break;
      default:
        color = Colors.grey;
        label = '';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: strength / 5,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for rich decorative geometric motifs in Brand panel
class _BrandDecorativePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Concentric geometric circles
    final center1 = Offset(size.width * 0.15, size.height * 0.2);
    canvas.drawCircle(center1, 140, paint);
    canvas.drawCircle(center1, 200, paint);

    final center2 = Offset(size.width * 0.85, size.height * 0.8);
    canvas.drawCircle(center2, 160, paint);
    canvas.drawCircle(center2, 240, paint);

    // Glowing filled accents
    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.25), 80, fillPaint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.75), 100, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
