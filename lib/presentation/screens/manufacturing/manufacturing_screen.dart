import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/locale_provider.dart';

class ManufacturingScreen extends ConsumerWidget {
  const ManufacturingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.list_alt), label: Text(isAr ? 'قائمة المواد BOM' : 'Bill of Materials')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.precision_manufacturing), label: Text(isAr ? 'أمر تصنيع' : 'Work Order')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: Center(
                child: Text(
                  isAr
                      ? 'إدارة التصنيع — BOM، أوامر تصنيع، تكلفة المنتج'
                      : 'Manufacturing — BOM, Work Orders, Product Costing',
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
