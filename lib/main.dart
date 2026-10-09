// Crash ERP - single-file Flutter app (Riverpod + Hive offline-first + Supabase)
// Edit kSupabaseUrl / kSupabaseKey below (or pass --dart-define) to enable cloud sync.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:excel/excel.dart' as xl;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

// ============================ CONFIG ============================
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'YOUR_SUPABASE_URL');
const kSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR_SUPABASE_ANON_KEY');
final bool cloudReady = !kSupabaseUrl.startsWith('YOUR_');
SupabaseClient? get sb => cloudReady ? Supabase.instance.client : null;

const navy = Color(0xFF0F172A);
const green = Color(0xFF10B981);

// ============================ MAIN ============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  const ss = FlutterSecureStorage();
  var k = await ss.read(key: 'crash_hive_key');
  if (k == null) {
    k = base64UrlEncode(Hive.generateSecureKey());
    await ss.write(key: 'crash_hive_key', value: k);
  }
  final cipher = HiveAesCipher(base64Url.decode(k));
  for (final b in ['settings', 'data', 'queue']) {
    await Hive.openBox(b, encryptionCipher: cipher);
  }
  if (cloudReady) {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseKey);
  }
  runApp(const ProviderScope(child: CrashApp()));
}

// ============================ STATE ============================
extension Tr on Map<String, dynamic> {
  String t(String ar, String en) => this['lang'] == 'ar' ? ar : en;
}

class SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  SettingsNotifier() : super(_load());
  static Map<String, dynamic> _load() {
    final b = Hive.box('settings');
    const d = <String, dynamic>{
      'lang': 'ar', 'plan': 'free', 'role': 'admin', 'company': 'Crash ERP',
      'currency': 'EGP', 'tax': 14.0, 'expires': '', 'taxid': '',
    };
    d.forEach((k, v) {
      if (!b.containsKey(k)) b.put(k, v);
    });
    return {for (final k in b.keys) '$k': b.get(k)};
  }

  void setAll(Map<String, dynamic> m) {
    Hive.box('settings').putAll(m);
    state = {...state, ...m};
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Map<String, dynamic>>((ref) => SettingsNotifier());
final navProvider = StateProvider<String>((ref) => 'dashboard');

// ============================ HELPERS ============================
double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _f(dynamic v) {
  if (v == null) return '';
  if (v is num) return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  return '$v';
}

String _today() => DateTime.now().toIso8601String().substring(0, 10);
void _snack(BuildContext c, String m, {SnackBarAction? action}) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), action: action));

// ============================ PLANS ============================
class Plan {
  final String id, ar, en;
  final int price, users, invoices, warehouses, rank;
  final bool adv, api, vip;
  const Plan(this.id, this.ar, this.en, this.price, this.users, this.invoices, this.warehouses,
      this.rank, this.adv, this.api, this.vip);
}

const plans = [
  Plan('free', 'مجانية', 'Free', 0, 1, 100, 1, 0, false, false, false),
  Plan('starter', 'Starter', 'Starter', 199, 3, 1000, 2, 1, false, false, false),
  Plan('business', 'Business', 'Business', 499, 10, -1, -1, 2, true, true, false),
  Plan('enterprise', 'Enterprise', 'Enterprise', 999, -1, -1, -1, 3, true, true, true),
];

/// Active plan; falls back to Free when the subscription expired (locks features).
Plan effectivePlan(Map<String, dynamic> s) {
  final p = plans.firstWhere((e) => e.id == s['plan'], orElse: () => plans[0]);
  if (p.id == 'free') return p;
  final ex = DateTime.tryParse('${s['expires']}');
  return (ex != null && ex.isAfter(DateTime.now())) ? p : plans[0];
}

// ============================ TABLE DEFINITIONS ============================
class F {
  final String k, ar, en;
  final bool num;
  const F(this.k, this.ar, this.en, [this.num = false]);
}

class TableDef {
  final String table, ar, en;
  final List<F> fields;
  final bool wa;
  const TableDef(this.table, this.ar, this.en, this.fields, [this.wa = false]);
}

const tInvoices = TableDef('invoices', 'الفواتير', 'Invoices', [
  F('number', 'الرقم', 'No.'), F('customer', 'العميل', 'Customer'), F('total', 'الإجمالي', 'Total', true),
  F('tax', 'الضريبة', 'Tax', true), F('discount', 'الخصم', 'Discount', true),
  F('payment_method', 'الدفع', 'Payment'), F('kind', 'النوع', 'Kind'), F('date', 'التاريخ', 'Date'),
]);
const tProducts = TableDef('products', 'المنتجات', 'Products', [
  F('name', 'الاسم', 'Name'), F('barcode', 'الباركود', 'Barcode'), F('sku', 'SKU', 'SKU'),
  F('price', 'سعر البيع', 'Price', true), F('cost', 'التكلفة', 'Cost', true),
  F('stock', 'الكمية', 'Stock', true), F('min_stock', 'حد الطلب', 'Reorder', true),
  F('warehouse', 'المستودع', 'Warehouse'), F('serial', 'Serial', 'Serial'),
]);
const tWarehouses = TableDef('warehouses', 'المستودعات', 'Warehouses',
    [F('name', 'الاسم', 'Name'), F('location', 'الموقع', 'Location')]);
const tTransfers = TableDef('stock_transfers', 'التحويلات', 'Transfers', [
  F('product', 'المنتج', 'Product'), F('from_wh', 'من', 'From'), F('to_wh', 'إلى', 'To'),
  F('qty', 'الكمية', 'Qty', true), F('date', 'التاريخ', 'Date'),
]);
const tSuppliers = TableDef('suppliers', 'الموردون', 'Suppliers', [
  F('name', 'الاسم', 'Name'), F('phone', 'الهاتف', 'Phone'), F('balance', 'الرصيد', 'Balance', true),
]);
const tPO = TableDef('purchase_orders', 'أوامر الشراء', 'Purchase orders', [
  F('supplier', 'المورد', 'Supplier'), F('total', 'الإجمالي', 'Total', true),
  F('status', 'الحالة', 'Status'), F('date', 'التاريخ', 'Date'),
]);
const tCustomers = TableDef('customers', 'العملاء', 'Customers', [
  F('name', 'الاسم', 'Name'), F('phone', 'الهاتف', 'Phone'), F('email', 'البريد', 'Email'),
  F('balance', 'المديونية', 'Balance', true), F('points', 'النقاط', 'Points', true),
], true);
const tExpenses = TableDef('expenses', 'مصروفات وإيرادات', 'Expenses & income', [
  F('title', 'البيان', 'Title'), F('amount', 'المبلغ', 'Amount', true),
  F('kind', 'النوع (expense/income)', 'Kind (expense/income)'), F('account', 'الحساب', 'Account'),
  F('date', 'التاريخ', 'Date'),
]);
const tJournal = TableDef('journal_entries', 'قيود اليومية', 'Journal', [
  F('date', 'التاريخ', 'Date'), F('description', 'البيان', 'Description'),
  F('debit_account', 'مدين', 'Debit'), F('credit_account', 'دائن', 'Credit'),
  F('amount', 'المبلغ', 'Amount', true),
]);
const tEmployees = TableDef('employees', 'الموظفون', 'Employees', [
  F('name', 'الاسم', 'Name'), F('job', 'الوظيفة', 'Job'), F('salary', 'الراتب', 'Salary', true),
  F('commission_pct', 'عمولة %', 'Commission %', true),
]);
const tAttendance = TableDef('attendance', 'الحضور', 'Attendance', [
  F('employee', 'الموظف', 'Employee'), F('date', 'التاريخ', 'Date'),
  F('check_in', 'حضور', 'In'), F('check_out', 'انصراف', 'Out'),
]);
const tBoms = TableDef('boms', 'التصنيع BOM', 'Manufacturing BOM', [
  F('product', 'المنتج', 'Product'), F('components', 'المكونات', 'Components'),
  F('cost', 'التكلفة', 'Cost', true),
]);
const allTables = [
  tInvoices, tProducts, tWarehouses, tTransfers, tSuppliers, tPO,
  tCustomers, tExpenses, tJournal, tEmployees, tAttendance, tBoms,
];
final tableDefs = {for (final t in allTables) t.table: t};

