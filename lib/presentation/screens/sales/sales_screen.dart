import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subscription_provider.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final sub = ref.watch(subscriptionProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: sub.canCreateInvoice()
                    ? () {
                        // Open POS / New Invoice
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isAr
                                ? 'فتح شاشة نقطة البيع...'
                                : 'Opening POS...'),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: Text(isAr ? 'فاتورة جديدة' : 'New Invoice'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(isAr ? 'تصدير PDF' : 'Export PDF'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.table_chart),
                label: Text(isAr ? 'تصدير Excel' : 'Export Excel'),
              ),
              const Spacer(),
              // Search
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isAr ? 'بحث في الفواتير...' : 'Search invoices...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: isAr ? 'الكل' : 'All', selected: true),
                _FilterChip(label: isAr ? 'مدفوعة' : 'Paid'),
                _FilterChip(label: isAr ? 'جزئي' : 'Partial'),
                _FilterChip(label: isAr ? 'آجل' : 'Credit'),
                _FilterChip(label: isAr ? 'مرتجع' : 'Returned'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(isAr ? 'رقم الفاتورة' : 'Invoice #')),
                    DataColumn(label: Text(isAr ? 'التاريخ' : 'Date')),
                    DataColumn(label: Text(isAr ? 'العميل' : 'Customer')),
                    DataColumn(label: Text(isAr ? 'الإجمالي' : 'Total')),
                    DataColumn(label: Text(isAr ? 'المدفوع' : 'Paid')),
                    DataColumn(label: Text(isAr ? 'الحالة' : 'Status')),
                    DataColumn(label: Text(isAr ? 'إجراءات' : 'Actions')),
                  ],
                  rows: List.generate(15, (i) {
                    return DataRow(cells: [
                      DataCell(Text('INV-${1000 + i}')),
                      DataCell(Text('2026-10-${(i % 28) + 1}')),
                      DataCell(Text(isAr ? 'عميل ${i + 1}' : 'Customer ${i + 1}')),
                      DataCell(Text('${(i + 1) * 350}.00')),
                      DataCell(Text('${(i + 1) * 350}.00')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentGreen)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isAr ? 'مدفوعة' : 'Paid',
                            style: const TextStyle(
                              color: Color(AppConstants.accentGreen),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print, size: 18),
                            onPressed: () {},
                            tooltip: isAr ? 'طباعة' : 'Print',
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 18),
                            onPressed: () {},
                          ),
                        ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {},
        selectedColor: const Color(AppConstants.accentGreen).withOpacity(0.2),
        checkmarkColor: const Color(AppConstants.accentGreen),
      ),
    );
  }
}
