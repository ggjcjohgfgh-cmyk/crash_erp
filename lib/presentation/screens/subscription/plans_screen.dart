import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subscription_provider.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final current = ref.watch(subscriptionProvider).plan;

    final plans = [
      _PlanData('free', isAr ? 'مجاني' : 'Free', 0, [
        isAr ? '1 مستخدم' : '1 User',
        isAr ? '100 فاتورة/شهر' : '100 Invoices/mo',
        isAr ? 'مستودع واحد' : '1 Warehouse',
        isAr ? 'بدون تقارير متقدمة' : 'No advanced reports',
      ], false),
      _PlanData('starter', 'Starter', 199, [
        isAr ? '3 مستخدمين' : '3 Users',
        isAr ? '1000 فاتورة/شهر' : '1000 Invoices/mo',
        isAr ? '2 مستودع' : '2 Warehouses',
        isAr ? 'تقارير متقدمة' : 'Advanced reports',
      ], true),
      _PlanData('business', 'Business', 499, [
        isAr ? '10 مستخدمين' : '10 Users',
        isAr ? 'فواتير غير محدودة' : 'Unlimited invoices',
        isAr ? 'كل الموديولات' : 'All modules',
        isAr ? 'API access' : 'API access',
      ], true),
      _PlanData('enterprise', 'Enterprise', 999, [
        isAr ? 'مستخدمين غير محدود' : 'Unlimited users',
        isAr ? 'فروع غير محدودة' : 'Unlimited branches',
        isAr ? 'دعم VIP' : 'VIP Support',
        isAr ? 'تخصيص لوجو' : 'Custom logo',
      ], true),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'خطط الاشتراك — Crash ERP SaaS' : 'Subscription Plans — Crash ERP SaaS',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'اختر الخطة المناسبة لنمو أعمالك'
                : 'Choose the plan that fits your business growth',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final cross = constraints.maxWidth > 1100
                  ? 4
                  : constraints.maxWidth > 700
                      ? 2
                      : 1;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: plans.length,
                itemBuilder: (context, i) {
                  final p = plans[i];
                  final isCurrent = current == p.id;
                  final isPopular = p.id == 'business';
                  return Card(
                    elevation: isPopular ? 6 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isPopular
                          ? const BorderSide(
                              color: Color(AppConstants.accentGreen), width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.accentGreen),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isAr ? 'الأكثر شيوعاً' : 'Most Popular',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          if (isPopular) const SizedBox(height: 12),
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                p.price == 0 ? (isAr ? 'مجاناً' : 'Free') : '${p.price}',
                                style: const TextStyle(
                                    fontSize: 36, fontWeight: FontWeight.bold),
                              ),
                              if (p.price > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? 'ج.م/شهر' : 'EGP/mo',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 14),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          ...p.features.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        size: 18,
                                        color: Color(AppConstants.accentGreen)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              )),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isCurrent
                                  ? null
                                  : () {
                                      // Integrate Paymob / Fawry / Stripe here
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isAr
                                              ? 'جاري التحويل لبوابة الدفع...'
                                              : 'Redirecting to payment gateway...'),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCurrent
                                    ? Colors.grey
                                    : isPopular
                                        ? const Color(AppConstants.accentGreen)
                                        : const Color(AppConstants.primaryDark),
                              ),
                              child: Text(
                                isCurrent
                                    ? (isAr ? 'الخطة الحالية' : 'Current Plan')
                                    : (isAr ? 'اشترك الآن' : 'Subscribe'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PlanData {
  final String id;
  final String name;
  final int price;
  final List<String> features;
  final bool paid;
  const _PlanData(this.id, this.name, this.price, this.features, this.paid);
}