class ModuleDef {
  final String id, ar, en;
  final IconData icon;
  final Set<String> roles;
  final int rank;
  final List<TableDef> tabs;
  const ModuleDef(this.id, this.ar, this.en, this.icon, this.roles, [this.rank = 0, this.tabs = const []]);
}

const _all = {'admin', 'cashier', 'accountant', 'storekeeper'};
const modules = [
  ModuleDef('dashboard', 'لوحة التحكم', 'Dashboard', Icons.dashboard, _all),
  ModuleDef('sales', 'المبيعات والفواتير', 'Sales & invoices', Icons.receipt_long, {'admin', 'cashier', 'accountant'}),
  ModuleDef('inventory', 'المخزون', 'Inventory', Icons.inventory_2, {'admin', 'storekeeper', 'accountant'}, 0, [tProducts, tWarehouses, tTransfers]),
  ModuleDef('purchases', 'المشتريات', 'Purchases', Icons.shopping_cart, {'admin', 'storekeeper', 'accountant'}, 0, [tSuppliers, tPO]),
  ModuleDef('crm', 'العملاء CRM', 'CRM', Icons.people, {'admin', 'cashier', 'accountant'}, 0, [tCustomers]),
  ModuleDef('finance', 'المالية والمحاسبة', 'Finance', Icons.account_balance, {'admin', 'accountant'}, 0, [tExpenses, tJournal]),
  ModuleDef('hr', 'الموظفون والرواتب', 'HR & payroll', Icons.badge, {'admin'}, 2, [tEmployees, tAttendance]),
  ModuleDef('mfg', 'التصنيع', 'Manufacturing', Icons.precision_manufacturing, {'admin', 'storekeeper'}, 2, [tBoms]),
  ModuleDef('reports', 'التقارير', 'Reports', Icons.bar_chart, {'admin', 'accountant'}, 1),
  ModuleDef('barcode', 'الباركود', 'Barcode', Icons.qr_code_scanner, {'admin', 'cashier', 'storekeeper'}),
  ModuleDef('plans', 'الاشتراكات', 'Plans', Icons.workspace_premium, _all),
  ModuleDef('settings', 'الإعدادات', 'Settings', Icons.settings, {'admin'}),
];

// ============================ OFFLINE-FIRST REPO ============================
class Repo {
  static Box get _d => Hive.box('data');
  static Box get _q => Hive.box('queue');
  static bool _syncing = false;

  static List<Map<String, dynamic>> list(String t) {
    final raw = _d.get(t);
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> upsert(String t, Map<String, dynamic> row) async {
    final rows = list(t);
    row['id'] ??= const Uuid().v4();
    final i = rows.indexWhere((r) => r['id'] == row['id']);
    if (i >= 0) {
      rows[i] = row;
    } else {
      rows.insert(0, row);
    }
    await _d.put(t, rows);
    await _q.add({'op': 'upsert', 'table': t, 'row': row});
    unawaited(sync());
  }

  static Future<void> remove(String t, String id) async {
    final rows = list(t)..removeWhere((r) => r['id'] == id);
    await _d.put(t, rows);
    await _q.add({'op': 'delete', 'table': t, 'row': {'id': id}});
    unawaited(sync());
  }

  static int pending() => _q.length;

  /// Pushes the offline queue to Supabase (runs again whenever data changes / every 30s).
  static Future<void> sync() async {
    final c = sb;
    if (c == null || c.auth.currentUser == null || _syncing) return;
    _syncing = true;
    try {
      for (final k in _q.keys.toList()) {
        final e = Map<String, dynamic>.from(_q.get(k) as Map);
        final row = Map<String, dynamic>.from(e['row'] as Map);
        if (e['op'] == 'upsert') {
          await c.from(e['table'] as String).upsert(row);
        } else {
          await c.from(e['table'] as String).delete().eq('id', row['id']);
        }
        await _q.delete(k);
      }
    } catch (_) {
      // offline or server error: keep the queue, retry later
    } finally {
      _syncing = false;
    }
  }

  static Future<void> pull() async {
    final c = sb;
    if (c == null || c.auth.currentUser == null || _q.isNotEmpty) return;
    try {
      for (final t in allTables) {
        final r = await c.from(t.table).select();
        await _d.put(t.table, (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }
}

// ============================ EXPORT (PDF / EXCEL) ============================
Future<pw.Font?> _font() async {
  try {
    return await PdfGoogleFonts.cairoRegular();
  } catch (_) {
    return null;
  }
}

Future<Uint8List> tablePdf(Map<String, dynamic> s, String title, List<String> heads, List<List<String>> rows) async {
  final f = await _font();
  final doc = pw.Document(theme: f != null ? pw.ThemeData.withFont(base: f, bold: f) : null);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: s['lang'] == 'ar' ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    build: (c) => [
      pw.Text('${s['company']} - $title', style: const pw.TextStyle(fontSize: 18)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(headers: heads, data: rows, cellStyle: const pw.TextStyle(fontSize: 9)),
    ],
  ));
  return doc.save();
}

Future<void> exportPdf(Map<String, dynamic> s, String title, List<String> heads, List<List<String>> rows) async {
  final bytes = await tablePdf(s, title, heads, rows);
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: title);
}

Future<void> exportExcel(String name, List<String> heads, List<List<String>> rows) async {
  final ex = xl.Excel.createExcel();
  final sh = ex['Sheet1'];
  sh.appendRow(heads.map((e) => xl.TextCellValue(e)).toList());
  for (final r in rows) {
    sh.appendRow(r.map((e) => xl.TextCellValue(e)).toList());
  }
  final bytes = ex.encode();
  if (bytes == null) return;
  if (kIsWeb) {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: '$name.xlsx');
    return;
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.xlsx');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)]);
}

Widget exportButtons(BuildContext context, Map<String, dynamic> s, String title,
    (List<String>, List<List<String>>) Function() data) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(
      tooltip: 'PDF',
      icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
      onPressed: () {
        final d = data();
        exportPdf(s, title, d.$1, d.$2);
      },
    ),
    IconButton(
      tooltip: 'Excel',
      icon: const Icon(Icons.table_chart, color: green),
      onPressed: () {
        final d = data();
        exportExcel(title.replaceAll(' ', '_'), d.$1, d.$2);
      },
    ),
  ]);
}

// ---- Tax invoice receipt (58mm / 80mm thermal / A4) with TLV QR ----
String _tlv(List<String> parts) {
  final b = BytesBuilder();
  for (var i = 0; i < parts.length; i++) {
    final v = utf8.encode(parts[i]);
    b.add([i + 1, min(v.length, 255)]);
    b.add(v.take(255).toList());
  }
  return base64.encode(b.toBytes());
}

