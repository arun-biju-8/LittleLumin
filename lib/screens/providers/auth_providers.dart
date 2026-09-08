// lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool get isLoading => _authService.isLoading;
  bool get isLoggedIn => _authService.isLoggedIn;
  User? get user => _authService.user;

  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _authService.signUpWithEmail(
      name: name,
      email: email,
      password: password,
    );
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _authService.signInWithEmail(
      email: email,
      password: password,
    );
  }

  Future<String?> signInWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<String?> getUserRole(String uid) async {
    return await _authService.getUserRole(uid);
  }
}