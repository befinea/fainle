import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  // Read .env manually
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('.env file not found!');
    return;
  }
  
  final lines = envFile.readAsLinesSync();
  String? url;
  String? key;
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1];
    if (line.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) key = line.split('=')[1];
  }
  
  if (url == null || key == null) {
    print('Missing URL or KEY in .env');
    return;
  }
  
  final client = SupabaseClient(url, key);
  
  try {
    print('Checking profiles...');
    final pData = await client.from('profiles').select().limit(1);
    print('profiles row: $pData');
  } catch (e) {
    print('Error profiles: $e');
  }

  try {
    print('Checking users...');
    final uData = await client.from('users').select().limit(1);
    print('users row: $uData');
  } catch (e) {
    print('Error users: $e');
  }

  try {
    // Run an RPC to get triggers if possible, or just basic select
    final res = await client.rpc('get_schema_info'); // likely fails
    print(res);
  } catch (e) {}

}
