import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Interface language; independent of the source-content translation target.
enum AppLanguage {
  system(null),
  chinese(Locale('zh')),
  english(Locale('en'));

  const AppLanguage(this.locale);

  final Locale? locale;

  static AppLanguage fromPreference(String? value) => switch (value) {
    'zh' => chinese,
    'en' => english,
    _ => system,
  };

  String get preference => locale?.languageCode ?? 'system';
}

Locale resolveAppLocale(Locale? locale) =>
    locale?.languageCode == 'zh' ? const Locale('zh') : const Locale('en');

Future<void> syncNativeAppLocale(Locale locale) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'com.apkmesh/localization',
    ).invokeMethod<void>('setLanguage', {'languageCode': locale.languageCode});
  } on MissingPluginException {
    // Native localization is absent in Flutter-only test hosts.
  }
}