Future<Uint8List> receiptPdf(Map<String, dynamic> inv, Map<String, dynamic> s, PdfPageFormat fmt) async {
  final f = await _font();
  final doc = pw.Document(theme: f != null ? pw.ThemeData.withFont(base: f, bold: f) : null);
  final fs = fmt.width < 200 ? 7.0 : (fmt.width < 300 ? 9.0 : 12.0);
  final items = ((inv['items'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final total = _n(inv['total']), tax = _n(inv['tax']);
  final qr = _tlv([
    '${s['company']}', '${s['taxid']}', DateTime.now().toIso8601String(),
    total.toStringAsFixed(2), tax.toStringAsFixed(2),
  ]);
  pw.Widget row(String a, String b, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(child: pw.Text(a, style: pw.TextStyle(fontSize: fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(b, style: pw.TextStyle(fontSize: fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );
  doc.addPage(pw.Page(
    pageFormat: fmt,
    margin: pw.EdgeInsets.all(fmt.width > 400 ? 32 : 6),
    textDirection: s['lang'] == 'ar' ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text('${s['company']}', style: pw.TextStyle(fontSize: fs + 3, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text(inv['kind'] == 'return' ? (s.t('فاتورة مرتجع', 'Return invoice')) : (s.t('فاتورة ضريبية', 'Tax invoice')), style: pw.TextStyle(fontSize: fs))),
      if ('${s['taxid']}'.isNotEmpty) pw.Center(child: pw.Text('${s.t('الرقم الضريبي', 'Tax ID')}: ${s['taxid']}', style: pw.TextStyle(fontSize: fs))),
      pw.Divider(),
      row('${inv['number']}', '${inv['date']}'),
      row(s.t('العميل', 'Customer'), '${inv['customer'] ?? ''}'),
      pw.Divider(),
      for (final i in items) row('${i['name']} x${_f(i['qty'])}', _f(_n(i['qty']) * _n(i['price']))),
      pw.Divider(),
      row(s.t('الخصم', 'Discount'), _f(inv['discount'])),
      row(s.t('الضريبة', 'Tax'), _f(tax)),
      row(s.t('الإجمالي', 'Total'), '${_f(total)} ${s['currency']}', bold: true),
      row(s.t('الدفع', 'Payment'), '${inv['payment_method']}'),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.BarcodeWidget(barcode: Barcode.qrCode(), data: qr, width: 70, height: 70)),
      pw.SizedBox(height: 4),
      pw.Center(child: pw.BarcodeWidget(barcode: Barcode.code128(), data: '${inv['number']}', width: 120, height: 28, drawText: false)),
    ]),
  ));
  return doc.save();
}

// ============================ APP ============================
class CrashApp extends ConsumerWidget {
  const CrashApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Crash ERP',
      debugShowCheckedModeBanner: false,
      locale: Locale(s['lang'] as String),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: green),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
        cardTheme: const CardTheme(color: Colors.white, elevation: 1),
      ),
      home: const Gate(),
    );
  }
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) {
    if (!cloudReady) return const Shell();
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (c, _) => Supabase.instance.client.auth.currentSession != null ? const Shell() : const LoginScreen(),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> _go(bool signUp) async {
    setState(() { busy = true; err = null; });
    try {
      final a = Supabase.instance.client.auth;
      if (signUp) {
        await a.signUp(email: email.text.trim(), password: pass.text);
      } else {
        await a.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } catch (e) {
      err = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: navy,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt, size: 56, color: green),
                const Text('Crash ERP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: navy)),
                const SizedBox(height: 16),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s.t('البريد الإلكتروني', 'Email'), border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: s.t('كلمة المرور', 'Password'), border: const OutlineInputBorder())),
                if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : () => _go(false), child: Text(s.t('دخول', 'Sign in')))),
                TextButton(onPressed: busy ? null : () => _go(true), child: Text(s.t('إنشاء حساب جديد (خطة مجانية)', 'Create account (free plan)'))),
                TextButton(
                  onPressed: () => ref.read(settingsProvider.notifier).setAll({'lang': s['lang'] == 'ar' ? 'en' : 'ar'}),
                  child: const Text('العربية / English'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================ SHELL / NAVIGATION ============================
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _cycle();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _cycle());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _cycle() async {
    await Repo.sync();
    await Repo.pull();
    await _meta();
  }

  /// Reads role + subscription from the server (the server is the source of truth).
  Future<void> _meta() async {
    final c = sb;
    if (c == null || c.auth.currentUser == null) return;
    try {
      final m = await c.from('org_members').select('role').eq('user_id', c.auth.currentUser!.id).maybeSingle();
      final sub = await c.from('subscriptions').select().maybeSingle();
      final up = <String, dynamic>{};
      if (m != null) up['role'] = m['role'];
      if (sub != null) {
        up['plan'] = sub['plan'];
        up['expires'] = sub['expires_at'] ?? '';
      }
      if (up.isNotEmpty && mounted) ref.read(settingsProvider.notifier).setAll(up);
    } catch (_) {}
  }

  Widget _body(ModuleDef m, Map<String, dynamic> s) {
    if (effectivePlan(s).rank < m.rank) return Locked(m);
    switch (m.id) {
      case 'dashboard': return const Dashboard();
      case 'sales': return const SalesScreen();
      case 'reports': return const ReportsScreen();
      case 'barcode': return const BarcodeScreen();
      case 'settings': return const SettingsScreen();
      case 'plans': return const PlansScreen();
      default: return TabsScreen(m.tabs, key: ValueKey(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final vis = modules.where((m) => m.roles.contains(s['role'])).toList();
    final cur = vis.firstWhere((m) => m.id == ref.watch(navProvider), orElse: () => vis.first);
    final wide = MediaQuery.of(context).size.width >= 900;

    Widget menu(bool drawer) => ListView(children: [
          Container(
            color: navy,
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Row(children: [
              const Icon(Icons.bolt, color: green, size: 32),
              const SizedBox(width: 8),
              Expanded(child: Text('${s['company']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
          ),
          for (final m in vis)
            ListTile(
              leading: Icon(m.icon),
              title: Text(s.t(m.ar, m.en)),
              trailing: effectivePlan(s).rank < m.rank ? const Icon(Icons.lock, size: 16) : null,
              selected: m.id == cur.id,
              selectedColor: green,
              onTap: () {
                ref.read(navProvider.notifier).state = m.id;
                if (drawer) Navigator.pop(context);
              },
            ),
        ]);

    final appBar = AppBar(
      title: Text(s.t(cur.ar, cur.en)),
      actions: [
        ValueListenableBuilder(
          valueListenable: Hive.box('queue').listenable(),
          builder: (c, box, _) => Chip(
            avatar: Icon(box.isEmpty ? Icons.cloud_done : Icons.cloud_off, size: 16, color: box.isEmpty ? green : Colors.orange),
            label: Text(cloudReady ? (box.isEmpty ? s.t('متزامن', 'Synced') : '${box.length} ${s.t('معلّق', 'pending')}') : s.t('محلي', 'Local'), style: const TextStyle(fontSize: 11)),
          ),
        ),
        IconButton(icon: const Icon(Icons.sync), tooltip: 'Sync', onPressed: _cycle),
        IconButton(
          icon: const Icon(Icons.translate),
          onPressed: () => ref.read(settingsProvider.notifier).setAll({'lang': s['lang'] == 'ar' ? 'en' : 'ar'}),
        ),
        if (cloudReady)
          IconButton(icon: const Icon(Icons.logout), onPressed: () => Supabase.instance.client.auth.signOut()),
      ],
    );

    final content = Padding(padding: const EdgeInsets.all(10), child: _body(cur, s));
    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          SizedBox(width: 250, child: Material(color: Colors.white, child: menu(false))),
          Expanded(child: content),
        ]),
      );
    }
    return Scaffold(appBar: appBar, drawer: Drawer(child: menu(true)), body: content);
  }
}

class Locked extends ConsumerWidget {
  final ModuleDef m;
  const Locked(this.m, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Text(s.t('هذه الميزة تتطلب خطة ${plans[m.rank].en} أو أعلى (أو اشتراكك انتهى)', 'This feature needs the ${plans[m.rank].en} plan or higher (or your subscription expired)'), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => ref.read(navProvider.notifier).state = 'plans', child: Text(s.t('ترقية الخطة', 'Upgrade plan'))),
      ]),
    );
  }
}

Widget tabsScaffold(List<String> labels, List<Widget> pages) => DefaultTabController(
      length: labels.length,
      child: Column(children: [
        Material(color: Colors.white, child: TabBar(labelColor: navy, indicatorColor: green, isScrollable: true, tabs: [for (final l in labels) Tab(text: l)])),
        Expanded(child: TabBarView(children: pages)),
      ]),
    );

class TabsScreen extends ConsumerWidget {
  final List<TableDef> defs;
  const TabsScreen(this.defs, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return tabsScaffold([for (final d in defs) s.t(d.ar, d.en)], [for (final d in defs) TableView(d)]);
  }
}

// ============================ GENERIC TABLE (search / filter / sort / CRUD / export) ============================
class TableView extends ConsumerStatefulWidget {
  final TableDef def;
  const TableView(this.def, {super.key});
  @override
  ConsumerState<TableView> createState() => _TableViewState();
}

class _TableViewState extends ConsumerState<TableView> {
  final q = TextEditingController();
  String? col;
  int? sortIdx;
  bool asc = true;

  Future<void> _edit(Map<String, dynamic>? row) async {
    final s = ref.read(settingsProvider);
    final d = widget.def;
    final p = effectivePlan(s);
    if (row == null && d.table == 'warehouses' && p.warehouses >= 0 && Repo.list('warehouses').length >= p.warehouses) {
      _snack(context, s.t('وصلت لحد المستودعات في خطتك', 'Warehouse limit reached for your plan'),
          action: SnackBarAction(label: s.t('ترقية', 'Upgrade'), onPressed: () => ref.read(navProvider.notifier).state = 'plans'));
      return;
    }
    final ctrls = {
      for (final f in d.fields) f.k: TextEditingController(text: row == null ? (f.k == 'date' ? _today() : '') : _f(row[f.k]))
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t(d.ar, d.en)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final f in d.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: ctrls[f.k],
                  keyboardType: f.num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                  decoration: InputDecoration(labelText: s.t(f.ar, f.en), border: const OutlineInputBorder()),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('حفظ', 'Save'))),
        ],
      ),
    );
    if (ok != true) return;
    final m = Map<String, dynamic>.from(row ?? {});
    for (final f in d.fields) {
      var v = ctrls[f.k]!.text.trim();
      if (f.k == 'date' && v.isEmpty) v = _today();
      m[f.k] = f.num ? _n(v) : v;
    }
    await Repo.upsert(d.table, m);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final d = widget.def;
    return ValueListenableBuilder(
      valueListenable: Hive.box('data').listenable(keys: [d.table]),
      builder: (c, _, __) {
        var rows = Repo.list(d.table);
        final term = q.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          final keys = col == null ? d.fields.map((f) => f.k).toList() : [col!];
          rows = rows.where((r) => keys.any((k) => '${r[k] ?? ''}'.toLowerCase().contains(term))).toList();
        }
        if (sortIdx != null) {
          final f = d.fields[sortIdx!];
          rows.sort((a, b) {
            final x = f.num ? _n(a[f.k]).compareTo(_n(b[f.k])) : '${a[f.k] ?? ''}'.compareTo('${b[f.k] ?? ''}');
            return asc ? x : -x;
          });
        }
        final heads = d.fields.map((f) => s.t(f.ar, f.en)).toList();
        final data = rows.map((r) => d.fields.map((f) => _f(r[f.k])).toList()).toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: q,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.t('بحث...', 'Search...'), isDense: true, filled: true, fillColor: Colors.white, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 6),
              DropdownButton<String?>(
                value: col,
                hint: Text(s.t('كل الأعمدة', 'All columns')),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(s.t('كل الأعمدة', 'All columns'))),
                  for (final f in d.fields) DropdownMenuItem<String?>(value: f.k, child: Text(s.t(f.ar, f.en))),
                ],
                onChanged: (v) => setState(() => col = v),
              ),
              exportButtons(context, s, s.t(d.ar, d.en), () => (heads, data)),
              IconButton.filled(onPressed: () => _edit(null), icon: const Icon(Icons.add)),
            ]),
          ),
          Expanded(
            child: Card(
              child: rows.isEmpty
                  ? Center(child: Text(s.t('لا توجد بيانات', 'No data')))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: sortIdx,
                          sortAscending: asc,
                          columns: [
                            for (var i = 0; i < d.fields.length; i++)
                              DataColumn(
                                label: Text(heads[i]),
                                numeric: d.fields[i].num,
                                onSort: (idx, a) => setState(() { sortIdx = idx; asc = a; }),
                              ),
                            const DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final r in rows)
                              DataRow(
                                cells: [
                                  for (final f in d.fields) DataCell(Text(_f(r[f.k])), onTap: () => _edit(r)),
                                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                    if (d.wa)
                                      IconButton(
                                        icon: const Icon(Icons.chat, color: green),
                                        tooltip: 'WhatsApp',
                                        onPressed: () {
                                          final ph = '${r['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
                                          if (ph.isNotEmpty) launchUrl(Uri.parse('https://wa.me/$ph'), mode: LaunchMode.externalApplication);
                                        },
                                      ),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => Repo.remove(d.table, '${r['id']}')),
                                  ])),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ]);
      },
    );
  }
}

