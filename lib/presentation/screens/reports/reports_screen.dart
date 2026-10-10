import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subscription_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final sub = ref.watch(subscriptionProvider);
    final hasAdvanced = sub.hasAdvancedReports;

    final reports = [
      (Icons.point_of_sale, isAr ? 'تقرير المبيعات' : 'Sales Report', true),
      (Icons.inventory, isAr ? 'تقرير المخزون' : 'Inventory Report', true),
      (Icons.people, isAr ? 'تقرير العملاء' : 'Customers Report', true),
      (Icons.shopping_cart, isAr ? 'تقرير المشتريات' : 'Purchases Report', true),
      (Icons.account_balance, isAr ? 'قائمة الأرباح والخسائر' : 'Profit & Loss', hasAdvanced),
      (Icons.balance, isAr ? 'ميزان المراجعة' : 'Trial Balance', hasAdvanced),
      (Icons.receipt_long, isAr ? 'التقرير الضريبي' : 'Tax Report', hasAdvanced),
      (Icons.trending_up, isAr ? 'تحليل المبيعات' : 'Sales Analytics', hasAdvanced),
      (Icons.warehouse, isAr ? 'حركة المخزون' : 'Stock Movement', hasAdvanced),
      (Icons.badge, isAr ? 'تقرير الرواتب' : 'Payroll Report', hasAdvanced),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'التقارير المتقدمة (+40 تقرير)' : 'Advanced Reports (+40)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!hasAdvanced)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(AppConstants.accentOrange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isAr
                    ? 'الترقية لخطة Starter أو أعلى لفتح التقارير المتقدمة'
                    : 'Upgrade to Starter+ to unlock advanced reports',
                style: const TextStyle(color: Color(AppConstants.accentOrange)),
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                childAspectRatio: 1.4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: reports.length,
              itemBuilder: (context, i) {
                final r = reports[i];
                final locked = !r.$3;
                return Card(
                  child: InkWell(
                    onTap: locked
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isAr ? 'جاري التصدير...' : 'Exporting...')),
                            );
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(r.$1,
                              size: 36,
                              color: locked
                                  ? Colors.grey
                                  : const Color(AppConstants.primaryDark)),
                          const SizedBox(height: 12),
                          Text(r.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: locked ? Colors.grey : null,
                              )),
                          if (locked)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Icon(Icons.lock, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
