import 'package:apk_mesh/app.dart';
import 'package:apk_mesh/core/app_language.dart';
import 'package:apk_mesh/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'translation.auto': false});
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);

  testWidgets(
    'language follows the system until overridden and survives restart',
    (tester) async {
      binding.platformDispatcher.localesTestValue = const [Locale('zh', 'TW')];
      await tester.pumpWidget(const ApkMeshApp());
      await tester.pumpAndSettle();
      expect(find.text('主页'), findsWidgets);

      await tester.tap(find.byIcon(Icons.settings_outlined).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-language-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-language-en')));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);

      final shell = tester.widget<Shell>(find.byType(Shell));
      expect(shell.state.translationSettings.targetLanguage, 'system');
      binding.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const ApkMeshApp());
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);

      await tester.tap(find.byIcon(Icons.settings_outlined).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-language-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-language-system')));
      await tester.pumpAndSettle();
      expect(find.text('主页'), findsWidgets);

      binding.platformDispatcher.localesTestValue = const [Locale('fr')];
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
      expect(
        Localizations.localeOf(tester.element(find.byType(Shell))),
        const Locale('en'),
      );
    },
  );

  testWidgets(
    'saved Chinese overrides English and dialogs use Chinese Material labels',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app.language': 'zh',
        'translation.language': 'ja',
        'translation.auto': false,
      });
      binding.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpWidget(const ApkMeshApp());
      await tester.pumpAndSettle();
      final shell = tester.widget<Shell>(find.byType(Shell));
      expect(find.text('主页'), findsWidgets);
      expect(shell.state.translationSettings.targetLanguage, 'ja');
      final context = tester.element(find.byType(Shell));
      expect(MaterialLocalizations.of(context).cancelButtonLabel, '取消');
      await shell.state.setAppLanguage(AppLanguage.english);
      await tester.pumpAndSettle();
      expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancel');
      expect(AppLocalizations.of(context).cancel, 'Cancel');
    },
  );

  test('action and tab localizations differentiate verbs and nouns', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));

    expect(en.downloads, 'Downloads');
    expect(en.downloadAction, 'Download');
    expect(en.favorites, 'Favorites');
    expect(en.favoriteAction, 'Add to favorites');
    expect(en.enable, 'Enable');
    expect(en.disable, 'Disable');

    expect(zh.downloads, '下载');
    expect(zh.downloadAction, '下载');
    expect(zh.favorites, '收藏');
    expect(zh.favoriteAction, '收藏');
    expect(zh.enable, '开启');
    expect(zh.disable, '关闭');
  });
}