// ============================ DASHBOARD ============================
class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return ValueListenableBuilder(
      valueListenable: Hive.box('data').listenable(),
      builder: (c, _, __) {
        final inv = Repo.list('invoices'), exp = Repo.list('expenses'), prods = Repo.list('products');
        double sale(Map r) => (r['kind'] == 'return' ? -1 : 1) * _n(r['total']);
        final today = _today(), mk = today.substring(0, 7);
        final salesToday = inv.where((r) => r['date'] == today).fold<double>(0, (a, r) => a + sale(r));
        final monthInv = inv.where((r) => '${r['date']}'.startsWith(mk)).toList();
        final salesMonth = monthInv.fold<double>(0, (a, r) => a + sale(r));
        var gross = 0.0;
        for (final r in monthInv) {
          for (final i in (r['items'] ?? []) as List) {
            final m = Map<String, dynamic>.from(i as Map);
            gross += (r['kind'] == 'return' ? -1 : 1) * _n(m['qty']) * (_n(m['price']) - _n(m['cost']));
          }
        }
        final inMonth = exp.where((r) => '${r['date']}'.startsWith(mk));
        final expMonth = inMonth.where((r) => r['kind'] != 'income').fold<double>(0, (a, r) => a + _n(r['amount']));
        final incMonth = inMonth.where((r) => r['kind'] == 'income').fold<double>(0, (a, r) => a + _n(r['amount']));
        final profit = gross + incMonth - expMonth;
        final low = prods.where((p) => _n(p['stock']) <= _n(p['min_stock'])).toList();
        final days = List.generate(7, (i) {
          final d = DateTime.now().subtract(Duration(days: 6 - i)).toIso8601String().substring(0, 10);
          return inv.where((r) => r['date'] == d).fold<double>(0, (a, r) => a + sale(r));
        });
        final pay = <String, double>{};
        for (final r in inv) {
          pay['${r['payment_method'] ?? 'cash'}'] = (pay['${r['payment_method'] ?? 'cash'}'] ?? 0) + sale(r);
        }
        final cur = '${s['currency']}';
        Widget kpi(String t, String v, IconData i, Color col) => SizedBox(
              width: 220,
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: col.withOpacity(.15), child: Icon(i, color: col)),
                  title: Text(t, style: const TextStyle(fontSize: 12)),
                  subtitle: Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col)),
                ),
              ),
            );
        final kpis = [
          [s.t('مبيعات اليوم', 'Sales today'), '${_f(salesToday)} $cur'],
          [s.t('مبيعات الشهر', 'Sales this month'), '${_f(salesMonth)} $cur'],
          [s.t('صافي الربح (الشهر)', 'Net profit (month)'), '${_f(profit)} $cur'],
          [s.t('أصناف منخفضة', 'Low stock items'), '${low.length}'],
        ];
        final colors = [const Color(0xFF2563EB), navy, green, Colors.orange];
        final pieColors = [green, const Color(0xFF2563EB), Colors.orange, Colors.purple, Colors.teal];
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: exportButtons(context, s, s.t('لوحة التحكم', 'Dashboard'), () => ([s.t('المؤشر', 'KPI'), s.t('القيمة', 'Value')], kpis.map((e) => [e[0], e[1]]).toList())),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              kpi(kpis[0][0], kpis[0][1], Icons.today, colors[0]),
              kpi(kpis[1][0], kpis[1][1], Icons.calendar_month, colors[1]),
              kpi(kpis[2][0], kpis[2][1], Icons.trending_up, colors[2]),
              kpi(kpis[3][0], kpis[3][1], Icons.warning_amber, colors[3]),
            ]),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('مبيعات آخر 7 أيام', 'Sales - last 7 days'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: LineChart(LineChartData(
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), days[i])],
                          isCurved: true,
                          color: green,
                          barWidth: 3,
                          belowBarData: BarAreaData(show: true, color: green.withOpacity(.15)),
                        ),
                      ],
                    )),
                  ),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('المبيعات حسب طريقة الدفع', 'Sales by payment method'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: pay.values.every((v) => v <= 0)
                        ? Center(child: Text(s.t('لا توجد بيانات', 'No data')))
                        : PieChart(PieChartData(sections: [
                            for (var i = 0; i < pay.length; i++)
                              if (pay.values.elementAt(i) > 0)
                                PieChartSectionData(value: pay.values.elementAt(i), title: pay.keys.elementAt(i), color: pieColors[i % pieColors.length], radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                          ])),
                  ),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('تنبيهات المخزون', 'Stock alerts'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (low.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('كل شيء تمام ✓', 'All good ✓'))),
                  for (final p in low.take(10))
                    ListTile(dense: true, leading: const Icon(Icons.warning, color: Colors.orange), title: Text('${p['name']}'), trailing: Text('${_f(p['stock'])} / ${_f(p['min_stock'])}')),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ============================ SALES / INVOICES ============================
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return tabsScaffold([s.t('فاتورة جديدة', 'New invoice'), s.t('سجل الفواتير', 'Invoice log')], [const NewInvoice(), const InvoiceLog()]);
  }
}

