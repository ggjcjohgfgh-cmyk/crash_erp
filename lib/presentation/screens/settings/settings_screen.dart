import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(isAr ? 'الإعدادات العامة' : 'General Settings',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          _SettingsTile(Icons.business, isAr ? 'بيانات الشركة' : 'Company Info', isAr ? 'الاسم، الضريبة، اللوجو' : 'Name, Tax, Logo'),
          _SettingsTile(Icons.currency_exchange, isAr ? 'العملات' : 'Currencies', isAr ? 'متعدد العملات' : 'Multi-currency'),
          _SettingsTile(Icons.percent, isAr ? 'الضرائب' : 'Taxes', isAr ? 'ضريبة القيمة المضافة وغيرها' : 'VAT & others'),
          _SettingsTile(Icons.people, isAr ? 'المستخدمين والصلاحيات' : 'Users & Roles', isAr ? 'Admin, Cashier, Accountant...' : 'Role-Based Access'),
          _SettingsTile(Icons.print, isAr ? 'الطابعات' : 'Printers', isAr ? 'حرارية 58mm / 80mm' : 'Thermal 58/80mm'),
          _SettingsTile(Icons.language, isAr ? 'اللغة' : 'Language', isAr ? 'عربي / English' : 'Arabic / English',
              onTap: () => ref.read(localeProvider.notifier).toggle()),
          _SettingsTile(Icons.sync, isAr ? 'المزامنة Offline' : 'Offline Sync', isAr ? 'يعمل بدون نت' : 'Works offline'),
          const SizedBox(height: 24),
          Card(
            color: const Color(AppConstants.primaryDark),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Crash ERP v1.0.0',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    isAr ? 'نظام سحابي متكامل — SaaS' : 'Cloud SaaS ERP System',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsTile(this.icon, this.title, this.subtitle, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(AppConstants.primaryDark)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
