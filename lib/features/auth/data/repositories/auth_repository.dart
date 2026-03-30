import 'package:finport/core/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  Stream<AuthState> authStateChanges() => Supa.client.auth.onAuthStateChange;

  Session? get currentSession => Supa.client.auth.currentSession;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Supa.client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await Supa.client.auth.signUp(email: email, password: password);
  }

  Future<void> sendPasswordRecoveryCode({required String email}) async {
    await Supa.client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    await Supa.client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: code,
    );
  }

  Future<void> updatePassword({required String newPassword}) async {
    await Supa.client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signInWithGoogle() async {
    await Supa.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  Future<void> signInWithApple() async {
    await Supa.client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  Future<void> signOut() async {
    await Supa.client.auth.signOut();
  }
}
