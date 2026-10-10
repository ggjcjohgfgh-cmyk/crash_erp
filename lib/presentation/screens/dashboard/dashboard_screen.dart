import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../sales/sales_screen.dart';
import '../inventory/inventory_screen.dart';
import '../purchases/purchases_screen.dart';
import '../crm/crm_screen.dart';
import '../finance/finance_screen.dart';
import '../hr/hr_screen.dart';
import '../manufacturing/manufacturing_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../barcode/barcode_screen.dart';
import '../subscription/plans_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_rounded, 'لوحة التحكم', 'Dashboard'),
    _NavItem(Icons.point_of_sale_rounded, 'المبيعات', 'Sales'),
    _NavItem(Icons.inventory_2_rounded, 'المخزون', 'Inventory'),
    _NavItem(Icons.shopping_cart_rounded, 'المشتريات', 'Purchases'),
    _NavItem(Icons.people_rounded, 'العملاء', 'CRM'),
    _NavItem(Icons.account_balance_wallet_rounded, 'المالية', 'Finance'),
    _NavItem(Icons.badge_rounded, 'الموظفين', 'HR'),
    _NavItem(Icons.precision_manufacturing_rounded, 'التصنيع', 'Manufacturing'),
    _NavItem(Icons.bar_chart_rounded, 'التقارير', 'Reports'),
    _NavItem(Icons.qr_code_rounded, 'الباركود', 'Barcode'),
    _NavItem(Icons.settings_rounded, 'الإعدادات', 'Settings'),
    _NavItem(Icons.workspace_premium_rounded, 'الاشتراك', 'Subscription'),
  ];

  @override
  Widget build(BuildContext context) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(AppConstants.surfaceLight),
      body: Row(
        children: [
          // Side Navigation (Desktop/Web)
          if (isWide)
            Container(
              width: 260,
              color: const Color(AppConstants.primaryDark),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentGreen),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Crash ERP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navItems.length,
                      itemBuilder: (context, i) {
                        final item = _navItems[i];
                        final selected = _selectedIndex == i;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          child: Material(
                            color: selected
                                ? const Color(AppConstants.accentGreen)
                                    .withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              leading: Icon(
                                item.icon,
                                color: selected
                                    ? const Color(AppConstants.accentGreen)
                                    : Colors.white70,
                              ),
                              title: Text(
                                isAr ? item.labelAr : item.labelEn,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(AppConstants.accentGreen)
                                      : Colors.white70,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: selected,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              onTap: () => setState(() => _selectedIndex = i),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Logout
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white54),
                      title: Text(
                        isAr ? 'تسجيل الخروج' : 'Logout',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () =>
                          ref.read(authControllerProvider).signOut(),
                    ),
                  ),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!isWide)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            // Mobile drawer
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => _MobileNav(
                                items: _navItems,
                                selected: _selectedIndex,
                                isAr: isAr,
                                onSelect: (i) {
                                  setState(() => _selectedIndex = i);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      Text(
                        isAr
                            ? _navItems[_selectedIndex].labelAr
                            : _navItems[_selectedIndex].labelEn,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      // Plan badge
                      Consumer(builder: (context, ref, _) {
                        final sub = ref.watch(subscriptionProvider);
                        return Chip(
                          avatar: const Icon(Icons.workspace_premium,
                              size: 16, color: Color(AppConstants.accentOrange)),
                          label: Text(
                            sub.plan.toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor:
                              const Color(AppConstants.accentOrange)
                                  .withOpacity(0.1),
                        );
                      }),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.language),
                        onPressed: () =>
                            ref.read(localeProvider.notifier).toggle(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _buildContent(_selectedIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const _DashboardHome();
      case 1:
        return const SalesScreen();
      case 2:
        return const InventoryScreen();
      case 3:
        return const PurchasesScreen();
      case 4:
        return const CrmScreen();
      case 5:
        return const FinanceScreen();
      case 6:
        return const HrScreen();
      case 7:
        return const ManufacturingScreen();
      case 8:
        return const ReportsScreen();
      case 9:
        return const BarcodeScreen();
      case 10:
        return const SettingsScreen();
      case 11:
        return const PlansScreen();
      default:
        return const _DashboardHome();
    }
  }
}

class _NavItem {
  final IconData icon;
  final String labelAr;
  final String labelEn;
  const _NavItem(this.icon, this.labelAr, this.labelEn);
}

class _MobileNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selected;
  final bool isAr;
  final ValueChanged<int> onSelect;

  const _MobileNav({
    required this.items,
    required this.selected,
    required this.isAr,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return ListTile(
          leading: Icon(item.icon),
          title: Text(isAr ? item.labelAr : item.labelEn),
          selected: selected == i,
          onTap: () => onSelect(i),
        );
      },
    );
  }
}

// ==================== DASHBOARD HOME ====================
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          LayoutBuilder(builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 1100
                ? 4
                : constraints.maxWidth > 700
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: const [
                _KpiCard(
                  title: 'مبيعات اليوم',
                  value: '12,450',
                  unit: 'ج.م',
                  icon: Icons.trending_up,
                  color: Color(AppConstants.accentGreen),
                  change: '+12.5%',
                ),
                _KpiCard(
                  title: 'الأرباح',
                  value: '3,820',
                  unit: 'ج.م',
                  icon: Icons.attach_money,
                  color: Color(AppConstants.accentBlue),
                  change: '+8.2%',
                ),
                _KpiCard(
                  title: 'مخزون منخفض',
                  value: '7',
                  unit: 'منتج',
                  icon: Icons.warning_amber_rounded,
                  color: Color(AppConstants.accentOrange),
                  change: 'تنبيه',
                ),
                _KpiCard(
                  title: 'فواتير اليوم',
                  value: '48',
                  unit: 'فاتورة',
                  icon: Icons.receipt_long,
                  color: Color(0xFF8B5CF6),
                  change: '+5',
                ),
              ],
            );
          }),
          const SizedBox(height: 32),

          // Charts Row
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _SalesChart()),
                  const SizedBox(width: 16),
                  Expanded(child: _TopProducts()),
                ],
              );
            }
            return Column(
              children: [
                _SalesChart(),
                const SizedBox(height: 16),
                _TopProducts(),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String change;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text(unit,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
            ),
            Text(change,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مبيعات آخر 7 أيام',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: const Color(0xFFE2E8F0),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = ['س', 'أ', 'ث', 'أ', 'خ', 'ج', 'س'];
                          final i = v.toInt();
                          if (i >= 0 && i < days.length) {
                            return Text(days[i],
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8)));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 8),
                        FlSpot(1, 12),
                        FlSpot(2, 9),
                        FlSpot(3, 15),
                        FlSpot(4, 11),
                        FlSpot(5, 18),
                        FlSpot(6, 14),
                      ],
                      isCurved: true,
                      color: const Color(AppConstants.accentGreen),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(AppConstants.accentGreen)
                            .withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final products = [
      ('منتج أ', 2450),
      ('منتج ب', 1890),
      ('منتج ج', 1420),
      ('منتج د', 980),
      ('منتج هـ', 760),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أكثر المنتجات مبيعاً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...products.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.$1)),
                      Text('${p.$2} ج.م',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(AppConstants.accentGreen))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
