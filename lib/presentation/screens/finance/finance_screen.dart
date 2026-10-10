import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'الشؤون المالية والمحاسبة' : 'Finance & Accounting',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 800 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _FinanceCard(Icons.account_balance_wallet, isAr ? 'الخزينة' : 'Cash Box', '45,200 ج.م', const Color(AppConstants.accentGreen)),
                _FinanceCard(Icons.account_balance, isAr ? 'البنوك' : 'Banks', '128,500 ج.م', const Color(AppConstants.accentBlue)),
                _FinanceCard(Icons.money_off, isAr ? 'المصروفات' : 'Expenses', '12,300 ج.م', const Color(AppConstants.accentRed)),
                _FinanceCard(Icons.trending_up, isAr ? 'الإيرادات' : 'Income', '89,400 ج.م', const Color(0xFF8B5CF6)),
              ],
            );
          }),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.book), label: Text(isAr ? 'قيود يومية' : 'Journal Entries')),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.balance), label: Text(isAr ? 'ميزان مراجعة' : 'Trial Balance')),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.assessment), label: Text(isAr ? 'قائمة الأرباح والخسائر' : 'P&L Statement')),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.receipt_long), label: Text(isAr ? 'تقارير ضريبية' : 'Tax Reports')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _FinanceCard(this.icon, this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
