import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

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
                icon: const Icon(Icons.add),
                label: Text(isAr ? 'منتج جديد' : 'New Product'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_horiz),
                label: Text(isAr ? 'تحويل مخزني' : 'Stock Transfer'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.inventory),
                label: Text(isAr ? 'جرد' : 'Stock Take'),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isAr ? 'بحث بالاسم أو الباركود...' : 'Search name or barcode...',
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
                    DataColumn(label: Text(isAr ? 'الباركود' : 'Barcode')),
                    DataColumn(label: Text(isAr ? 'المنتج' : 'Product')),
                    DataColumn(label: Text(isAr ? 'الكمية' : 'Qty')),
                    DataColumn(label: Text(isAr ? 'التكلفة' : 'Cost')),
                    DataColumn(label: Text(isAr ? 'السعر' : 'Price')),
                    DataColumn(label: Text(isAr ? 'الحد الأدنى' : 'Min Stock')),
                    DataColumn(label: Text(isAr ? 'الحالة' : 'Status')),
                  ],
                  rows: List.generate(12, (i) {
                    final low = i % 4 == 0;
                    return DataRow(cells: [
                      DataCell(Text('6223001${1000 + i}')),
                      DataCell(Text(isAr ? 'منتج رقم ${i + 1}' : 'Product ${i + 1}')),
                      DataCell(Text('${low ? 3 : 45 + i}')),
                      DataCell(Text('${50 + i * 10}.00')),
                      DataCell(Text('${80 + i * 15}.00')),
                      DataCell(Text('10')),
                      DataCell(
                        low
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(AppConstants.accentOrange)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isAr ? 'منخفض' : 'Low',
                                  style: const TextStyle(
                                    color: Color(AppConstants.accentOrange),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : const Text('—'),
                      ),
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
