import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/locale_provider.dart';

class HrScreen extends ConsumerWidget {
  const HrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.person_add), label: Text(isAr ? 'موظف جديد' : 'New Employee')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.access_time), label: Text(isAr ? 'حضور وانصراف' : 'Attendance')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.payments), label: Text(isAr ? 'الرواتب' : 'Payroll')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: Center(
                child: Text(
                  isAr
                      ? 'إدارة الموظفين — حضور، رواتب، سلف، عمولات مبيعات'
                      : 'HR — Attendance, Payroll, Advances, Sales Commissions',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
