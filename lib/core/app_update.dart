import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String currentAppVersionString = '1.0.0';

class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
    this.preRelease = '',
    required this.raw,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;
  final String preRelease;
  final String raw;

  static final AppVersion current = AppVersion.parse(currentAppVersionString);

  static AppVersion parse(String versionStr) {
    var text = versionStr.trim();
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1).trim();
    }

    var buildNumber = 0;
    final plusIndex = text.indexOf('+');
    if (plusIndex != -1) {
      final buildStr = text.substring(plusIndex + 1);
      text = text.substring(0, plusIndex);
      buildNumber = int.tryParse(buildStr) ?? 0;
    }

    var preReleaseStr = '';
    final dashIndex = text.indexOf('-');
    if (dashIndex != -1) {
      preReleaseStr = text.substring(dashIndex + 1);
      text = text.substring(0, dashIndex);
    }

    final segments = text.split('.');
    final majorNumber = segments.isNotEmpty
        ? int.tryParse(segments[0]) ?? 0
        : 0;
    final minorNumber = segments.length > 1
        ? int.tryParse(segments[1]) ?? 0
        : 0;
    final patchNumber = segments.length > 2
        ? int.tryParse(segments[2]) ?? 0
        : 0;

    return AppVersion(
      major: majorNumber,
      minor: minorNumber,
      patch: patchNumber,
      build: buildNumber,
      preRelease: preReleaseStr,
      raw: versionStr,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (build != other.build) return build.compareTo(other.build);

    // If both have or both lack pre-release, compare strings.
    // A version without pre-release is newer than one with pre-release.
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;
    return preRelease.compareTo(other.preRelease);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          build == other.build &&
          preRelease == other.preRelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, build, preRelease);

  @override
  String toString() => raw;
}

class AppReleaseAsset {
  const AppReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
    this.contentType,
  });

  final String name;
  final int size;
  final String downloadUrl;
  final String? contentType;

  bool get isApk =>
      name.toLowerCase().endsWith('.apk') ||
      contentType == 'application/vnd.android.package-archive';

  factory AppReleaseAsset.fromJson(Map<String, dynamic> json) {
    return AppReleaseAsset(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String?,
    );
  }
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    this.name,
    this.body,
    required this.htmlUrl,
    this.publishedAt,
    this.assets = const [],
  });

  final String tagName;
  final AppVersion version;
  final String? name;
  final String? body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<AppReleaseAsset> assets;

  AppReleaseAsset? get apkAsset {
    for (final asset in assets) {
      if (asset.isApk) return asset;
    }
    return null;
  }

  bool hasUpdate(AppVersion currentVersion) => version > currentVersion;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final assetsJson = json['assets'] as List<dynamic>? ?? const [];
    final assets = assetsJson
        .whereType<Map<String, dynamic>>()
        .map(AppReleaseAsset.fromJson)
        .toList();

    DateTime? publishedAt;
    final publishedStr = json['published_at'] as String?;
    if (publishedStr != null) {
      publishedAt = DateTime.tryParse(publishedStr);
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: AppVersion.parse(tagName),
      name: json['name'] as String?,
      body: json['body'] as String?,
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: publishedAt,
      assets: assets,
    );
  }
}

class UpdateService {
  UpdateService({this.repository = 'wsdx233/ApkMesh', this.client});

  final String repository;
  final http.Client? client;

  static const _timeout = Duration(seconds: 15);
  static const _githubApiHeaders = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'ApkMesh-App',
  };

  http.Client get _effectiveClient => client ?? http.Client();

  Future<AppReleaseInfo?> fetchLatestRelease({http.Client? client}) async {
    final httpClient = client ?? _effectiveClient;
    final shouldClose = client == null && this.client == null;

    try {
      final latestUri = Uri.parse(
        'https://api.github.com/repos/$repository/releases/latest',
      );
      final response = await httpClient
          .get(latestUri, headers: _githubApiHeaders)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AppReleaseInfo.fromJson(data);
      }

      if (response.statusCode == 404) {
        // Fallback: Check /releases list in case releases are marked pre-release
        final listUri = Uri.parse(
          'https://api.github.com/repos/$repository/releases',
        );
        final listResponse = await httpClient
            .get(listUri, headers: _githubApiHeaders)
            .timeout(_timeout);
        if (listResponse.statusCode == 200) {
          final listData = jsonDecode(listResponse.body) as List<dynamic>;
          for (final item in listData) {
            if (item is Map<String, dynamic> && item['draft'] != true) {
              return AppReleaseInfo.fromJson(item);
            }
          }
        }
      }

      throw HttpException(
        'GitHub API error: ${response.statusCode} ${response.reasonPhrase ?? ''}',
        uri: latestUri,
      );
    } finally {
      if (shouldClose) {
        httpClient.close();
      }
    }
  }

  Future<File> downloadApk(
    AppReleaseAsset asset, {
    File? destinationFile,
    void Function(int received, int? total)? onProgress,
    http.Client? client,
  }) async {
    final httpClient = client ?? _effectiveClient;
    final shouldClose = client == null && this.client == null;

    try {
      final file =
          destinationFile ??
          File(
            p.join(
              (await getTemporaryDirectory()).path,
              asset.name.isNotEmpty ? asset.name : 'apkmesh-update.apk',
            ),
          );

      if (await file.exists()) {
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(asset.downloadUrl));
      request.headers.addAll({'User-Agent': 'ApkMesh-App'});

      final response = await httpClient.send(request).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(asset.downloadUrl),
        );
      }

      final total =
          response.contentLength != null && response.contentLength! > 0
          ? response.contentLength
          : (asset.size > 0 ? asset.size : null);

      final sink = file.openWrite();
      var received = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } catch (error) {
        await sink.close();
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }

      await sink.close();
      return file;
    } finally {
      if (shouldClose) {
        httpClient.close();
      }
    }
  }
}
