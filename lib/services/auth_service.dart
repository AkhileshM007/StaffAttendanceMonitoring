import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define admin email
  final String adminEmail = "admin@example.com";

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Sign-in Error: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if current user is admin
  bool isAdmin() {
    final user = _auth.currentUser;
    return user != null && user.email == adminEmail;
  }

  // Navigate based on email-based admin detection
  void navigateUserBasedOnRole(BuildContext context, Widget adminPage, Widget staffPage) {
    final user = getCurrentUser();
    if (user == null) return;

    final isAdminUser = isAdmin();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => isAdminUser ? adminPage : staffPage),
    );
  }

  // Sign up new user (admin only)
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Sign-up Error: $e");
      return null;
    }
  }
}
