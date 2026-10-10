import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/supabase_client.dart';

class SubscriptionState {
  final String plan;
  final DateTime? expiresAt;
  final bool isActive;
  final int usersUsed;
  final int invoicesUsed;
  final int warehousesUsed;

  const SubscriptionState({
    this.plan = 'free',
    this.expiresAt,
    this.isActive = true,
    this.usersUsed = 1,
    this.invoicesUsed = 0,
    this.warehousesUsed = 1,
  });

  bool get isExpired {
    if (plan == 'free') return false;
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isLocked => isExpired || !isActive;

  Map<String, dynamic> get planLimits => AppConstants.plans[plan] ?? AppConstants.plans['free']!;

  bool canCreateInvoice() {
    if (isLocked) return false;
    final max = planLimits['invoices'] as int;
    if (max == -1) return true;
    return invoicesUsed < max;
  }

  bool canAddUser() {
    if (isLocked) return false;
    final max = planLimits['users'] as int;
    if (max == -1) return true;
    return usersUsed < max;
  }

  bool canAddWarehouse() {
    if (isLocked) return false;
    final max = planLimits['warehouses'] as int;
    if (max == -1) return true;
    return warehousesUsed < max;
  }

  bool get hasAdvancedReports => planLimits['advanced_reports'] == true;
  bool get hasApi => planLimits['api'] == true;

  SubscriptionState copyWith({
    String? plan,
    DateTime? expiresAt,
    bool? isActive,
    int? usersUsed,
    int? invoicesUsed,
    int? warehousesUsed,
  }) {
    return SubscriptionState(
      plan: plan ?? this.plan,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      usersUsed: usersUsed ?? this.usersUsed,
      invoicesUsed: invoicesUsed ?? this.invoicesUsed,
      warehousesUsed: warehousesUsed ?? this.warehousesUsed,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState()) {
    _loadFromCache();
  }

  void _loadFromCache() {
    final box = Hive.box(AppConstants.settingsBox);
    final plan = box.get('plan', defaultValue: 'free') as String;
    final expires = box.get('plan_expires') as String?;
    state = SubscriptionState(
      plan: plan,
      expiresAt: expires != null ? DateTime.tryParse(expires) : null,
      isActive: true,
    );
  }

  Future<void> loadFromServer(String companyId) async {
    try {
      final data = await SupabaseService.from('companies')
          .select('plan, plan_expires_at')
          .eq('id', companyId)
          .single();

      final plan = data['plan'] as String? ?? 'free';
      final expires = data['plan_expires_at'] != null
          ? DateTime.parse(data['plan_expires_at'])
          : null;

      final box = Hive.box(AppConstants.settingsBox);
      box.put('plan', plan);
      if (expires != null) box.put('plan_expires', expires.toIso8601String());

      state = state.copyWith(plan: plan, expiresAt: expires);
    } catch (_) {
      // keep cached
    }
  }

  Future<void> upgradePlan(String newPlan, DateTime expiresAt) async {
    final box = Hive.box(AppConstants.settingsBox);
    box.put('plan', newPlan);
    box.put('plan_expires', expiresAt.toIso8601String());
    state = state.copyWith(plan: newPlan, expiresAt: expiresAt, isActive: true);
  }

  void incrementInvoiceCount() {
    state = state.copyWith(invoicesUsed: state.invoicesUsed + 1);
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});
