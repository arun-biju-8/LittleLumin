import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
  User? get user => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============ EMAIL/PASSWORD SIGN UP ============
  Future<UserModel?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String userType = 'parent',
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('🔵 Signing up: $email');
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('User creation failed');

      // Update display name
      await user.updateDisplayName(name.trim());

      // Create user document in Firestore
      final userModel = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        userType: userType,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      
      debugPrint('✅ Sign up successful: ${user.uid}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign up error: ${e.code} - ${e.message}');
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      throw Exception('Sign up failed. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ EMAIL/PASSWORD LOGIN ============
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('🔵 Signing in: $email');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Login failed');

      // Fetch user data from Firestore
      final userModel = await _getUserData(user.uid);
      debugPrint('✅ Login successful: ${user.uid}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Login error: ${e.code} - ${e.message}');
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw Exception('Login failed. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ GOOGLE SIGN-IN (FIXED) ============
  Future<UserModel?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('🔵 Starting Google Sign-In...');

      // Configure GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Sign out first to force account picker
      await googleSignIn.signOut();

      // Trigger the sign-in flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('⚠️ User cancelled Google Sign-In');
        return null;
      }

      debugPrint('✅ Google account selected: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) throw Exception('Google sign-in failed');

      debugPrint('✅ Firebase Google Sign-In: ${user.uid}');

      // Check if user document exists
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      UserModel userModel;
      if (!userDoc.exists) {
        // Create new user document
        userModel = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          phone: '',
          userType: 'parent',
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        debugPrint('✅ New user document created');
      } else {
        userModel = UserModel.fromMap(user.uid, userDoc.data()!);
        debugPrint('✅ Existing user loaded');
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Google Sign-In error: ${e.code} - ${e.message}');
      
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception('An account already exists with a different sign-in method.');
      }
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      throw Exception('Google Sign-In failed. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ SIGN OUT ============
  Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await _auth.signOut();
      notifyListeners();
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      throw Exception('Sign out failed');
    }
  }

  // ============ HELPERS ============
  Future<UserModel?> _getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        debugPrint('⚠️ User document not found for: $uid');
        return null;
      }
      return UserModel.fromMap(uid, doc.data()!);
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
      return null;
    }
  }

  // Compatibility method for AuthWrapper & role checks
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['userType'] as String? ?? 'parent';
      }
      return 'parent';
    } catch (e) {
      debugPrint('❌ Error fetching user role: $e');
      return 'parent';
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}