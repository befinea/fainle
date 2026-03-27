import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

final customPermissionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Watch auth state so we re-fetch when user logs in/out
  final authState = ref.watch(authProvider);
  
  if (!authState.isAuthenticated || authState.user == null) return {};

  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return {};

  try {
    final response = await supabase
        .from('profiles')
        .select('custom_permissions')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null || response['custom_permissions'] == null) {
      return {};
    }
    return response['custom_permissions'] as Map<String, dynamic>;
  } catch (e) {
    return {};
  }
});