class InvoiceLog extends ConsumerWidget {
  const InvoiceLog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(children: [
      Expanded(child: TableView(tInvoices, key: const ValueKey('inv-table'))),
      ValueListenableBuilder(
        valueListenable: Hive.box('data').listenable(keys: ['invoices']),
        builder: (c, _, __) {
          final l = Repo.list('invoices');
          if (l.isEmpty) return const SizedBox.shrink();
          return Wrap(spacing: 6, children: [
            Text(s.t('إعادة طباعة آخر فاتورة:', 'Reprint last invoice:')),
            for (final e in {'58mm': PdfPageFormat.roll57, '80mm': PdfPageFormat.roll80, 'A4': PdfPageFormat.a4}.entries)
              ActionChip(label: Text(e.key), onPressed: () => Printing.layoutPdf(onLayout: (_) => receiptPdf(l.first, s, e.value))),
          ]);
        },
      ),
    ]);
  }
}

class _Line {
  String name;
  double qty, price, cost;
  _Line(this.name, this.qty, this.price, this.cost);
}

class NewInvoice extends ConsumerStatefulWidget {
  const NewInvoice({super.key});
  @override
  ConsumerState<NewInvoice> createState() => _NewInvoiceState();
}

class _NewInvoiceState extends ConsumerState<NewInvoice> {
  final cust = TextEditingController(), disc = TextEditingController(text: '0');
  String pay = 'cash';
  bool isReturn = false;
  final lines = <_Line>[];

  double get sub => lines.fold(0.0, (a, l) => a + l.qty * l.price);
  Map<String, double> _totals(Map<String, dynamic> s) {
    final d = _n(disc.text), taxable = max(0.0, sub - d), tax = taxable * _n(s['tax']) / 100;
    return {'sub': sub, 'disc': d, 'tax': tax, 'total': taxable + tax};
  }

