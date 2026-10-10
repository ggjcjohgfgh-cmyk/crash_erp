import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(AppConstants.accentGreen),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Crash ERP',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'نظام إدارة الأعمال الاحترافي',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Color(AppConstants.accentGreen),
            ),
          ],
        ),
      ),
    );
  }
}
