import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static RealtimeClient get realtime => client.realtime;

  static SupabaseStorageClient get storage => client.storage;

  static PostgrestQueryBuilder from(String table) => client.from(table);
}
