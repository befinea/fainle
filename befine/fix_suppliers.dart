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
    if (line.startsWith('SUPABASE_URL=')) {
      url = line.substring(line.indexOf('=') + 1).trim().replaceAll('"', '').replaceAll("'", '');
    }
    if (line.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) {
      key = line.substring(line.indexOf('=') + 1).trim().replaceAll('"', '').replaceAll("'", '');
    }
  }
  
  if (url.isEmpty || key.isEmpty) {
    print('Missing url or key in .env');
    return;
  }
  
  final client = SupabaseClient(url, key);
  try {
    print('Fetching profiles with role = "supplier"...');
    final profiles = await client
        .from('profiles')
        .select('id, company_id, full_name')
        .eq('role', 'supplier');
    
    print('Found ${profiles.length} suppliers.');

    for (var p in profiles) {
      final String id = p['id'];
      final String companyId = p['company_id'];
      final String name = p['full_name'] ?? 'Unknown Supplier';

      print('Processing supplier: $name ($id)');
      
      try {
        await client.from('external_entities').upsert({
          'id': id,
          'company_id': companyId,
          'name': name,
          'type': 'supplier',
        });
        print('  -> Successfully synced to external_entities.');
      } catch (e) {
        print('  -> Error syncing $name: $e');
      }
    }
    
    print('Done syncing suppliers.');
  } catch (e) {
    print('Global error: $e');
  } finally {
    client.dispose();
  }
}
