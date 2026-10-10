class AppConstants {
  // ========== SUPABASE (Replace with your project) ==========
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';

  // ========== APP ==========
  static const String appName = 'Crash ERP';
  static const String appVersion = '1.0.0';
  static const String companyName = 'Crash Soft';

  // ========== HIVE BOXES ==========
  static const String offlineBox = 'offline_data';
  static const String settingsBox = 'settings';
  static const String syncQueueBox = 'sync_queue';

  // ========== COLORS ==========
  static const int primaryDark = 0xFF0F172A;
  static const int primaryBlue = 0xFF1E293B;
  static const int accentGreen = 0xFF10B981;
  static const int accentRed = 0xFFEF4444;
  static const int accentOrange = 0xFFF59E0B;
  static const int accentBlue = 0xFF3B82F6;
  static const int surfaceLight = 0xFFF8FAFC;
  static const int cardWhite = 0xFFFFFFFF;

  // ========== SUBSCRIPTION PLANS ==========
  static const Map<String, Map<String, dynamic>> plans = {
    'free': {
      'name_ar': 'مجاني',
      'name_en': 'Free',
      'price': 0,
      'users': 1,
      'invoices': 100,
      'warehouses': 1,
      'advanced_reports': false,
      'api': false,
      'branches': 1,
    },
    'starter': {
      'name_ar': 'Starter',
      'name_en': 'Starter',
      'price': 199,
      'users': 3,
      'invoices': 1000,
      'warehouses': 2,
      'advanced_reports': true,
      'api': false,
      'branches': 1,
    },
    'business': {
      'name_ar': 'Business',
      'name_en': 'Business',
      'price': 499,
      'users': 10,
      'invoices': -1, // unlimited
      'warehouses': 10,
      'advanced_reports': true,
      'api': true,
      'branches': 5,
    },
    'enterprise': {
      'name_ar': 'Enterprise',
      'name_en': 'Enterprise',
      'price': 999,
      'users': -1,
      'invoices': -1,
      'warehouses': -1,
      'advanced_reports': true,
      'api': true,
      'branches': -1,
      'vip_support': true,
      'custom_logo': true,
    },
  };

  // ========== ROLES ==========
  static const List<String> roles = [
    'admin',
    'cashier',
    'accountant',
    'warehouse',
    'sales',
    'hr',
  ];

  // ========== PAYMENT GATEWAYS ==========
  static const String paymobApiKey = 'YOUR_PAYMOB_API_KEY';
  static const String fawryMerchantCode = 'YOUR_FAWRY_CODE';
  static const String stripePublishableKey = 'YOUR_STRIPE_KEY';
}
