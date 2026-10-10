import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_loadLocale());

  static Locale _loadLocale() {
    final box = Hive.box(AppConstants.settingsBox);
    final code = box.get('locale', defaultValue: 'ar') as String;
    return Locale(code);
  }

  void setLocale(String code) {
    final box = Hive.box(AppConstants.settingsBox);
    box.put('locale', code);
    state = Locale(code);
  }

  void toggle() {
    final newCode = state.languageCode == 'ar' ? 'en' : 'ar';
    setLocale(newCode);
  }
}