  Future<void> _addLine() async {
    final s = ref.read(settingsProvider);
    final prods = Repo.list('products');
    final name = TextEditingController(), qty = TextEditingController(text: '1'), price = TextEditingController();
    double cost = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(s.t('إضافة صنف', 'Add item')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (prods.isNotEmpty)
                DropdownButtonFormField<Map<String, dynamic>>(
                  hint: Text(s.t('اختر من المخزون', 'Pick from inventory')),
                  items: [for (final p in prods) DropdownMenuItem(value: p, child: Text('${p['name']}'))],
                  onChanged: (p) => set(() {
                    name.text = '${p!['name']}';
                    price.text = _f(p['price']);
                    cost = _n(p['cost']);
                  }),
                ),
              TextField(controller: name, decoration: InputDecoration(labelText: s.t('الصنف', 'Item'))),
              TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.t('الكمية', 'Qty'))),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.t('السعر', 'Price'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('إلغاء', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('إضافة', 'Add'))),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      setState(() => lines.add(_Line(name.text.trim(), _n(qty.text), _n(price.text), cost)));
    }
  }

  Future<Map<String, dynamic>?> _save() async {
    final s = ref.read(settingsProvider);
    if (lines.isEmpty) return null;
    final p = effectivePlan(s);
    final count = Repo.list('invoices').length;
    if (p.invoices >= 0 && count >= p.invoices) {
      _snack(context, s.t('وصلت لحد الفواتير في خطتك (${p.invoices})', 'Invoice limit reached (${p.invoices})'),
          action: SnackBarAction(label: s.t('ترقية', 'Upgrade'), onPressed: () => ref.read(navProvider.notifier).state = 'plans'));
      return null;
    }
    final t = _totals(s);
    final inv = <String, dynamic>{
      'number': 'INV-${count + 1}',
      'customer': cust.text.trim(),
      'total': t['total'],
      'tax': t['tax'],
      'discount': t['disc'],
      'payment_method': pay,
      'kind': isReturn ? 'return' : 'sale',
      'date': _today(),
      'items': [for (final l in lines) {'name': l.name, 'qty': l.qty, 'price': l.price, 'cost': l.cost}],
    };
    await Repo.upsert('invoices', inv);
    // update stock (sale reduces, return increases)
    for (final l in lines) {
      final prod = Repo.list('products').where((x) => x['name'] == l.name).toList();
      if (prod.isNotEmpty) {
        final m = prod.first;
        m['stock'] = _n(m['stock']) + (isReturn ? l.qty : -l.qty);
        await Repo.upsert('products', m);
      }
    }
    // credit sale => customer balance
    if (pay == 'credit' && cust.text.trim().isNotEmpty) {
      final cs = Repo.list('customers').where((x) => x['name'] == cust.text.trim()).toList();
      if (cs.isNotEmpty) {
        final m = cs.first;
        m['balance'] = _n(m['balance']) + (isReturn ? -1 : 1) * _n(t['total']);
        await Repo.upsert('customers', m);
      }
    }
    return inv;
  }

  Future<void> _saveAndPrint(PdfPageFormat? fmt) async {
    final s = ref.read(settingsProvider);
    final inv = await _save();
    if (inv == null) return;
    if (fmt != null) await Printing.layoutPdf(onLayout: (_) => receiptPdf(inv, s, fmt));
    if (!mounted) return;
    setState(() { lines.clear(); cust.clear(); disc.text = '0'; isReturn = false; });
    _snack(context, s.t('تم حفظ الفاتورة', 'Invoice saved'));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final t = _totals(s);
    return ListView(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: cust, decoration: InputDecoration(labelText: s.t('العميل', 'Customer'), border: const OutlineInputBorder(), isDense: true))),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: pay,
                items: [for (final m in ['cash', 'card', 'wallet', 'credit', 'instapay']) DropdownMenuItem(value: m, child: Text(m))],
                onChanged: (v) => setState(() => pay = v!),
              ),
            ]),
            SwitchListTile(dense: true, title: Text(s.t('فاتورة مرتجع', 'Return invoice')), value: isReturn, onChanged: (v) => setState(() => isReturn = v)),
            TextField(controller: disc, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.t('خصم', 'Discount'), border: const OutlineInputBorder(), isDense: true)),
          ]),
        ),
      ),
      Card(
        child: Column(children: [
          ListTile(title: Text(s.t('الأصناف', 'Items'), style: const TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton.filled(onPressed: _addLine, icon: const Icon(Icons.add))),
          for (var i = 0; i < lines.length; i++)
            ListTile(
              dense: true,
              title: Text(lines[i].name),
              subtitle: Text('${_f(lines[i].qty)} × ${_f(lines[i].price)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_f(lines[i].qty * lines[i].price), style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => lines.removeAt(i))),
              ]),
            ),
        ]),
      ),
      Card(
        color: navy,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(children: [
              _tr(s.t('المجموع', 'Subtotal'), _f(t['sub'])),
              _tr(s.t('الخصم', 'Discount'), _f(t['disc'])),
              _tr('${s.t('الضريبة', 'Tax')} ${_f(s['tax'])}%', _f(t['tax'])),
              const Divider(color: Colors.white24),
              _tr(s.t('الإجمالي', 'Total'), '${_f(t['total'])} ${s['currency']}', big: true),
            ]),
          ),
        ),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: () => _saveAndPrint(null), icon: const Icon(Icons.save), label: Text(s.t('حفظ', 'Save'))),
        OutlinedButton.icon(onPressed: () => _saveAndPrint(PdfPageFormat.roll57), icon: const Icon(Icons.print), label: const Text('58mm')),
        OutlinedButton.icon(onPressed: () => _saveAndPrint(PdfPageFormat.roll80), icon: const Icon(Icons.print), label: const Text('80mm')),
        OutlinedButton.icon(onPressed: () => _saveAndPrint(PdfPageFormat.a4), icon: const Icon(Icons.picture_as_pdf), label: const Text('A4 PDF')),
      ]),
    ]);
  }

  Widget _tr(String a, String b, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: TextStyle(fontSize: big ? 18 : 14)),
          Text(b, style: TextStyle(fontSize: big ? 20 : 14, fontWeight: FontWeight.bold, color: big ? green : Colors.white)),
        ]),
      );
}

// ============================ REPORTS (40+) ============================
class R {
  final String ar, en, table, g, sum, wk, wv;
  const R(this.ar, this.en, this.table, [this.g = '', this.sum = '', this.wk = '', this.wv = '']);
}

const reportList = [
  // --- first 15 = basic (Starter+) ---
  R('كل الفواتير', 'All invoices', 'invoices'),
  R('المبيعات اليومية', 'Daily sales', 'invoices', 'date', 'total'),
  R('المبيعات حسب العميل', 'Sales by customer', 'invoices', 'customer', 'total'),
  R('المبيعات حسب طريقة الدفع', 'Sales by payment method', 'invoices', 'payment_method', 'total'),
  R('المرتجعات', 'Returns', 'invoices', '', '', 'kind', 'return'),
  R('كشف المنتجات', 'Product list', 'products'),
  R('أصناف تحت حد الطلب', 'Low stock', 'products', '', '', '__low'),
  R('المخزون حسب المستودع', 'Stock by warehouse', 'products', 'warehouse', 'stock'),
  R('قائمة العملاء', 'Customer list', 'customers'),
  R('العملاء المدينون', 'Debtors', 'customers', '', '', '__pos'),
  R('قائمة الموردين', 'Supplier list', 'suppliers'),
  R('أوامر الشراء', 'Purchase orders', 'purchase_orders'),
  R('المصروفات', 'Expenses', 'expenses', '', '', 'kind', 'expense'),
  R('الإيرادات', 'Income', 'expenses', '', '', 'kind', 'income'),
  R('قائمة الموظفين', 'Employees', 'employees'),
  // --- advanced (Business+) ---
  R('تقرير ضريبة القيمة المضافة اليومي', 'Daily VAT report', 'invoices', 'date', 'tax'),
  R('تقرير الخصومات', 'Discounts report', 'invoices', 'date', 'discount'),
  R('المرتجعات حسب العميل', 'Returns by customer', 'invoices', 'customer', 'total', 'kind', 'return'),
  R('المبيعات الآجلة', 'Credit sales', 'invoices', '', '', 'payment_method', 'credit'),
  R('فواتير المبيعات فقط', 'Sales invoices only', 'invoices', '', '', 'kind', 'sale'),
  R('أسعار البيع', 'Price list', 'products'),
  R('تكلفة المنتجات', 'Cost list', 'products'),
  R('الأرقام التسلسلية', 'Serial numbers', 'products'),
  R('الباركود', 'Barcode list', 'products'),
  R('كميات المخزون', 'Stock levels', 'products', 'name', 'stock'),
  R('المستودعات', 'Warehouses', 'warehouses'),
  R('تحويلات المخزون', 'Stock transfers', 'stock_transfers'),
  R('تحويلات حسب المنتج', 'Transfers by product', 'stock_transfers', 'product', 'qty'),
  R('نقاط الولاء', 'Loyalty points', 'customers', 'name', 'points'),
  R('أرصدة العملاء', 'Customer balances', 'customers', 'name', 'balance'),
  R('أرصدة الموردين', 'Supplier balances', 'suppliers', 'name', 'balance'),
  R('الموردون المستحق لهم', 'Suppliers owed', 'suppliers', '', '', '__pos'),
  R('المشتريات حسب المورد', 'Purchases by supplier', 'purchase_orders', 'supplier', 'total'),
  R('المشتريات حسب الحالة', 'Purchases by status', 'purchase_orders', 'status', 'total'),
  R('المصروفات حسب الحساب', 'Expenses by account', 'expenses', 'account', 'amount', 'kind', 'expense'),
  R('المصروفات اليومية', 'Daily expenses', 'expenses', 'date', 'amount', 'kind', 'expense'),
  R('قيود اليومية', 'Journal entries', 'journal_entries'),
  R('اليومية حسب الحساب المدين', 'Journal by debit', 'journal_entries', 'debit_account', 'amount'),
  R('اليومية حسب الحساب الدائن', 'Journal by credit', 'journal_entries', 'credit_account', 'amount'),
  R('كشف الرواتب', 'Payroll', 'employees', 'name', 'salary'),
  R('العمولات', 'Commissions', 'employees', 'name', 'commission_pct'),
  R('سجل الحضور', 'Attendance log', 'attendance'),
  R('الحضور حسب الموظف', 'Attendance by employee', 'attendance', 'employee'),
  R('قوائم التصنيع BOM', 'BOM list', 'boms'),
  R('ميزان المراجعة', 'Trial balance', '__tb'),
  R('قائمة الأرباح والخسائر', 'Profit & loss', '__pl'),
];

