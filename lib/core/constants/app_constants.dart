class AppConstants {
  static const String appName = 'Crash ERP';
  
  static const String supabaseUrl = 'https://zpfpgqygxibptowssilx.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_57I6BzIToWMO5EsiC4tbQg_aegxpBYG';

  static const String offlineBox = 'offline_box';
  static const String settingsBox = 'settings_box';
  static const String syncQueueBox = 'sync_queue';

  // Colors
  static const int primaryDark = 0xFF0F172A;
  static const int surfaceLight = 0xFFF8FAFC;
  static const int cardWhite = 0xFFFFFFFF;
  static const int accentGreen = 0xFF10B981;
  static const int accentBlue = 0xFF3B82F6;
  static const int accentRed = 0xFFEF4444;
  static const int accentOrange = 0xFFF59E0B;

  // Plans
  static const Map<String, Map<String, dynamic>> plans = {
    'free': {
      'name': 'Free',
      'maxProducts': 50,
      'maxUsers': 2,
      'maxInvoices': 100,
    },
    'pro': {
      'name': 'Pro',
      'maxProducts': 500,
      'maxUsers': 10,
      'maxInvoices': 1000,
    },
    'enterprise': {
      'name': 'Enterprise',
      'maxProducts': 10000,
      'maxUsers': 100,
      'maxInvoices': 10000,
    },
  };
}