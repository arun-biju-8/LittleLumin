import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../parent/parent_dashboard.dart';
import '../llg/llg_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'signup_page.dart';
import '../../models/user_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remembered_email');
      final remembered = prefs.getBool('remember_me') ?? false;
      if (email != null && remembered) {
        setState(() {
          _emailController.text = email;
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

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user == null) {
        throw Exception('Invalid credentials');
      }

      await _saveRememberedEmail(_emailController.text.trim());

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

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();

      if (user == null) {
        // User cancelled
        setState(() => _isLoading = false);
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

  // ============ VALIDATION HELPERS ============

  /// Email validation with detailed messages
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final email = value.trim();
    
    // Basic format check
    if (!email.contains('@')) {
      return 'Email must contain @ symbol';
    }
    
    if (!email.contains('.')) {
      return 'Email must contain a domain (e.g., .com)';
    }
    
    // Regex validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    // Check for common typos
    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }
    
    if (email.startsWith('.') || email.endsWith('.')) {
      return 'Email cannot start or end with a dot';
    }
    
    if (email.contains('@.')) {
      return 'Email domain is invalid';
    }
    
    return null;
  }

  /// Login password validation (only checks if provided)
  String? _validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        // Left - Branding
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade800, Colors.purple.shade500],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'LittleLumin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Growing Children,\nGrowing Parents',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AI-powered, screen-free activities and personalized stories for children aged 3-6.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildFeaturePoint(Icons.auto_awesome, 'AI-Generated Activities'),
                    _buildFeaturePoint(Icons.book, 'Personalized Stories'),
                    _buildFeaturePoint(Icons.trending_up, 'Skill Progress Tracking'),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right - Form
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade700, Colors.purple.shade400],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.auto_awesome, size: 48, color: Colors.purple.shade700),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Welcome Back',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Sign in to continue your journey',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'example@email.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            validator: _validateLoginPassword,
          ),
          const SizedBox(height: 12),

          // Remember me
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (val) => setState(() => _rememberMe = val ?? false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const Text('Remember me'),
            ],
          ),
          const SizedBox(height: 16),

          // Login button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),

          // Google sign-in
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleLogin,
              icon: Image.asset(
                'assets/images/google_logo.png',
                height: 24,
                errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 32),
              ),
              label: const Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Sign up link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ", style: TextStyle(color: Colors.grey.shade600)),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
                },
                child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