(List<String>, List<List<String>>) runReport(R r, Map<String, dynamic> s) {
  if (r.table == '__tb') {
    final j = Repo.list('journal_entries');
    final acc = <String, List<double>>{};
    for (final e in j) {
      acc.putIfAbsent('${e['debit_account']}', () => [0, 0])[0] += _n(e['amount']);
      acc.putIfAbsent('${e['credit_account']}', () => [0, 0])[1] += _n(e['amount']);
    }
    return ([s.t('الحساب', 'Account'), s.t('مدين', 'Debit'), s.t('دائن', 'Credit'), s.t('الرصيد', 'Balance')],
        [for (final e in acc.entries) [e.key, _f(e.value[0]), _f(e.value[1]), _f(e.value[0] - e.value[1])]]);
  }
  if (r.table == '__pl') {
    final inv = Repo.list('invoices');
    final sales = inv.fold<double>(0, (a, x) => a + (x['kind'] == 'return' ? -1 : 1) * _n(x['total']));
    final ex = Repo.list('expenses');
    final inc = ex.where((x) => x['kind'] == 'income').fold<double>(0, (a, x) => a + _n(x['amount']));
    final exps = ex.where((x) => x['kind'] != 'income').fold<double>(0, (a, x) => a + _n(x['amount']));
    final purch = Repo.list('purchase_orders').fold<double>(0, (a, x) => a + _n(x['total']));
    final sal = Repo.list('employees').fold<double>(0, (a, x) => a + _n(x['salary']));
    return ([s.t('البند', 'Item'), s.t('المبلغ', 'Amount')], [
      [s.t('صافي المبيعات', 'Net sales'), _f(sales)],
      [s.t('إيرادات أخرى', 'Other income'), _f(inc)],
      [s.t('المشتريات', 'Purchases'), _f(-purch)],
      [s.t('المصروفات', 'Expenses'), _f(-exps)],
      [s.t('الرواتب (شهرياً)', 'Salaries (monthly)'), _f(-sal)],
      [s.t('صافي الربح', 'Net profit'), _f(sales + inc - purch - exps - sal)],
    ]);
  }
  final def = tableDefs[r.table]!;
  var rows = Repo.list(r.table);
  if (r.wk == '__low') {
    rows = rows.where((x) => _n(x['stock']) <= _n(x['min_stock'])).toList();
  } else if (r.wk == '__pos') {
    rows = rows.where((x) => _n(x['balance']) > 0).toList();
  } else if (r.wk.isNotEmpty) {
    rows = rows.where((x) => '${x[r.wk]}' == r.wv).toList();
  }
  if (r.g.isNotEmpty) {
    final g = def.fields.firstWhere((f) => f.k == r.g);
    final m = <String, List<double>>{};
    for (final x in rows) {
      final v = m.putIfAbsent('${x[r.g] ?? ''}', () => [0, 0]);
      v[0] += 1;
      if (r.sum.isNotEmpty) v[1] += _n(x[r.sum]);
    }
    final sf = r.sum.isEmpty ? null : def.fields.firstWhere((f) => f.k == r.sum);
    return ([s.t(g.ar, g.en), s.t('العدد', 'Count'), if (sf != null) s.t(sf.ar, sf.en)],
        [for (final e in m.entries) [e.key, _f(e.value[0]), if (sf != null) _f(e.value[1])]]);
  }
  return (def.fields.map((f) => s.t(f.ar, f.en)).toList(), rows.map((x) => def.fields.map((f) => _f(x[f.k])).toList()).toList());
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final rank = effectivePlan(s).rank;
    return ListView.builder(
      itemCount: reportList.length,
      itemBuilder: (c, i) {
        final r = reportList[i];
        final locked = i >= 15 && rank < 2;
        final title = s.t(r.ar, r.en);
        return Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: navy, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(title),
            trailing: locked
                ? TextButton.icon(onPressed: () => ref.read(navProvider.notifier).state = 'plans', icon: const Icon(Icons.lock, size: 16), label: const Text('Business'))
                : exportButtons(context, s, title, () => runReport(r, s)),
            onTap: locked
                ? null
                : () {
                    final d = runReport(r, s);
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(title),
                        content: SizedBox(
                          width: 600,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: [for (final h in d.$1) DataColumn(label: Text(h))],
                                rows: [for (final row in d.$2.take(100)) DataRow(cells: [for (final v in row) DataCell(Text(v))])],
                              ),
                            ),
                          ),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(s.t('إغلاق', 'Close')))],
                      ),
                    );
                  },
          ),
        );
      },
    );
  }
}

// ============================ BARCODE ============================
class BarcodeScreen extends ConsumerStatefulWidget {
  const BarcodeScreen({super.key});
  @override
  ConsumerState<BarcodeScreen> createState() => _BarcodeState();
}

class _BarcodeState extends ConsumerState<BarcodeScreen> {
  final data = TextEditingController(text: '200000000001');
  String type = 'code128';
  Map<String, dynamic>? found;

  Barcode get bc => type == 'qr' ? Barcode.qrCode() : (type == 'ean13' ? Barcode.ean13() : Barcode.code128());

  void _lookup(String v) {
    final r = Repo.list('products').where((p) => '${p['barcode']}' == v).toList();
    setState(() => found = r.isEmpty ? null : r.first);
  }

  Future<void> _scan() async {
    var done = false;
    final v = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        child: SizedBox(
          height: 320,
          child: ms.MobileScanner(onDetect: (cap) {
            final raw = cap.barcodes.firstOrNull?.rawValue;
            if (raw != null && !done) {
              done = true;
              Navigator.pop(c, raw);
            }
          }),
        ),
      ),
    );
    if (v != null) {
      data.text = v;
      _lookup(v);
    }
  }

  Future<void> _print() async {
    if (!bc.isValid(data.text)) {
      _snack(context, 'Invalid data for $type');
      return;
    }
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (c) => pw.Center(child: pw.BarcodeWidget(barcode: bc, data: data.text, width: 180, height: type == 'qr' ? 100 : 60)),
    ));
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return ListView(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(controller: data, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: s.t('قيمة الباركود', 'Barcode value'), border: const OutlineInputBorder())),
            DropdownButton<String>(value: type, items: const [
              DropdownMenuItem(value: 'code128', child: Text('Code 128')),
              DropdownMenuItem(value: 'ean13', child: Text('EAN-13')),
              DropdownMenuItem(value: 'qr', child: Text('QR')),
            ], onChanged: (v) => setState(() => type = v!)),
            const SizedBox(height: 10),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: BarcodeWidget(barcode: bc, data: data.text, width: 240, height: type == 'qr' ? 120 : 80, errorBuilder: (c, e) => Text(e, style: const TextStyle(color: Colors.red, fontSize: 12))),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: Text(s.t('مسح', 'Scan'))),
              OutlinedButton.icon(onPressed: _print, icon: const Icon(Icons.print), label: Text(s.t('طباعة', 'Print'))),
              OutlinedButton.icon(
                onPressed: () => setState(() => data.text = List.generate(12, (_) => Random().nextInt(10)).join()),
                icon: const Icon(Icons.casino),
                label: Text(s.t('توليد', 'Generate')),
              ),
            ]),
          ]),
        ),
      ),
      if (found != null)
        Card(child: ListTile(leading: const Icon(Icons.inventory_2, color: green), title: Text('${found!['name']}'), subtitle: Text('${s.t('السعر', 'Price')}: ${_f(found!['price'])}  •  ${s.t('الكمية', 'Stock')}: ${_f(found!['stock'])}'))),
    ]);
  }
}

