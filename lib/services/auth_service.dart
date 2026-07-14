import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/auth_config.dart';

enum AuthFailureReason {
  emptyId,
  emptyPassword,
  invalidId,
  configMissing,
  invalidCredentials,
  unauthorized,
  network,
  unknown,
}

class AuthResult {
  const AuthResult.success() : failure = null;
  const AuthResult.failure(this.failure);

  final AuthFailureReason? failure;

  bool get isSuccess => failure == null;
}

abstract class AuthClient {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  bool get isAuthorized;

  Future<void> setPersistence({required bool keepSignedIn});
  Future<AuthResult> signIn({
    required String adminId,
    required String password,
    required bool keepSignedIn,
  });
  Future<void> signOut();
}

class AuthService implements AuthClient {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  bool get isAuthorized {
    final user = currentUser;
    if (user == null) return false;
    return AuthConfig.isAuthorizedUser(uid: user.uid, email: user.email);
  }

  @override
  Future<void> setPersistence({required bool keepSignedIn}) async {
    if (!kIsWeb) return;
    await _auth.setPersistence(
      keepSignedIn ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  @override
  Future<AuthResult> signIn({
    required String adminId,
    required String password,
    required bool keepSignedIn,
  }) async {
    final id = adminId.trim();
    final pwd = password;

    if (id.isEmpty) return const AuthResult.failure(AuthFailureReason.emptyId);
    if (pwd.isEmpty) {
      return const AuthResult.failure(AuthFailureReason.emptyPassword);
    }
    if (id != AuthConfig.displayAdminId) {
      return const AuthResult.failure(AuthFailureReason.invalidId);
    }
    if (!AuthConfig.hasAdminEmailConfigured) {
      return const AuthResult.failure(AuthFailureReason.configMissing);
    }

    try {
      await setPersistence(keepSignedIn: keepSignedIn);
      final credential = await _auth.signInWithEmailAndPassword(
        email: AuthConfig.adminAuthEmail.trim(),
        password: pwd,
      );
      final user = credential.user;
      if (user == null ||
          !AuthConfig.isAuthorizedUser(uid: user.uid, email: user.email)) {
        await _auth.signOut();
        return const AuthResult.failure(AuthFailureReason.unauthorized);
      }
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      AuthConfig.debugLogAuthFailure(e.code);
      if (e.code == 'network-request-failed') {
        return const AuthResult.failure(AuthFailureReason.network);
      }
      return const AuthResult.failure(AuthFailureReason.invalidCredentials);
    } catch (e) {
      AuthConfig.debugLogAuthFailure(e);
      final text = e.toString().toLowerCase();
      if (text.contains('network') || text.contains('socket')) {
        return const AuthResult.failure(AuthFailureReason.network);
      }
      return const AuthResult.failure(AuthFailureReason.unknown);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
