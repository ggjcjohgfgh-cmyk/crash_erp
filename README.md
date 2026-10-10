# Crash ERP — Professional Cloud SaaS ERP

**نظام إدارة موارد المؤسسات السحابي المتكامل**  
يعمل على **Android · iOS · Web · Windows** من كود Flutter واحد.

ينافس Odoo و QuickBooks في السوق العربي.

---

## التقنيات

| الطبقة | التقنية |
|--------|---------|
| Frontend | Flutter 3.22+ (Responsive) |
| State | Riverpod + Hive (Offline-First) |
| Backend | Supabase (Postgres + Auth + Realtime + Storage + RLS) |
| Charts | fl_chart |
| PDF/Print | pdf + printing |
| Barcode | barcode + mobile_scanner |
| Payments | Paymob + Fawry + Stripe |

---

## الموديولات (12)

1. **لوحة التحكم الذكية** — KPIs, Charts, تنبيهات
2. **المبيعات والفواتير** — فاتورة ضريبية + QR + طباعة حرارية 58/80mm
3. **المخزون والمستودعات** — متعدد، باركود، جرد، تحويل، Serial
4. **المشتريات والموردين** — أوامر شراء، فواتير، مرتجعات
5. **CRM العملاء** — مديونيات، ولاء، واتساب
6. **المالية والمحاسبة** — خزينة، بنوك، قيود، ميزان، P&L، ضرائب
7. **الموظفين والرواتب** — حضور، رواتب، سلف، عمولات
8. **التصنيع** — BOM + أوامر تصنيع + تكلفة
9. **التقارير** — +40 تقرير PDF/Excel
10. **الإعدادات** — شركة، عملات، ضرائب، Roles
11. **الباركود** — إنشاء + طباعة + قراءة
12. **Offline-First** — يعمل بدون نت + Sync تلقائي

---

## خطط SaaS (نموذج الربح)

| الخطة | السعر | مستخدمين | فواتير | مستودعات | ملاحظات |
|-------|-------|----------|--------|----------|---------|
| Free | 0 | 1 | 100 | 1 | بدون تقارير متقدمة |
| Starter | 199 ج.م/شهر | 3 | 1000 | 2 | تقارير متقدمة |
| Business | 499 ج.م/شهر | 10 | ∞ | 10 | كل الموديولات + API |
| Enterprise | 999 ج.م/شهر | ∞ | ∞ | ∞ | VIP + لوجو مخصص |

**بوابات الدفع:** Paymob · Fawry · Stripe

الكود يتحقق من الاشتراك ويقفل المميزات تلقائياً عند الانتهاء.

---

## التشغيل السريع

### 1. إعداد Supabase
```bash
# أنشئ مشروع جديد على supabase.com
# انسخ URL و Anon Key
# نفّذ الملف:
supabase/supabase_tables.sql
```

### 2. تعديل الثوابت
```dart
// lib/core/constants/app_constants.dart
static const String supabaseUrl = 'https://xxxx.supabase.co';
static const String supabaseAnonKey = 'eyJ...';
```

### 3. تثبيت الحزم
```bash
cd crash_erp
flutter pub get
```

### 4. تشغيل
```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# Windows
flutter run -d windows

# Build APK (جاهز بدون أخطاء mipmap)
flutter build apk --release
```

### Android Config (مُصلّح)
- `AndroidManifest.xml` يستخدم `@android:drawable/sym_def_app_icon`
- `styles.xml` مبسّط بدون LaunchTheme معقد
- لا أخطاء mipmap أو theme

---

## Clean Architecture

```
lib/
├── core/           # constants, theme, network, utils
├── data/           # models, repositories, datasources
├── domain/         # entities, repositories, usecases
├── features/       # feature modules
└── presentation/   # providers, screens, widgets
```

---

## كيف تربح من Crash ERP؟

1. انشر التطبيق على Google Play + App Store + Web
2. اربط Paymob / Fawry / Stripe
3. العملاء يشتركون داخل التطبيق
4. الخطط تبدأ من 199 ج.م → 999 ج.م شهرياً
5. أضف فروع (White-label) لخطة Enterprise
6. قدّم دعم VIP و تخصيصات بأسعار إضافية

**متوسط الإيراد المتوقع:**  
100 عميل Business = ~50,000 ج.م/شهر

---

## الأمان
- Row Level Security (RLS) على كل الجداول
- Multi-tenant isolation
- Auth عبر Supabase (JWT)
- Offline encryption عبر Hive

---

## الرخصة
ملكية خاصة — Crash Soft © 2026

---

**Crash ERP — نظام ينافس العالم، مصنوع للسوق العربي.**
