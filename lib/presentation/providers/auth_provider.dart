import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.auth.onAuthStateChange.map((event) => event.session?.user);
});

final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.auth.currentUser;
});

final authControllerProvider = Provider((ref) => AuthController());

class AuthController {
  Future<AuthResponse> signIn(String email, String password) async {
    return await SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password, String fullName) async {
    final res = await SupabaseService.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return res;
  }

  Future<void> signOut() async {
    await SupabaseService.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await SupabaseService.auth.resetPasswordForEmail(email);
  }
}
