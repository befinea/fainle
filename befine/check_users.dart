import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('No .env file found');
    return;
  }
  
  final lines = await envFile.readAsLines();
  String url = '';
  String key = '';
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].trim();
    if (line.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) key = line.split('=')[1].trim();
  }
  
  if (url.isEmpty || key.isEmpty) {
    print('Missing url or key');
    return;
  }
  
  final client = SupabaseClient(url, key);
  try {
    // Note: older versions of supabase-dart might not have listUsers, 
    // but the admin API allows creating users. Let's try to query profiles 
    // to get the email since it's stored in auth.users, wait, profiles doesn't store email.
    // Let's print profiles first to see if the profile was created.
    final profiles = await client.from('profiles').select();
    print('--- PROFILES ---');
    for (var p in profiles) {
      print('ID: ${p['id']}, Name: ${p['full_name']}, Role: ${p['role']}, Company: ${p['company_id']}');
    }

    try {
      final res = await client.auth.admin.listUsers();
      print('\n--- AUTH USERS ---');
      for (var u in res) {
        print('Email: ${u.email}, Confirmed: ${u.emailConfirmedAt != null}, CreatedAt: ${u.createdAt}');
      }
    } catch (e) {
      print('\nCould not list users (might not be supported in this SDK version): $e');
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
