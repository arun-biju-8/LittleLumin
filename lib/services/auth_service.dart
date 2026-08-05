// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // ✅ Sign Up with Email
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'userType': 'parent',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _user = userCredential.user;
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _handleAuthError(e);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Something went wrong. Please try again.';
    }
  }

  // ✅ Sign In with Email
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _handleAuthError(e);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Something went wrong. Please try again.';
    }
  }

  // ✅ Sign In with Google
  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    await _googleSignIn.signOut();

    try {
      //////////////////////////////
      print("1. Starting Google Sign-In");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print("2. Google account selected");

      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;
      print("3. Google authentication received");

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("4. Firebase credential created");

      final userCredential = await _auth.signInWithCredential(credential);

      print("5. Firebase sign-in successful");

      final docSnapshot = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      print("6. Firestore read successful");
      // final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      // if (googleUser == null) {
      //   _isLoading = false;
      //   notifyListeners();
      //   return 'Google sign-in cancelled.';
      // }

      // final GoogleSignInAuthentication googleAuth =
      //     await googleUser.authentication;

      // final OAuthCredential credential = GoogleAuthProvider.credential(
      //   accessToken: googleAuth.accessToken,
      //   idToken: googleAuth.idToken,
      // );

      // UserCredential userCredential = await _auth.signInWithCredential(
      //   credential,
      // );

      // print("Signed in");

      // final docSnapshot = await _firestore
      //     .collection('users')
      //     .doc(userCredential.user!.uid)
      //     .get();

      // print("Firestore read success");

      /////////////////////////////////

      if (!docSnapshot.exists) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': googleUser.displayName ?? '',
          'email': googleUser.email,
          'photoUrl': googleUser.photoUrl ?? '',
          'userType': 'parent',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _user = userCredential.user;
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _handleAuthError(e);
    } catch (e, stack) {
      _isLoading = false;
      notifyListeners();

      print("=================================");
      print(e);
      print(stack);

      return e.toString();
    }
  }

  // ✅ Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  // ✅ Handle Auth Errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
