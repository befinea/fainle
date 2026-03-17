import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/app_user.dart';
import '../../../../core/error/exceptions.dart' hide AuthException;

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Get current user from the session and DB
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final json = Map<String, dynamic>.from(profileData);
      json['email'] = user.email ?? '';
      json['name'] = profileData['full_name'];

      return AppUser.fromJson(json);
    } catch (e) {
      throw ServerException('Failed to get user profile: $e');
    }
  }

  Future<AppUser> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Login failed: user is null');
      }

      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .single();

      final json = Map<String, dynamic>.from(profileResponse);
      json['email'] = response.user!.email ?? '';
      json['name'] = profileResponse['full_name'];

      return AppUser.fromJson(json);
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw ServerException('Failed to sign in: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw ServerException('Failed to sign out: $e');
    }
  }
}