// ============================ SETTINGS ============================
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  late final TextEditingController company, tax, taxid;
  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    company = TextEditingController(text: '${s['company']}');
    tax = TextEditingController(text: _f(s['tax']));
    taxid = TextEditingController(text: '${s['taxid']}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final p = effectivePlan(s);
    return ListView(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(controller: company, decoration: InputDecoration(labelText: s.t('اسم الشركة', 'Company name'), border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: taxid, decoration: InputDecoration(labelText: s.t('الرقم الضريبي', 'Tax ID'), border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: tax, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.t('نسبة الضريبة %', 'Tax rate %'), border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Text(s.t('العملة:', 'Currency:')),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: '${s['currency']}',
                items: [for (final c in ['EGP', 'USD', 'SAR', 'AED', 'EUR']) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => n.setAll({'currency': v}),
              ),
              const Spacer(),
              Text(s.t('اللغة:', 'Language:')),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: '${s['lang']}',
                items: const [DropdownMenuItem(value: 'ar', child: Text('العربية')), DropdownMenuItem(value: 'en', child: Text('English'))],
                onChanged: (v) => n.setAll({'lang': v}),
              ),
            ]),
            if (!cloudReady)
              Row(children: [
                Text(s.t('الدور (تجريبي):', 'Role (demo):')),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: '${s['role']}',
                  items: [for (final r in ['admin', 'cashier', 'accountant', 'storekeeper']) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: (v) => n.setAll({'role': v}),
                ),
              ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  n.setAll({'company': company.text.trim(), 'taxid': taxid.text.trim(), 'tax': _n(tax.text)});
                  _snack(context, s.t('تم الحفظ', 'Saved'));
                },
                child: Text(s.t('حفظ الإعدادات', 'Save settings')),
              ),
            ),
          ]),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.workspace_premium, color: green),
          title: Text('${s.t('الخطة الحالية', 'Current plan')}: ${p.en}'),
          subtitle: Text(cloudReady ? s.t('متصل بـ Supabase', 'Connected to Supabase') : s.t('وضع محلي (بدون سحابة) - عدّل kSupabaseUrl', 'Local mode - set kSupabaseUrl to enable cloud')),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.sync),
          title: Text(s.t('مزامنة Offline الآن', 'Sync now')),
          subtitle: Text('${Repo.pending()} ${s.t('عملية معلّقة', 'pending operations')}'),
          onTap: () async {
            await Repo.sync();
            await Repo.pull();
            if (mounted) setState(() {});
          },
        ),
      ),
    ]);
  }
}

// ============================ PLANS + PAYMENT ============================
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  Widget _feat(bool ok, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 18, color: ok ? green : Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: ok ? null : Colors.grey))),
        ]),
      );

  Future<void> _pay(BuildContext context, WidgetRef ref, Plan p, String gw) async {
    final s = ref.read(settingsProvider);
    final c = sb;
    if (c == null || c.auth.currentUser == null) {
      // DEMO activation only (local mode). In production the subscription is set by the payment webhook.
      ref.read(settingsProvider.notifier).setAll({'plan': p.id, 'expires': DateTime.now().add(const Duration(days: 30)).toIso8601String()});
      _snack(context, s.t('تم التفعيل تجريبياً لمدة 30 يوم (وضع محلي)', 'Activated for 30 days (local demo mode)'));
      return;
    }
    try {
      final r = await c.functions.invoke('create-payment', body: {'plan': p.id, 'gateway': gw});
      final url = (r.data as Map)['url'] as String;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) _snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final cur = effectivePlan(s);
    final expired = s['plan'] != 'free' && cur.id == 'free';
    return SingleChildScrollView(
      child: Column(children: [
        if (expired)
          Card(color: Colors.red.shade50, child: ListTile(leading: const Icon(Icons.error, color: Colors.red), title: Text(s.t('انتهى اشتراكك - تم قفل المميزات المدفوعة', 'Subscription expired - paid features are locked')))),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (final p in plans)
            SizedBox(
              width: 260,
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.id == 'business' ? green : Colors.transparent, width: 2)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (p.id == 'business') Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(8)), child: Text(s.t('الأكثر طلباً', 'Most popular'), style: const TextStyle(color: Colors.white, fontSize: 11))),
                    Text(s.t(p.ar, p.en), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
                    Text(p.price == 0 ? s.t('مجاناً', 'Free') : '${p.price} ${s.t('جنيه/شهر', 'EGP/mo')}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: green)),
                    const Divider(),
                    _feat(true, p.users < 0 ? s.t('مستخدمون غير محدودون', 'Unlimited users') : s.t('${p.users} مستخدم', '${p.users} user(s)')),
                    _feat(true, p.invoices < 0 ? s.t('فواتير غير محدودة', 'Unlimited invoices') : s.t('${p.invoices} فاتورة', '${p.invoices} invoices')),
                    _feat(true, p.warehouses < 0 ? s.t('مستودعات غير محدودة', 'Unlimited warehouses') : s.t('${p.warehouses} مستودع', '${p.warehouses} warehouse(s)')),
                    _feat(p.rank >= 1, s.t('تقارير أساسية', 'Basic reports')),
                    _feat(p.adv, s.t('تقارير متقدمة (40+)', 'Advanced reports (40+)')),
                    _feat(p.rank >= 2, s.t('كل الموديولات (HR / تصنيع)', 'All modules (HR / Mfg)')),
                    _feat(p.api, 'API'),
                    _feat(p.rank >= 3, s.t('فروع غير محدودة + لوجو مخصص', 'Unlimited branches + custom logo')),
                    _feat(p.vip, s.t('دعم VIP', 'VIP support')),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: p.id == cur.id
                          ? OutlinedButton(onPressed: null, child: Text(s.t('خطتك الحالية', 'Current plan')))
                          : FilledButton(
                              onPressed: p.price == 0
                                  ? null
                                  : () => showModalBottomSheet(
                                        context: context,
                                        builder: (c) => SafeArea(
                                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                                            ListTile(title: Text('${s.t('اختر بوابة الدفع', 'Choose gateway')} - ${p.en}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                            for (final g in ['paymob', 'fawry', 'stripe'])
                                              ListTile(
                                                leading: const Icon(Icons.credit_card),
                                                title: Text(g[0].toUpperCase() + g.substring(1)),
                                                onTap: () { Navigator.pop(c); _pay(context, ref, p, g); },
                                              ),
                                          ]),
                                        ),
                                      ),
                              child: Text(s.t('اشترك', 'Subscribe')),
                            ),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}