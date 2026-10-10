import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/locale_provider.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

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
                label: Text(isAr ? 'أمر شراء' : 'Purchase Order'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.receipt),
                label: Text(isAr ? 'فاتورة مورد' : 'Supplier Invoice'),
              ),
              const Spacer(),
              SizedBox(
                width: 240,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isAr ? 'بحث...' : 'Search...',
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
              child: Center(
                child: Text(
                  isAr
                      ? 'إدارة المشتريات والموردين — أوامر شراء، فواتير، مرتجعات'
                      : 'Purchases & Suppliers — POs, Invoices, Returns',
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
