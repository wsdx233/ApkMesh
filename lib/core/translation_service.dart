import '../l10n/app_localizations.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'app_language.dart';

/// The three consumer/free translation routes supported by the app.
enum TranslationProvider { microsoft, google, freeModel }

extension TranslationProviderLabel on TranslationProvider {
  String label(AppLocalizations strings) => switch (this) {
    TranslationProvider.microsoft => strings.microsoftTranslator,
    TranslationProvider.google => 'Google Translate',
    TranslationProvider.freeModel => strings.freeTranslator,
  };
}

class TranslationSettings {
  const TranslationSettings({
    this.provider = TranslationProvider.microsoft,
    this.targetLanguage = 'system',
    this.autoTranslate = true,
    this.googlePublicKey = '',
  });

  final TranslationProvider provider;
  final String targetLanguage;
  final bool autoTranslate;
  final String googlePublicKey;

  TranslationSettings copyWith({
    TranslationProvider? provider,
    String? targetLanguage,
    bool? autoTranslate,
    String? googlePublicKey,
  }) => TranslationSettings(
    provider: provider ?? this.provider,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    autoTranslate: autoTranslate ?? this.autoTranslate,
    googlePublicKey: googlePublicKey ?? this.googlePublicKey,
  );
}

class TranslationService {
  TranslationService({http.Client? client, this._localizations})
    : _client = client ?? http.Client();

  final AppLocalizations Function()? _localizations;
  AppLocalizations get strings =>
      _localizations?.call() ??
      lookupAppLocalizations(
        resolveAppLocale(PlatformDispatcher.instance.locale),
      );

  final http.Client _client;
  String? _freeModelJwt;
  DateTime? _freeModelTokenExpiresAt;

