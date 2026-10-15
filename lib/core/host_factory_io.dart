import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'concurrency_limiter.dart';
import 'debug_log.dart';
import 'download_path.dart';
import 'models.dart';
import 'source_runtime.dart';

SourceHostApi createPlatformHostApi({DebugLogStore? debug}) =>
    NativeHostApi(debug: debug);

class NativeHostApi implements SourceHostApi, SourceHostConcurrencyApi {
  NativeHostApi({this._debug});

  static const _installChannel = MethodChannel('com.apkmesh/install');
  InstallMethod _installMethod = InstallMethod.system;
  final DebugLogStore? _debug;
  final Map<String, HeadlessInAppWebView> _tabs = {};
  final Map<String, InAppWebViewController> _controllers = {};
  final Map<String, InAppWebViewKeepAlive> _attachedTabs = {};
  final Map<String, SourcePolicy> _tabPolicies = {};
  final Map<String, BrowserTabDebugInfo> _tabStates = {};
  final List<BrowserTabDebugInfo> _tabHistory = [];
  final Map<String, String> _tabDownloadUrls = {};
  final Map<String, Map<String, String>> _browserCookies = {};
  final http.Client _client = http.Client();
  final Map<String, _NativeDownloadSession> _downloadSessions = {};
  final AdjustableSemaphore _httpRequests = AdjustableSemaphore(
    SourceConcurrencySettings.defaultHttpRequests,
  );
  final AdjustableSemaphore _webViews = AdjustableSemaphore(
    SourceConcurrencySettings.defaultWebViews,
  );
  final Set<String> _browserPermits = {};

  @override
  void setSourceConcurrency(SourceConcurrencySettings settings) {
    _httpRequests.limit = settings.httpRequests;
    _webViews.limit = settings.webViews;
  }

  bool get _hasHeadlessWebView =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  bool get supportsBrowser => _hasHeadlessWebView;

  @override
  bool get supportsInstall => Platform.isAndroid;

  @override
  bool get supportsShizuku => Platform.isAndroid;

  @override
  bool hasDownloadSession(String downloadId) =>
      _downloadSessions.containsKey(downloadId);

  @override
  List<BrowserTabDebugInfo> get browserTabs => [
    ..._tabStates.values,
    ..._tabHistory,
  ];

  void _log(
    String message, {
    DebugLogLevel level = DebugLogLevel.info,
    String category = 'Host',
  }) {
    debugPrint('[APK Mesh] $message');
    _debug?.add(message, level: level, category: category);
  }

  bool _looksLikeApkDownload(Uri url) =>
      url.path.toLowerCase().endsWith('.apk');

  void _recordWebViewDownload(String tabId, Uri url) {
    final downloadUrl = url.toString();
    if (_tabDownloadUrls[tabId] == downloadUrl) return;
    _tabDownloadUrls[tabId] = downloadUrl;
    _setTabState(tabId, url: downloadUrl, state: 'download-started');
    _log('WebView download started $tabId $downloadUrl', category: 'WebView');
  }

  void _setTabState(
    String tabId, {
    String? url,
    required String state,
    bool active = true,
  }) {
    final current = _tabStates[tabId];
    if (current == null) return;
    final snapshot = current.copyWith(url: url, state: state, active: active);
    if (active) {
      _tabStates[tabId] = snapshot;
    } else {
      _tabStates.remove(tabId);
      _tabHistory.insert(0, snapshot);
      if (_tabHistory.length > 20) _tabHistory.removeLast();
    }
    _log('WebView ${active ? state : 'closed'} $tabId ${snapshot.url}');
  }

  void _check(Uri uri, SourcePolicy policy, {required bool capability}) {
    if (!capability) throw UnsupportedError('该源没有请求此能力');
    if (!policy.permits(uri)) {
      throw StateError('源权限拒绝访问 ${uri.host}');
    }
  }

