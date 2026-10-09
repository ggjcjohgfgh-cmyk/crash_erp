# Crash ERP — نظام ERP سحابي SaaS (Flutter + Supabase)

مشروع مستقل كامل: تطبيق Flutter + قاعدة بيانات + دوال الدفع + ملف بناء APK تلقائي.

## الهيكل
```
pubspec.yaml
lib/main.dart                      التطبيق (12 موديول + الاشتراكات + Offline)
android/                           إعدادات Gradle/Manifest/styles كاملة (minSdk 21)
.github/workflows/build.yml        بناء APK تلقائياً على GitHub
supabase_tables.sql                الجداول + RLS + الأدوار + حدود الخطط
supabase/functions/create-payment  إنشاء جلسة دفع (Stripe / Paymob)
supabase/functions/payment-webhook تفعيل الاشتراك بعد الدفع (مع التحقق من التوقيع)
```

## 1) تشغيل التطبيق محلياً (بدون سحابة)
```bash
flutter pub get
flutter run
```
بدون بيانات Supabase يعمل كل شيء محلياً ومشفراً على الجهاز، وتقدر تجرب كل الموديولات والفواتير والتقارير والطباعة.

## 2) بناء APK
**محلياً:** `flutter build apk --release`
**على GitHub:** ارفع المشروع، ثم تبويب Actions ← Build APK ← Run workflow، وحمّل الـ APK من Artifacts.
إضافة `SUPABASE_URL` و`SUPABASE_ANON_KEY` في Settings ← Secrets ← Actions تدمجهما في التطبيق تلقائياً.

## 3) تفعيل السحابة (Supabase)
1. أنشئ مشروعاً في supabase.com، وفي SQL Editor نفّذ `supabase_tables.sql`.
2. انسخ `URL` و`anon key` من Project Settings ← API وضعهما في أعلى `lib/main.dart` أو في `--dart-define`.
3. من تبويب Authentication فعّل Email.
4. أول مستخدم يسجّل ينشئ شركته تلقائياً ويصبح admin على الخطة المجانية.

## 4) تفعيل الدفع
```bash
npm i -g supabase
supabase login && supabase link --project-ref <ref>
supabase secrets set STRIPE_SECRET_KEY=... STRIPE_WEBHOOK_SECRET=... \
  PAYMOB_API_KEY=... PAYMOB_INTEGRATION_ID=... PAYMOB_IFRAME_ID=... PAYMOB_HMAC=... \
  RETURN_URL=https://your-site.com/paid
supabase functions deploy create-payment
supabase functions deploy payment-webhook --no-verify-jwt
```
- **Stripe:** أضف Webhook على `https://<ref>.functions.supabase.co/payment-webhook?gateway=stripe` للحدث `checkout.session.completed`.
- **Paymob:** ضع Transaction processed callback على `.../payment-webhook?gateway=paymob`.
- **Fawry:** غير مكتملة عمداً (تحتاج merchantCode وsecureKey وإعدادات خاصة بحسابك)؛ الدالة ترجع 501 حتى تُكمل.
- بعد الدفع تُفعّل الدالة الاشتراك 30 يوماً (وتمدّده عند التجديد)، ويقرأه التطبيق كل 30 ثانية؛ عند الانتهاء ينزل للخطة المجانية وتُقفل الميزات.
- مفاتيح البوابات تبقى في Supabase Secrets فقط، ولا توضع في التطبيق.

## الأمان
- RLS على كل الجداول، وكل صف مربوط بـ `org_id`.
- الصلاحيات (admin/cashier/accountant/storekeeper) مطبقة داخل قاعدة البيانات.
- حدود الخطط (مستخدمين/فواتير/مستودعات) مطبقة بـ Triggers على السيرفر.
- جدول `subscriptions` للقراءة فقط من العميل، ويكتب فيه الـ webhook فقط.
- بيانات Hive المحلية مشفرة AES والمفتاح في Keystore.

## الربح
| الخطة | السعر | دورها |
|---|---|---|
| Free | 0 | جذب مستخدمين (حد 100 فاتورة يدفع للترقية) |
| Starter | 199 ج/شهر | محلات صغيرة |
| Business | 499 ج/شهر | الأكثر ربحاً: كل الموديولات + API |
| Enterprise | 999 ج/شهر | شركات متعددة الفروع |

نصائح: خصم 20% للسنوي، بيع التهيئة والتدريب كخدمة مستقلة، ومحاسبون كمسوّقين بعمولة. 100 عميل Business ≈ 49,900 ج/شهر قبل رسوم البوابة.

## حدود هذه النسخة (صراحةً)
- **لم يُجرَّب البناء عليها بعد.** أول `flutter pub get` / `flutter analyze` قد يظهر أخطاء بسيطة؛ ابعتها وتُصلح.
- القيود المحاسبية يدوية (غير مولدة من الفواتير)، والتصنيع BOM وتكلفة بدون أوامر تصنيع.
- Serial Number حقل نصي لكل منتج، لا تتبع لكل وحدة.
- الـ QR بصيغة TLV عامة، وليس ربطاً رسمياً بالفاتورة الإلكترونية المصرية.
- توقيع الإصدار يستخدم debug key؛ أنشئ keystore قبل النشر على Google Play.
- التطبيق في ملف واحد `main.dart` كما طلبت، وليس مقسماً لطبقات Clean Architecture.