  Future<List<String>> translate(
    List<String> texts, {
    required TranslationSettings settings,
    required String deviceId,
  }) async {
    final values = texts.map((text) => text.trim()).toList(growable: false);
    final translated = List<String>.filled(values.length, '');
    final pending = <({int index, String text})>[];
    final maxTextLength = _maxTextLength(settings.provider);
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value.isEmpty) continue;
      for (var offset = 0; offset < value.length; offset += maxTextLength) {
        final end = (offset + maxTextLength).clamp(0, value.length);
        pending.add((index: index, text: value.substring(offset, end)));
      }
    }
    if (pending.isEmpty) return translated;

    final target = translationLanguageCode(
      settings.targetLanguage,
      settings.provider,
    );
    final batches = _batches(pending, settings.provider);
    for (final batch in batches) {
      final result = await switch (settings.provider) {
        TranslationProvider.microsoft => _translateMicrosoft(
          batch.map((item) => item.text).toList(growable: false),
          target,
        ),
        TranslationProvider.google => _translateGoogle(
          batch.map((item) => item.text).toList(growable: false),
          target,
          publicKey: settings.googlePublicKey,
        ),
        TranslationProvider.freeModel => _translateFreeModel(
          batch.map((item) => item.text).toList(growable: false),
          target,
          deviceId: deviceId,
        ),
      };
      if (result.length != batch.length) {
        throw FormatException(strings.translationCountMismatch);
      }
      for (var index = 0; index < batch.length; index++) {
        translated[batch[index].index] += result[index];
      }
    }
    return translated.map((text) => text.trim()).toList(growable: false);
  }

  int _maxTextLength(TranslationProvider provider) => switch (provider) {
    TranslationProvider.microsoft => 1800,
    TranslationProvider.google => 8000,
    TranslationProvider.freeModel => 12000,
  };

  List<List<({int index, String text})>> _batches(
    List<({int index, String text})> values,
    TranslationProvider provider,
  ) {
    final maxItems = switch (provider) {
      TranslationProvider.microsoft => 50,
      TranslationProvider.google => 8,
      TranslationProvider.freeModel => 20,
    };
    final maxChars = switch (provider) {
      TranslationProvider.microsoft => 1800,
      TranslationProvider.google => 8000,
      TranslationProvider.freeModel => 12000,
    };
    final batches = <List<({int index, String text})>>[];
    var current = <({int index, String text})>[];
    var characters = 0;
    for (final value in values) {
      final tooManyItems = current.length >= maxItems;
      final tooManyCharacters =
          current.isNotEmpty && characters + value.text.length > maxChars;
      if (tooManyItems || tooManyCharacters) {
        batches.add(current);
        current = <({int index, String text})>[];
        characters = 0;
      }
      current.add(value);
      characters += value.text.length;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }

  Future<List<String>> _translateMicrosoft(
    List<String> texts,
    String target,
  ) async {
    final uri = Uri.https(
      'edge.microsoft.com',
      '/translate/translatetext',
      <String, String>{'to': target, 'isEnterpriseClient': 'false'},
    );
    final response = await _client
        .post(
          uri,
          headers: const {'Accept': '*/*', 'Content-Type': 'application/json'},
          body: jsonEncode(texts),
        )
        .timeout(const Duration(seconds: 10));
    _checkResponse(response, 'Microsoft');
    final decoded = _decodeJson(response.body);
    if (decoded is! List || decoded.length != texts.length) {
      throw FormatException(strings.microsoftResponseInvalid);
    }
    return decoded
        .map((item) {
          if (item is! Map) return '';
          final translations = item['translations'];
          if (translations is! List || translations.isEmpty) return '';
          final first = translations.first;
          return first is Map ? (first['text'] ?? '').toString() : '';
        })
        .toList(growable: false);
  }

  Future<List<String>> _translateGoogle(
    List<String> texts,
    String target, {
    required String publicKey,
  }) async {
    // The browser endpoint accepts one text group per request. A public key is
    // optional because the legacy consumer endpoint is used as a fallback.
    final results = <String>[];
    for (final text in texts) {
      results.add(
        await _translateGoogleText(text, target, publicKey: publicKey.trim()),
      );
    }
    return results;
  }

  Future<String> _translateGoogleText(
    String text,
    String target, {
    required String publicKey,
  }) async {
    late final http.Response response;
    if (publicKey.isNotEmpty) {
      final uri = Uri.https('translate-pa.googleapis.com', '/v1/translateHtml');
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json+protobuf',
              'x-goog-api-key': publicKey,
            },
            body: jsonEncode([
              [text.split(''), 'auto', target],
              'te_lib',
            ]),
          )
          .timeout(const Duration(seconds: 15));
    } else {
      final uri = Uri.https(
        'translate.googleapis.com',
        '/translate_a/t',
        <String, String>{
          'client': 'gtx',
          'dt': 't',
          'sl': 'auto',
          'tl': target,
        },
      );
      response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: Uri(queryParameters: {'q': text}).query,
          )
          .timeout(const Duration(seconds: 15));
    }
    _checkResponse(response, 'Google');
    return _decodeGoogleText(_decodeJson(response.body));
  }

  Future<List<String>> _translateFreeModel(
    List<String> texts,
    String target, {
    required String deviceId,
  }) async {
    final token = await _freeModelToken(
      deviceId: deviceId,
      language: target,
      forceRefresh: false,
    );
    try {
      return await _translateFreeModelWithToken(texts, target, token);
    } on _UnauthorizedTranslationException {
      final refreshed = await _freeModelToken(
        deviceId: deviceId,
        language: target,
        forceRefresh: true,
      );
      return _translateFreeModelWithToken(texts, target, refreshed);
    }
  }

  Future<List<String>> _translateFreeModelWithToken(
    List<String> texts,
    String target,
    String token,
  ) async {
    final uri = Uri.https(
      'aigw1.immersivetranslate.com',
      '/v1/translation/tasks',
    );
    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'task_type': 'web_page',
            'stream': false,
            'payload': {
              'to': target,
              'content_type': 'plain_text',
              'segments': [
                for (var index = 0; index < texts.length; index++)
                  {'id': 'seg-$index', 'text': texts[index]},
              ],
            },
            'ui_language': target,
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 401) {
      throw const _UnauthorizedTranslationException();
    }
    _checkResponse(response, strings.freeTranslator);
    final decoded = _decodeJson(response.body);
    final rawSegments = decoded is Map
        ? (decoded['result'] is Map ? decoded['result']['segments'] : null)
        : null;
    if (rawSegments is! List) {
      throw FormatException(strings.freeTranslationResponseInvalid);
    }
    final values = <String>[];
    final byId = <String, String>{};
    for (final item in rawSegments) {
      if (item is! Map) continue;
      final id = item['id']?.toString();
      if (id == null) continue;
      byId[id] = (item['translated_text'] ?? item['text'] ?? '').toString();
    }
    for (var index = 0; index < texts.length; index++) {
      values.add(byId['seg-$index'] ?? '');
    }
    return values;
  }

  Future<String> _freeModelToken({
    required String deviceId,
    required String language,
    required bool forceRefresh,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _freeModelJwt != null &&
        _freeModelTokenExpiresAt != null &&
        _freeModelTokenExpiresAt!.isAfter(
          now.add(const Duration(minutes: 2)),
        )) {
      return _freeModelJwt!;
    }
    final uri = Uri.https(
      'api2.immersivetranslate.com',
      '/free-model/get-token',
      <String, String>{'deviceId': deviceId, 'l': '0'},
    );
    final response = await _client
        .get(uri, headers: {'Accept-Language': language})
        .timeout(const Duration(seconds: 15));
    _checkResponse(response, strings.freeTranslationToken);
    final decoded = _decodeJson(response.body);
    final token = decoded is Map ? decoded['data']?.toString() : null;
    if (token == null || token.isEmpty) {
      throw FormatException(strings.translationTokenMissing);
    }
    _freeModelJwt = token;
    _freeModelTokenExpiresAt =
        _jwtExpiry(token) ?? now.add(const Duration(hours: 1));
    return token;
  }

  DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final seconds = payload is Map ? int.tryParse('${payload['exp']}') : null;
      return seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {
      return null;
    }
  }

  dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (error) {
      throw FormatException(strings.translationJsonInvalid((error).toString()));
    }
  }

  static void _checkResponse(http.Response response, String provider) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranslationHttpException('$provider HTTP ${response.statusCode}');
    }
  }

  static String _decodeGoogleText(dynamic value) {
    dynamic current = value;
    while (current is List && current.isNotEmpty) {
      current = current.first;
    }
    if (current is String) return _decodeEntities(current);
    return '';
  }

  static String _decodeEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1)!);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      });

  void dispose() => _client.close();
}