  @override
  Future<String> request(
    String url, {
    Map<String, String> headers = const {},
    String method = 'GET',
    String? body,
    required SourcePolicy policy,
  }) => _httpRequests.withPermit(() async {
    final requestId = _debug?.beginRequest(
      url,
      method: method,
      headers: headers,
    );
    var requestRecorded = false;
    _log('HTTP $url', category: 'HTTP');
    try {
      final response = await _getWithRedirects(
        Uri.parse(url),
        policy,
        headers: headers,
        method: method,
        body: body,
      );
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode >= 400) {
        if (requestId != null) {
          _debug?.failRequest(
            requestId,
            'HTTP ${response.statusCode}',
            statusCode: response.statusCode,
            responseHeaders: response.headers,
            responseBody: responseBody,
          );
        }
        requestRecorded = true;
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      if (requestId != null) {
        _debug?.completeRequest(
          requestId,
          statusCode: response.statusCode,
          responseHeaders: response.headers,
          responseBody: responseBody,
        );
        requestRecorded = true;
      }
      _log('HTTP $url -> ${response.statusCode}', category: 'HTTP');
      return responseBody;
    } catch (error) {
      if (requestId != null && !requestRecorded) {
        _debug?.failRequest(requestId, error);
      }
      _log(
        'HTTP $url failed: $error',
        level: DebugLogLevel.error,
        category: 'HTTP',
      );
      rethrow;
    }
  });

  @override
  Future<List<int>> requestBytes(
    String url, {
    Map<String, String> headers = const {},
    required SourcePolicy policy,
  }) => _httpRequests.withPermit(() async {
    _log('HTTP bytes $url', category: 'HTTP');
    final response = await _getWithRedirects(
      Uri.parse(url),
      policy,
      headers: headers,
    );
    final bytes = await response.stream.toBytes();
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    _log('HTTP bytes $url -> ${response.statusCode}', category: 'HTTP');
    return bytes;
  });

  Future<http.StreamedResponse> _getWithRedirects(
    Uri initialUri,
    SourcePolicy policy, {
    Map<String, String> headers = const {},
    String method = 'GET',
    String? body,
  }) async {
    var normalizedMethod = method.trim().toUpperCase();
    if (normalizedMethod != 'GET' && normalizedMethod != 'POST') {
      throw ArgumentError.value(method, 'method', '仅支持 GET 或 POST');
    }
    var uri = initialUri;
    var currentHeaders = <String, String>{...headers};
    var currentBody = body;
    for (var redirects = 0; redirects < 7; redirects++) {
      _check(uri, policy, capability: true);
      final requestHeaders = <String, String>{...currentHeaders};
      if (!currentHeaders.keys.any((key) => key.toLowerCase() == 'cookie')) {
        final cookies = _cookieHeader(uri);
        if (cookies != null) requestHeaders['Cookie'] = cookies;
      }
      final request = http.Request(normalizedMethod, uri)
        ..followRedirects = false
        ..headers.addAll(requestHeaders);
      if (currentBody != null) request.body = currentBody;
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (!const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        return response;
      }
      await response.stream.drain<void>();
      final location = response.headers['location'];
      if (location == null) throw HttpException('重定向缺少 Location', uri: uri);
      final nextUri = uri.resolve(location);
      if (response.statusCode == 303 ||
          ((response.statusCode == 301 || response.statusCode == 302) &&
              normalizedMethod == 'POST')) {
        normalizedMethod = 'GET';
        currentBody = null;
        currentHeaders.removeWhere(
          (key, _) => const {
            'content-type',
            'content-length',
            'transfer-encoding',
          }.contains(key.toLowerCase()),
        );
      }
      if (uri.scheme != nextUri.scheme ||
          uri.host != nextUri.host ||
          uri.port != nextUri.port) {
        currentHeaders.removeWhere(
          (key, _) => const {
            'authorization',
            'proxy-authorization',
            'cookie',
            'host',
          }.contains(key.toLowerCase()),
        );
      }
      uri = nextUri;
    }
    throw HttpException('重定向次数过多', uri: uri);
  }

