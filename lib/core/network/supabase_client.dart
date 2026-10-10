import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://zpfpgqygxibptowssilx.supabase.co',
    anonKey: 'sb_publishable_57I6BzIToWMO5EsiC4tbQg_aegxpBYG',
  );
}

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static RealtimeClient get realtime => client.realtime;

  static SupabaseStorageClient get storage => client.storage;

  static dynamic from(String table) => client.from(table);
}