/**
 * 应用宝 (Tencent MyApp) 源适配器
 * 腾讯官方 Android 应用市场
 */

const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

function formatSize(bytes) {
  const n = typeof bytes === 'string' ? parseInt(bytes, 10) : bytes;
  if (!n || isNaN(n) || n <= 0) return '';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB';
  if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + ' MB';
  return (n / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

function parseNextData(html) {
  const match = html.match(/<script[^>]+id=["']__NEXT_DATA__["'][^>]*>([\s\S]*?)<\/script>/);
  if (!match) return null;
  try {
    return JSON.parse(match[1]);
  } catch (_) {
    return null;
  }
}

function fixUrl(url) {
  if (!url) return '';
  if (url.startsWith('http://')) {
    return 'https://' + url.substring(7);
  }
  return url;
}

function isAndroidApp(item) {
  if (!item || typeof item !== 'object') return false;
  const pkg = String(item.pkg_name || '');
  // 过滤 PC 端应用/模拟器游戏 (如 com.tencent.pcgame.*, com.*.pcapp.*)
  if (
    pkg.includes('.pcgame.') ||
    pkg.includes('.pcapp.') ||
    pkg.startsWith('com.tencent.pcgame.') ||
    pkg.startsWith('com.tencent.pcapp.')
  ) {
    return false;
  }
  const apkUrl = String(item.apk_url || '');
  const downloadUrl = String(item.download_url || '');
  const exeUrl = String(item.exe_download_url || '');
  // 过滤 Windows 可执行安装包 (.exe)
  if (
    exeUrl ||
    apkUrl.toLowerCase().endsWith('.exe') ||
    downloadUrl.toLowerCase().endsWith('.exe')
  ) {
    return false;
  }
  // 校验包名基本格式
  if (!pkg.includes('.') || pkg.length < 3) {
    return false;
  }
  return Boolean(downloadUrl || apkUrl);
}

globalThis.source = {
  manifest: {
    id: 'myapp',
    name: '应用宝',
    version: '1.0.0',
    homepage: 'https://sj.qq.com',
    description: '腾讯应用宝官方应用市场',
    permissions: {
      network: ['sj.qq.com', '*.qq.com', '*.myapp.com', '*.qpic.cn'],
      browser: false,
      download: true,
      install: false
    },
    packageLookup: true,
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索应用',
        description: '在应用宝中搜索 Android 应用。',
        inputLabel: '关键词',
        placeholder: '例如 微信',
        defaultInput: '微信'
      },
      {
        id: 'app-details',
        name: '获取应用详情',
        description: '读取应用宝中的应用详情及下载链接。',
        inputLabel: '包名或详情 URL',
        placeholder: '例如 com.tencent.mm',
        defaultInput: 'com.tencent.mm'
      }
    ]
  },

  packageLookupUrl(pkg) {
    return 'https://sj.qq.com/appdetail/' + encodeURIComponent(pkg);
  },

  async search(query, page = 1) {
    if (!query || !query.trim()) return [];
    if (page > 1) {
      // 应用宝网页搜索为单页聚合结果
      return [];
    }

    const url = 'https://sj.qq.com/search?q=' + encodeURIComponent(query.trim());
    const html = await apkmesh.request(url, {
      headers: {
        'User-Agent': MOBILE_UA,
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    });

    const data = parseNextData(html);
    if (!data) return [];

    const comps =
      data?.props?.pageProps?.dynamicCardResponse?.data?.components || [];
    const results = [];
    const seen = new Set();

    for (const comp of comps) {
      const items = comp?.data?.itemData;
      if (!Array.isArray(items)) continue;

      for (const item of items) {
        if (!isAndroidApp(item)) continue;

        const pkgName = item.pkg_name;
        if (!pkgName || seen.has(pkgName)) continue;
        seen.add(pkgName);

        const name = item.name || pkgName;
        const icon = fixUrl(item.icon || '');
        const size = formatSize(item.apk_size);
        const version = item.version_name || '';
        const summary = item.editor_intro || item.show_text || '';
        const category = item.cate_name_new || item.cate_name || '';

        results.push({
          id: 'https://sj.qq.com/appdetail/' + pkgName,
          name,
          packageName: pkgName,
          version,
          size,
          category,
          iconUrl: icon,
          summary
        });
      }

      // 若主力搜索卡片已解析出结果，则不再混入下方热门/相似推荐
      if (comp?.cardId === 'YYB_HOME_SEARCH_NORMAL_GAME' && results.length > 0) {
        break;
      }
    }

    return results;
  },

  async details(idOrUrl) {
    let pkg = idOrUrl;
    if (pkg.includes('/')) {
      const parts = pkg.split('/').filter(Boolean);
      pkg = parts[parts.length - 1];
    }

    const url = 'https://sj.qq.com/appdetail/' + encodeURIComponent(pkg);
    const html = await apkmesh.request(url, {
      headers: {
        'User-Agent': MOBILE_UA,
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    });

    const data = parseNextData(html);
    if (!data) {
      throw new Error('Failed to parse MyApp detail page data');
    }

    const comps =
      data?.props?.pageProps?.dynamicCardResponse?.data?.components || [];

    let targetItem = null;
    for (const comp of comps) {
      if (comp?.cardId === 'yybn_game_basic_info') {
        const items = comp?.data?.itemData;
        if (Array.isArray(items) && items.length > 0) {
          targetItem = items[0];
          break;
        }
      }
    }

    if (!targetItem || !isAndroidApp(targetItem)) {
      for (const comp of comps) {
        const items = comp?.data?.itemData;
        if (Array.isArray(items)) {
          for (const item of items) {
            if (item.pkg_name === pkg && isAndroidApp(item)) {
              targetItem = item;
              break;
            }
          }
        }
        if (targetItem) break;
      }
    }

    if (!targetItem) {
      throw new Error(`未在应用宝找到该 Android 应用详情 (${pkg})`);
    }

    if (!isAndroidApp(targetItem)) {
      throw new Error(`该条目为 PC 版应用，非 Android APK 安装包 (${pkg})`);
    }

    const name = targetItem.name || pkg;
    const pkgName = targetItem.pkg_name || pkg;
    const version = targetItem.version_name || '';
    const size = formatSize(targetItem.apk_size);
    const iconUrl = fixUrl(targetItem.icon || '');
    const summary = targetItem.editor_intro || targetItem.show_text || '';
    const description = targetItem.description || summary;
    const category = targetItem.cate_name_new || targetItem.cate_name || '';

    const screenshots = [];
    if (typeof targetItem.snap_shots === 'string' && targetItem.snap_shots.trim()) {
      const shots = targetItem.snap_shots.split(',');
      for (const shot of shots) {
        const clean = shot.trim();
        if (clean) screenshots.push(fixUrl(clean));
      }
    } else if (Array.isArray(targetItem.audited_snapshots)) {
      for (const s of targetItem.audited_snapshots) {
        if (s) screenshots.push(fixUrl(s));
      }
    }

    const downloads = [];
    let rawDownload = targetItem.download_url || targetItem.apk_url || '';
    if (rawDownload && !rawDownload.toLowerCase().endsWith('.exe')) {
      const downloadUrl = fixUrl(rawDownload);
      downloads.push({
        label: `官方下载 (${version || '最新版'})`,
        url: downloadUrl,
        size,
        headers: {
          'User-Agent': MOBILE_UA
        }
      });
    }

    return {
      id: url,
      name,
      packageName: pkgName,
      version,
      size,
      updatedAt: targetItem.app_update_time || targetItem.update_time || '',
      category,
      iconUrl,
      summary,
      description,
      screenshots,
      downloads,
      comments: []
    };
  },

  async debug(projectId, input) {
    if (projectId === 'search-keyword') {
      return this.search(input || '微信', 1);
    }
    if (projectId === 'app-details') {
      return this.details(input || 'com.tencent.mm');
    }
    throw new Error(`Unknown debug project: ${projectId}`);
  }
};