  @override
  Future<String> browserOpen(String url, {required SourcePolicy policy}) async {
    final uri = Uri.parse(url);
    _check(uri, policy, capability: policy.allowBrowser);
    if (!_hasHeadlessWebView) {
      throw UnsupportedError('Linux/Windows 当前没有隐藏 WebView 实现');
    }

    await _webViews.acquire();
    String? permitTabId;
    try {
      final tabId = DateTime.now().microsecondsSinceEpoch.toString();
      permitTabId = tabId;
      _browserPermits.add(tabId);
      _tabStates[tabId] = BrowserTabDebugInfo(
        id: tabId,
        url: url,
        state: 'starting',
        startedAt: DateTime.now(),
      );
      _tabPolicies[tabId] = policy;
      _log('WebView opening $tabId $url');
      final controllerReady = Completer<InAppWebViewController>();
      final pageLoaded = Completer<void>();
      var loaded = false;
      late final HeadlessInAppWebView tab;
      tab = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          incognito: true,
          useOnDownloadStart: true,
          useShouldOverrideUrlLoading: true,
          useShouldInterceptRequest: true,
          userAgent:
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131.0 Safari/537.36',
        ),
        initialUrlRequest: URLRequest(url: WebUri(uri.toString())),
        onWebViewCreated: (controller) {
          _controllers[tabId] = controller;
          _setTabState(tabId, state: 'created');
          if (!controllerReady.isCompleted) {
            controllerReady.complete(controller);
          }
        },
        onLoadStop: (controller, url) {
          loaded = true;
          _setTabState(tabId, url: url?.toString(), state: 'ready');
          if (!pageLoaded.isCompleted) pageLoaded.complete();
        },
        onDownloadStarting: (controller, request) {
          final downloadUrl = request.url.toString();
          if (!policy.permits(request.url)) {
            _log(
              'WebView download blocked $tabId $downloadUrl',
              level: DebugLogLevel.warning,
              category: 'WebView',
            );
            return null;
          }
          _recordWebViewDownload(tabId, request.url);
          return null;
        },
        shouldOverrideUrlLoading: (_, action) async {
          final next = action.request.url;
          if (next == null || !policy.permits(next)) {
            return NavigationActionPolicy.CANCEL;
          }
          _setTabState(tabId, url: next.toString(), state: 'navigating');
          return NavigationActionPolicy.ALLOW;
        },
        shouldInterceptRequest: (_, request) async {
          final resource = request.url;
          if (policy.permits(resource) && _looksLikeApkDownload(resource)) {
            _recordWebViewDownload(tabId, resource);
          }
          if ((resource.scheme == 'http' || resource.scheme == 'https') &&
              !policy.permits(resource)) {
            return WebResourceResponse(
              statusCode: 403,
              reasonPhrase: 'Source domain is not allowed',
              contentType: 'text/plain',
              data: Uint8List.fromList(utf8.encode('blocked by source policy')),
            );
          }
          return null;
        },
      );
      _tabs[tabId] = tab;
      await tab.run();
      await controllerReady.future.timeout(const Duration(seconds: 15));
      await pageLoaded.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
      if (!loaded) _setTabState(tabId, state: 'load-timeout');
      return tabId;
    } catch (_) {
      if (permitTabId == null) {
        _webViews.release();
      } else {
        try {
          await browserClose(permitTabId);
        } catch (_) {}
      }
      rethrow;
    }
  }

  InAppWebViewController _controller(String tabId) =>
      _controllers[tabId] ?? (throw StateError('浏览器标签页不存在'));

  @override
  Future<void> browserWaitFor(String tabId, String selector) async {
    _setTabState(tabId, state: 'waiting: $selector');
    final escaped = jsonEncode(selector);
    final controller = _controller(tabId);
    for (var i = 0; i < 100; i++) {
      final exists = await controller.evaluateJavascript(
        source: 'document.querySelector($escaped) != null',
      );
      if (exists == true || exists.toString() == 'true') {
        _setTabState(tabId, state: 'ready');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _setTabState(tabId, state: 'wait-timeout');
    throw TimeoutException('等待选择器超时: $selector');
  }

  @override
  Future<String> browserWaitForUrlChange(
    String tabId,
    String previousUrl,
  ) async {
    _setTabState(tabId, state: 'waiting: URL change');
    for (var i = 0; i < 150; i++) {
      final currentUrl =
          _tabDownloadUrls[tabId] ?? _tabStates[tabId]?.url ?? '';
      if (currentUrl.isNotEmpty && currentUrl != previousUrl) {
        _setTabState(tabId, state: 'ready');
        return currentUrl;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _setTabState(tabId, state: 'wait-timeout');
    throw TimeoutException('等待下载地址跳转超时: $previousUrl');
  }

  @override
  Future<Map<String, dynamic>> browserQuery(
    String tabId,
    Map<String, dynamic> selectors,
  ) async {
    _log('WebView query $tabId', category: 'WebView');
    final value = await _evaluateQuery(_controller(tabId), null, selectors);
    return value.cast<String, dynamic>();
  }

  @override
  Future<List<Map<String, dynamic>>> browserQueryAll(
    String tabId,
    String rootSelector,
    Map<String, dynamic> selectors,
  ) async {
    _log('WebView queryAll $tabId $rootSelector', category: 'WebView');
    final result = await _evaluateQueryAll(
      _controller(tabId),
      rootSelector,
      selectors,
    );
    _log(
      'WebView queryAll $tabId $rootSelector -> ${result.length}',
      category: 'WebView',
    );
    return result;
  }

  Future<dynamic> _evaluateQuery(
    InAppWebViewController controller,
    String? root,
    Map<String, dynamic> selectors,
  ) async {
    final expression = _queryExpression(
      selectors,
      rootExpression: root ?? 'document',
    );
    final value = await controller.evaluateJavascript(source: expression);
    return value is String ? jsonDecode(value) : (value ?? <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> _evaluateQueryAll(
    InAppWebViewController controller,
    String rootSelector,
    Map<String, dynamic> selectors,
  ) async {
    final itemExpression = _queryExpression(
      selectors,
      rootExpression: 'root',
      stringify: false,
    );
    final expression =
        '''(() => JSON.stringify(Array.from(document.querySelectorAll(${jsonEncode(rootSelector)})).map(root => $itemExpression)))()''';
    final value = await controller.evaluateJavascript(source: expression);
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  String _queryExpression(
    Map<String, dynamic> selectors, {
    required String rootExpression,
    bool stringify = true,
  }) {
    final entries = selectors.entries
        .map((entry) {
          final selector = entry.value is List
              ? entry.value.first.toString()
              : entry.value.toString();
          final parts = selector.split('@');
          final cssValue = parts.first.trim();
          final element = cssValue.isEmpty
              ? rootExpression
              : '$rootExpression.querySelector(${jsonEncode(cssValue)})';
          final attrValue = parts.length > 1
              ? parts.sublist(1).join('@').trim()
              : null;
          final attr = attrValue == null ? 'null' : jsonEncode(attrValue);
          return '${jsonEncode(entry.key)}: (() => { const el = $element; if (!el) return null; return $attr === null || $attr === "text" ? (el.textContent || "").trim() : (el.getAttribute($attr) || "").trim(); })()';
        })
        .join(',');
    final objectExpression = '({$entries})';
    return stringify
        ? '''(() => JSON.stringify($objectExpression))()'''
        : objectExpression;
  }

  String? _cookieHeader(Uri uri) {
    final cookies = <String, String>{};
    for (final entry in _browserCookies.entries) {
      final domain = entry.key;
      if (uri.host == domain || uri.host.endsWith('.$domain')) {
        cookies.addAll(entry.value);
      }
    }
    if (cookies.isEmpty) return null;
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  Future<void> _captureBrowserCookies(Uri uri) async {
    if (!_hasHeadlessWebView) return;
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(uri.toString()),
      );
      for (final cookie in cookies) {
        final domain = (cookie.domain ?? uri.host).toLowerCase().replaceFirst(
          RegExp(r'^\.'),
          '',
        );
        _browserCookies.putIfAbsent(domain, () => {})[cookie.name] = cookie
            .value
            .toString();
      }
    } catch (error) {
      _log(
        'WebView cookie capture failed for ${uri.host}: $error',
        level: DebugLogLevel.warning,
        category: 'WebView',
      );
    }
  }

  @override
  BrowserTabViewHandle? browserTabView(String tabId) {
    final headless = _tabs[tabId];
    var existingKeepAlive = _attachedTabs[tabId];
    if (headless == null && existingKeepAlive == null) return null;
    final keepAlive = existingKeepAlive ??= InAppWebViewKeepAlive();
    _attachedTabs[tabId] = keepAlive;
    return BrowserTabViewHandle(
      headlessWebView: headless?.isRunning() == true ? headless : null,
      keepAlive: keepAlive,
      policy: _tabPolicies[tabId] ?? (throw StateError('浏览器标签页权限策略不存在')),
    );
  }

  @override
  void browserAdoptController(String tabId, InAppWebViewController controller) {
    if (_tabs.containsKey(tabId) || _attachedTabs.containsKey(tabId)) {
      _controllers[tabId] = controller;
    }
  }

  @override
  Future<void> browserClose(String tabId) async {
    try {
      _log('WebView closing $tabId', category: 'WebView');
      final tab = _tabs.remove(tabId);
      final keepAlive = _attachedTabs.remove(tabId);
      final state = _tabStates[tabId];
      _tabPolicies.remove(tabId);
      _controllers.remove(tabId);
      _tabDownloadUrls.remove(tabId);
      final url = state == null ? null : Uri.tryParse(state.url);
      if (url != null) await _captureBrowserCookies(url);
      if (keepAlive != null) {
        await InAppWebViewController.disposeKeepAlive(keepAlive);
      } else {
        await tab?.dispose();
      }
      _setTabState(tabId, state: 'closed', active: false);
    } finally {
      if (_browserPermits.remove(tabId)) _webViews.release();
    }
  }

  Future<Directory> _downloadDirectory() async {
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    return directory;
  }

  File _partialFile(Directory directory, String sessionId) {
    final safeId = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File(p.join(directory.path, '.apkmesh-$safeId.part'));
  }

  ({int start, int? total})? _contentRange(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return (
      start: int.parse(match.group(1)!),
      total: match.group(3) == '*' ? null : int.parse(match.group(3)!),
    );
  }

  int? _responseTotal(http.StreamedResponse response, int offset) {
    final range = _contentRange(response.headers['content-range']);
    if (range?.total != null) return range!.total;
    final length = response.contentLength;
    return length == null ? null : offset + length;
  }

  Future<http.StreamedResponse> _downloadResponse(
    Uri uri,
    SourcePolicy policy, {
    required Map<String, String> headers,
    required int offset,
  }) async {
    final requestHeaders = <String, String>{...headers};
    if (offset > 0) requestHeaders['Range'] = 'bytes=$offset-';
    return await _getWithRedirects(uri, policy, headers: requestHeaders);
  }

  @override
  Future<String> download(
    String url, {
    Map<String, String> headers = const {},
    String? downloadId,
    String? fileName,
    required SourcePolicy policy,
    void Function(int received, int? total)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    _check(uri, policy, capability: policy.allowDownload);
    final directory = await _downloadDirectory();
    final sessionId =
        downloadId ?? 'host-${DateTime.now().microsecondsSinceEpoch}';
    final requestedName = fileName ?? p.basename(uri.path).split('?').first;
    final destinationName = buildDownloadDestinationName(
      requestedName: requestedName,
      sessionId: sessionId,
    );
    final destination = File(p.join(directory.path, destinationName));
    final partial = _partialFile(directory, sessionId);
    final session = _NativeDownloadSession(destination, partial);
    _downloadSessions[sessionId] = session;

    try {
      var offset = await partial.exists() ? await partial.length() : 0;
      var response = await _downloadResponse(
        uri,
        policy,
        headers: headers,
        offset: offset,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException('下载失败 HTTP ${response.statusCode}', uri: uri);
      }
      if (session.canceled) throw const DownloadCancelledException();

      final range = _contentRange(response.headers['content-range']);
      if (offset > 0 &&
          (response.statusCode != HttpStatus.partialContent ||
              range?.start != offset)) {
        await response.stream.drain<void>();
        if (await partial.exists()) await partial.delete();
        offset = 0;
        response = await _downloadResponse(
          uri,
          policy,
          headers: headers,
          offset: 0,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.stream.drain<void>();
          throw HttpException('下载失败 HTTP ${response.statusCode}', uri: uri);
        }
      }

      final total = _responseTotal(response, offset);
      onProgress?.call(offset, total);
      final sink = partial.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      session.sink = sink;
      var received = offset;
      session.subscription = response.stream.listen(
        (chunk) {
          if (session.canceled) return;
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(received, total);
        },
        onError: (Object error, StackTrace stack) {
          if (!session.done.isCompleted) {
            session.done.completeError(error, stack);
          }
        },
        onDone: () {
          if (!session.done.isCompleted) session.done.complete();
        },
      );
      if (session.paused) session.subscription!.pause();
      await session.done.future;
      if (session.canceled) throw const DownloadCancelledException();
      await sink.close();
      if (total != null && received != total) {
        throw HttpException('下载内容不完整：$received/$total', uri: uri);
      }
      await directory.create(recursive: true);
      if (!await partial.exists()) {
        throw FileSystemException('下载临时文件不存在', partial.path);
      }
      if (await destination.exists()) await destination.delete();
      await partial.rename(destination.path);
      return destination.path;
    } catch (error) {
      await session.subscription?.cancel();
      await session.sink?.close();
      if (session.canceled) {
        if (!session.preservePartialOnCancel && await partial.exists()) {
          await partial.delete();
        }
        throw const DownloadCancelledException();
      }
      rethrow;
    } finally {
      _downloadSessions.remove(sessionId);
      if (!session.finished.isCompleted) session.finished.complete();
    }
  }

  @override
  Future<void> pauseDownload(String downloadId) async {
    final session = _downloadSessions[downloadId];
    if (session == null) throw StateError('下载任务不存在');
    session.paused = true;
    session.subscription?.pause();
  }

  @override
  Future<void> resumeDownload(String downloadId) async {
    final session = _downloadSessions[downloadId];
    if (session == null) throw StateError('下载任务不存在');
    session.paused = false;
    session.subscription?.resume();
  }

  @override
  Future<void> cancelDownload(String downloadId) async {
    final session = _downloadSessions[downloadId];
    if (session == null) return;
    session.canceled = true;
    await session.subscription?.cancel();
    if (!session.done.isCompleted) session.done.complete();
    await session.finished.future;
  }

  bool _isWithin(String path, Directory directory) {
    final normalizedPath = p.normalize(path);
    final normalizedRoot = p.normalize(directory.path);
    return normalizedPath == normalizedRoot ||
        normalizedPath.startsWith('$normalizedRoot${p.separator}');
  }

  @override
  Future<void> removeDownloadFiles(
    String downloadId, {
    String? filePath,
  }) async {
    final directory = await _downloadDirectory();
    final partial = _partialFile(directory, downloadId);
    if (await partial.exists()) await partial.delete();
    if (filePath == null) return;

    final roots = <Directory>[directory];
    final documents = await getApplicationDocumentsDirectory();
    if (documents.path != directory.path) roots.add(documents);
    if (roots.any((root) => _isWithin(filePath, root))) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<bool> install(
    String filePath, {
    required SourcePolicy policy,
    bool userInitiated = false,
  }) async {
    if (!policy.permitsInstall(userInitiated: userInitiated)) {
      throw StateError('源未声明安装权限');
    }
    if (!supportsInstall) throw UnsupportedError('当前平台不支持 APK 安装');
    if (_installMethod == InstallMethod.shizuku) {
      if (!userInitiated) {
        throw StateError('Shizuku 安装必须由用户点击安装按钮发起');
      }
      final status = await shizukuStatus();
      if (status != ShizukuStatus.authorized) {
        throw StateError(_shizukuStatusMessage(status));
      }
    }
    if (!await canInstallPackages()) {
      await requestInstallPermission();
      return false;
    }
    if (_installMethod == InstallMethod.shizuku) {
      try {
        return await _installChannel.invokeMethod<bool>('installWithShizuku', {
              'filePath': filePath,
            }) ??
            false;
      } on PlatformException catch (error) {
        throw StateError(error.message ?? 'Shizuku 安装失败');
      }
    }
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    return result.type == ResultType.done;
  }

  @override
  Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return false;
    return await _installChannel.invokeMethod<bool>('canInstallPackages') ??
        false;
  }

  @override
  Future<void> requestInstallPermission() async {
    if (!Platform.isAndroid) return;
    await _installChannel.invokeMethod<void>('requestInstallPermission');
  }

  @override
  Future<ApkInstallInfo> inspectInstall(String filePath) async {
    if (!Platform.isAndroid) return const ApkInstallInfo.unsupported();
    final raw = await _installChannel.invokeMethod<dynamic>('inspectInstall', {
      'filePath': filePath,
    });
    if (raw is! Map) return const ApkInstallInfo.unsupported();
    return ApkInstallInfo(
      supported: raw['supported'] == true,
      installed: raw['installed'] == true,
      versionMatches: raw['versionMatches'] == true,
      canOpen: raw['canOpen'] == true,
      packageName: _platformString(raw['packageName']),
      archiveVersionName: _platformString(raw['archiveVersionName']),
      archiveVersionCode: _platformInt(raw['archiveVersionCode']),
      installedVersionName: _platformString(raw['installedVersionName']),
      installedVersionCode: _platformInt(raw['installedVersionCode']),
      error: _platformString(raw['error']),
    );
  }

  @override
  Future<InstalledAppInfo?> inspectInstalledApp(String packageName) async {
    if (!Platform.isAndroid) return null;
    final normalized = packageName.trim();
    if (normalized.isEmpty) return null;
    final raw = await _installChannel.invokeMethod<dynamic>(
      'inspectInstalledApp',
      {'packageName': normalized},
    );
    if (raw is! Map) return null;
    final installedPackage = _platformString(raw['packageName']);
    if (installedPackage == null || installedPackage.isEmpty) return null;
    return InstalledAppInfo(
      packageName: installedPackage,
      versionName: _platformString(raw['versionName']),
      versionCode: _platformInt(raw['versionCode']),
    );
  }

  @override
  Future<List<InstalledAppInfo>> installedApps() async {
    if (!Platform.isAndroid) return const [];
    final raw = await _installChannel.invokeListMethod<dynamic>(
      'installedApps',
    );
    return [
      for (final item in raw ?? const <dynamic>[])
        InstalledAppInfo(
          packageName: item['packageName'] as String,
          versionName: item['versionName'] as String?,
          versionCode: item['versionCode'] as int?,
        ),
    ];
  }

  @override
  Future<bool> openInstalled(String packageName) async {
    if (!Platform.isAndroid) return false;
    return await _installChannel.invokeMethod<bool>('openInstalled', {
          'packageName': packageName,
        }) ??
        false;
  }

  @override
  void setInstallMethod(InstallMethod method) {
    _installMethod = method;
  }

  @override
  Future<ShizukuStatus> shizukuStatus() async {
    if (!supportsShizuku) return ShizukuStatus.unsupported;
    final value = await _installChannel.invokeMethod<String>('shizukuStatus');
    return _parseShizukuStatus(value);
  }

  @override
  Future<ShizukuStatus> requestShizukuPermission() async {
    if (!supportsShizuku) return ShizukuStatus.unsupported;
    final value = await _installChannel.invokeMethod<String>(
      'requestShizukuPermission',
    );
    return _parseShizukuStatus(value);
  }

  @override
  Future<void> dispose() async {
    final tabIds = {..._tabs.keys, ..._attachedTabs.keys};
    for (final id in tabIds) {
      await browserClose(id);
    }
    for (final id in _downloadSessions.keys.toList()) {
      final session = _downloadSessions[id];
      if (session == null) continue;
      session.canceled = true;
      session.preservePartialOnCancel = true;
      await session.subscription?.cancel();
      if (!session.done.isCompleted) session.done.complete();
      await session.finished.future;
    }
    _downloadSessions.clear();
    _client.close();
  }
}

ShizukuStatus _parseShizukuStatus(String? value) => switch (value) {
  'authorized' => ShizukuStatus.authorized,
  'denied' => ShizukuStatus.denied,
  'unavailable' => ShizukuStatus.unavailable,
  _ => ShizukuStatus.unsupported,
};

String _shizukuStatusMessage(ShizukuStatus status) => switch (status) {
  ShizukuStatus.authorized => '',
  ShizukuStatus.denied => 'Shizuku 未授予 APK Mesh 权限，请在设置中重新授权',
  ShizukuStatus.unavailable => '未检测到正在运行的 Shizuku，请先启动服务',
  ShizukuStatus.unsupported => '当前平台不支持 Shizuku 安装',
};

String? _platformString(dynamic value) => value is String ? value : null;

int? _platformInt(dynamic value) =>
    value is int ? value : int.tryParse('$value');

class _NativeDownloadSession {
  _NativeDownloadSession(this.destination, this.partial);

  final File destination;
  final File partial;
  final done = Completer<void>();
  final finished = Completer<void>();
  StreamSubscription<List<int>>? subscription;
  IOSink? sink;
  bool paused = false;
  bool canceled = false;
  bool preservePartialOnCancel = false;
}
