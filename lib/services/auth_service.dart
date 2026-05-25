import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _firebaseReady = false;

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _firebaseReady = true;
    } catch (e) {
      debugPrint('AuthService: Firebase unavailable ($e). UI demo mode.');
      _firebaseReady = false;
    }
  }

  bool get firebaseReady => _firebaseReady;
  User? get currentUser => _firebaseReady ? _auth?.currentUser : null;

  Stream<User?> authStateChanges() {
    if (!_firebaseReady || _auth == null) {
      return Stream<User?>.value(null);
    }
    return _auth!.authStateChanges();
  }

  void _ensureReady() {
    if (!_firebaseReady || _auth == null) {
      throw FirebaseAuthException(
        code: 'firebase-not-configured',
        message:
            'Firebase is not configured. Add GoogleService-Info.plist and rebuild.',
      );
    }
  }

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _ensureReady();
    final cred = await _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
      await cred.user?.reload();
    }
    notifyListeners();
    return _auth!.currentUser;
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    final cred = await _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    notifyListeners();
    return cred.user;
  }

  Future<User?> signInWithGoogle() async {
    _ensureReady();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth!.signInWithCredential(credential);
    notifyListeners();
    return cred.user;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _ensureReady();
    await _auth!.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (!_firebaseReady || _auth == null) return;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth!.signOut();
    notifyListeners();
  }

  String mapAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'firebase-not-configured':
          return 'Auth backend not configured yet. Add GoogleService-Info.plist to ios/Runner/.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak (minimum 6 characters).';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'operation-not-allowed':
          return 'This sign-in method is disabled.';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    return 'Something went wrong. Try again.';
  }
}