String translationLanguageCode(String language, TranslationProvider provider) {
  final value = language == 'system' ? _systemLanguageCode() : language;
  if (provider == TranslationProvider.microsoft) {
    return const {
          'zh-CN': 'zh-Hans',
          'zh-TW': 'zh-Hant',
          'pt-BR': 'pt',
          'pt': 'pt-PT',
          'no': 'nb',
        }[value] ??
        value;
  }
  if (provider == TranslationProvider.google) {
    return const {'ja': 'jp', 'ko': 'kr', 'pt-BR': 'pt'}[value] ?? value;
  }
  return value;
}

String translationLanguageLabel(String language, AppLocalizations strings) =>
    switch (language) {
      'system' => strings.followSystem,
      'zh-CN' => strings.simplifiedChinese,
      'zh-TW' => strings.traditionalChinese,
      'en' => strings.englishLanguage,
      'ja' => strings.japaneseLanguage,
      'ko' => strings.koreanLanguage,
      'es' => strings.spanishLanguage,
      'fr' => strings.frenchLanguage,
      'de' => strings.germanLanguage,
      'pt' => strings.portugueseLanguage,
      _ => language,
    };

String _systemLanguageCode() {
  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  final language = locale.languageCode.toLowerCase();
  if (language == 'zh') {
    final country = locale.countryCode?.toUpperCase();
    return {'TW', 'HK', 'MO'}.contains(country) ? 'zh-TW' : 'zh-CN';
  }
  return language;
}

class TranslationHttpException implements Exception {
  const TranslationHttpException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _UnauthorizedTranslationException implements Exception {
  const _UnauthorizedTranslationException();
}
