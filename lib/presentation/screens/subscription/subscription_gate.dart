import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import 'plans_screen.dart';

class SubscriptionGateScreen extends ConsumerWidget {
  const SubscriptionGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(AppConstants.surfaceLight),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.accentOrange).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_clock,
                      size: 40,
                      color: Color(AppConstants.accentOrange),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isAr ? 'انتهى الاشتراك' : 'Subscription Expired',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isAr
                        ? 'يرجى تجديد اشتراكك للاستمرار في استخدام جميع مميزات Crash ERP'
                        : 'Please renew your subscription to continue using Crash ERP features',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlansScreen()),
                        );
                      },
                      child: Text(isAr ? 'عرض الخطط والتجديد' : 'View Plans & Renew'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
