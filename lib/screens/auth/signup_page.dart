// lib/screens/auth/signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/constants.dart';
import '../parent/parent_dashboard.dart';
import 'login_page.dart';
import '../../widgets/auth_loading_overlay.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final bool isWeb = kIsWeb;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'userType': 'parent',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        _showSuccess('Account created successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentDashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please login.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 8 characters.';
      }
      _showError(message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!doc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'name': googleUser.displayName ?? '',
              'email': googleUser.email,
              'phone': '',
              'photoUrl': googleUser.photoUrl ?? '',
              'userType': 'parent',
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      if (mounted) {
        _showSuccess('Account created successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentDashboard()),
        );
      }
    } catch (e) {
      _showError('Google Sign-Up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  /// Name validation
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    
    final name = value.trim();
    
    if (name.length < 3) {
      return 'Name must be at least 3 characters';
    }
    
    if (name.length > 50) {
      return 'Name is too long (max 50 characters)';
    }
    
    // Only letters and spaces
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(name)) {
      return 'Name can only contain letters and spaces';
    }
    
    return null;
  }

  /// Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final email = value.trim();
    
    if (!email.contains('@')) {
      return 'Email must contain @ symbol';
    }
    
    if (!email.contains('.')) {
      return 'Email must contain a domain (e.g., .com)';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }
    
    return null;
  }

  /// Phone validation (10-digit Indian mobile)
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    final phone = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    
    // Check for valid length
    if (phone.length != 10) {
      return 'Phone number must be 10 digits';
    }
    
    // Check if all digits
    final phoneRegex = RegExp(r'^[0-9]+$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Phone number can only contain digits';
    }
    
    // Indian mobile numbers start with 6, 7, 8, or 9
    if (!RegExp(r'^[6-9]').hasMatch(phone)) {
      return 'Phone number must start with 6, 7, 8, or 9';
    }
    
    return null;
  }

  /// Strong password validation
  String? _validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (value.length > 64) {
      return 'Password is too long (max 64 characters)';
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least 1 uppercase letter';
    }
    
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least 1 lowercase letter';
    }
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least 1 number';
    }
    
    if (value.contains(' ')) {
      return 'Password cannot contain spaces';
    }
    
    return null;
  }

  /// Confirm password validation
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    
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
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textDark),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isWeb ? 480 : double.infinity,
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Your Account',
                          style: AppTextStyles.heading1,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Start your parenting journey today',
                          style: AppTextStyles.bodyLight,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ============ NAME VALIDATION ============
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: _validateName,
                        ),
                        const SizedBox(height: 16),

                        // ============ EMAIL VALIDATION ============
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
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),

                        // ============ PHONE VALIDATION ============
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '10-digit mobile number',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 16),

                        // ============ PASSWORD VALIDATION (STRONG) ============
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Min 8 chars, 1 uppercase, 1 number',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            helperText: 'At least 8 characters with 1 uppercase letter and 1 number',
                            helperMaxLines: 2,
                          ),
                          validator: _validateStrongPassword,
                          onChanged: (_) => setState(() {}), // Update password strength indicator
                        ),
                        _buildPasswordStrengthIndicator(),
                        const SizedBox(height: 16),

                        // ============ CONFIRM PASSWORD VALIDATION ============
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Re-enter your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Create Account', style: AppTextStyles.button),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _signUpWithGoogle,
                            icon: const FaIcon(FontAwesomeIcons.google, color: Color(0xFFDB4437), size: 22),
                            label: Text(
                              'Sign up with Google',
                              style: AppTextStyles.body.copyWith(color: AppColors.textDark),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ', style: AppTextStyles.bodyLight),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              ),
                              child: Text(
                                'Log In',
                                style: AppTextStyles.button.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        Center(
                          child: Text(
                            '📚 Are you an LLG or Admin? Contact us to get started',
                            style: AppTextStyles.small,
                            textAlign: TextAlign.center,
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
        if (_isLoading)
          const AuthLoadingOverlay(
            message: 'Authenticating your account...',
          ),
      ],
    );
  }
}