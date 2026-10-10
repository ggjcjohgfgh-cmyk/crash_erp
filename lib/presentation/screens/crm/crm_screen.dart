import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';

class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add),
                label: Text(isAr ? 'عميل جديد' : 'New Customer'),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isAr ? 'بحث بالاسم أو الهاتف...' : 'Search name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(isAr ? 'الاسم' : 'Name')),
                    DataColumn(label: Text(isAr ? 'الهاتف' : 'Phone')),
                    DataColumn(label: Text(isAr ? 'الرصيد' : 'Balance')),
                    DataColumn(label: Text(isAr ? 'نقاط الولاء' : 'Loyalty')),
                    DataColumn(label: Text(isAr ? 'واتساب' : 'WhatsApp')),
                  ],
                  rows: List.generate(10, (i) {
                    return DataRow(cells: [
                      DataCell(Text(isAr ? 'عميل ${i + 1}' : 'Customer ${i + 1}')),
                      DataCell(Text('010${10000000 + i}')),
                      DataCell(Text(
                        '${i * 150}.00',
                        style: TextStyle(
                          color: i > 0
                              ? const Color(AppConstants.accentRed)
                              : const Color(AppConstants.accentGreen),
                        ),
                      )),
                      DataCell(Text('${i * 50}')),
                      DataCell(IconButton(
                        icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                        onPressed: () {},
                      )),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
