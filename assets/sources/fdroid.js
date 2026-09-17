/** F-Droid source for APK Mesh. */
const ORIGIN = 'https://f-droid.org';
const SEARCH_ORIGIN = 'https://search.f-droid.org';
const HEADERS = {
  Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
  Referer: `${ORIGIN}/`,
  'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36',
};

const CATALOG_TABS = [
  {id: 'multimedia', name: '影音媒体', query: 'player'},
  {id: 'internet', name: '网络通信', query: 'browser'},
  {id: 'security', name: '安全与隐私', query: 'vpn'},
  {id: 'system', name: '系统工具', query: 'tools'},
  {id: 'development', name: '开发工具', query: 'development'},
  {id: 'games', name: '开源游戏', query: 'game'},
];

function decodeHtml(value) {
  return String(value || '')
    .replace(/&#x([0-9a-f]+);?/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);?/g, (_, decimal) => String.fromCodePoint(parseInt(decimal, 10)))
    .replace(/&(amp|lt|gt|quot|apos|nbsp);/gi, (_, entity) => ({
      amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
    })[entity.toLowerCase()] || `&${entity};`);
}

function cleanText(value) {
  return decodeHtml(String(value || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ')).trim();
}

function absoluteUrl(value, base = ORIGIN) {
  const url = cleanText(value);
  if (!url) return '';
  if (url.startsWith('//')) return `https:${url}`;
  if (/^https?:\/\//i.test(url)) return url.replace(/^http:\/\//i, 'https://');
  const origin = (/^(https?:\/\/[^/]+)/i.exec(base) || [null, ORIGIN])[1];
  if (url.startsWith('/')) return `${origin}${url}`;
  return `${origin}/${url.replace(/^\/+/, '')}`;
}

function isPackageUrl(url) {
  return /^https:\/\/(?:www\.)?f-droid\.org\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?packages\/[a-zA-Z0-9._]+(?:\/|$)/i.test(url || '');
}

function extractPackageName(url) {
  const match = /\/packages\/([a-zA-Z0-9._]+)(?:\/|$)/i.exec(url || '');
  return match ? match[1] : '';
}

function uniqueBy(items, key) {
  return (items || []).filter((item, index, all) => item && all.findIndex((candidate) => candidate[key] === item[key]) === index);
}

async function fetchText(url) {
  return apkmesh.request(url, {headers: HEADERS});
}

function parseCards(html, page = 1) {
  // Check if pagination clamped (e.g. requested page 5 but only 2 pages exist)
  if (page > 1) {
    const currentStepMatch = /<span\s+class=["']step-links["']>\s*<u>\s*(\d+)\s*<\/u>/i.exec(html || '');
    if (currentStepMatch) {
      const activePage = parseInt(currentStepMatch[1], 10);
      if (activePage !== page) {
        return [];
      }
    }
  }

  const results = [];
  const pattern = /<a\s+class=["']package-header["']\s+href=["']([^"']+)["']>([\s\S]*?)<\/a>/gi;
  for (const match of String(html || '').matchAll(pattern)) {
    const href = match[1];
    const block = match[2];
    const id = absoluteUrl(href, ORIGIN);
    const packageName = extractPackageName(id);
    if (!packageName) continue;

    const iconMatch = /<img\s+class=["']package-icon["']\s+src=["']([^"']+)["']/i.exec(block);
    const nameMatch = /<h4\s+class=["']package-name["']>([\s\S]*?)<\/h4>/i.exec(block);
    const descMatch = /<span\s+class=["']package-summary["']>([\s\S]*?)<\/span>/i.exec(block);
    const licenseMatch = /<span\s+class=["']package-license["']>([\s\S]*?)<\/span>/i.exec(block);

    const name = cleanText(nameMatch ? nameMatch[1] : packageName);
    const iconUrl = iconMatch ? absoluteUrl(iconMatch[1], ORIGIN) : '';
    const summary = cleanText(descMatch ? descMatch[1] : '');
    const category = cleanText(licenseMatch ? licenseMatch[1] : '');

    results.push({
      id,
      name,
      packageName,
      version: '',
      size: '',
      updatedAt: '',
      category,
      iconUrl,
      summary,
    });
  }
  return uniqueBy(results, 'id');
}

function parseDetails(html, url) {
  const packageName = extractPackageName(url);
  const nameMatch = /<h3\s+class=["']package-name["']>([\s\S]*?)<\/h3>/i.exec(html);
  const iconMatch = /<img\s+class=["']package-icon["'][^>]*src=["']([^"']+)["']/i.exec(html);
  const summaryMatch = /<div\s+class=["']package-summary["']>([\s\S]*?)<\/div>/i.exec(html);
  const descMatch = /<div\s+class=["']package-description["'][^>]*>([\s\S]*?)<\/div>/i.exec(html);
  const categoryMatch = /<li\s+class=["']package-link["']\s+id=["']category["']>[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i.exec(html);

  const name = cleanText(nameMatch ? nameMatch[1] : packageName);
  const iconUrl = iconMatch ? absoluteUrl(iconMatch[1], ORIGIN) : '';
  const summary = cleanText(summaryMatch ? summaryMatch[1] : '');
  const description = cleanText(descMatch ? descMatch[1] : summary);
  const category = cleanText(categoryMatch ? categoryMatch[1] : '开源应用');

  // Screenshots
  const screenshots = [];
  const screenPattern = /<li\s+class=["']js_slide\s+screenshot["']>\s*<img[^>]*src=["']([^"']+)["']/gi;
  for (const m of String(html || '').matchAll(screenPattern)) {
    const shot = absoluteUrl(m[1], ORIGIN);
    if (shot && !screenshots.includes(shot)) {
      screenshots.push(shot);
    }
  }

  // Version downloads
  const downloads = [];
  const parts = String(html || '').split('<li class="package-version"');
  for (let i = 1; i < parts.length; i += 1) {
    const part = parts[i];
    const verMatch = /<b>Version\s+([^<]+)<\/b>/i.exec(part);
    const codeMatch = /<code\s+class=["']package-nativecode["']>([^<]+)<\/code>/i.exec(part);
    const apkMatch = /<a\s+href=["'](https?:\/\/[^"']+\.apk)["']>\s*Download APK/i.exec(part);
    const sizeMatch = /Download APK\s*<\/a>\s*<\/b>\s*([\d.]+\s*[KMGT]?i?B)/i.exec(part);

    if (apkMatch) {
      const verName = verMatch ? cleanText(verMatch[1]) : '';
      const abi = codeMatch ? cleanText(codeMatch[1]) : '';
      const size = sizeMatch ? cleanText(sizeMatch[1]) : '';
      const downloadUrl = absoluteUrl(apkMatch[1], ORIGIN);

      let label = verName ? `v${verName}` : 'APK';
      if (abi) label += ` (${abi})`;

      downloads.push({
        label,
        url: downloadUrl,
        size,
      });
    }
  }

  const latestVersion = downloads[0] ? downloads[0].label.replace(/^v/, '').replace(/\s*\(.*\)$/, '') : '';
  const latestSize = downloads[0] ? downloads[0].size : '';

  return {
    id: url,
    name,
    packageName,
    version: latestVersion,
    size: latestSize,
    updatedAt: '',
    category,
    iconUrl,
    summary,
    description,
    screenshots,
    downloads: uniqueBy(downloads, 'url'),
    comments: [],
  };
}

globalThis.source = {
  manifest: {
    id: 'fdroid',
    name: 'F-Droid',
    version: '1.0.0',
    minApiVersion: 1,
    homepage: `${ORIGIN}/`,
    description: '全球最大的开源 Android 应用仓库，提供自由及开源软件搜索、版本和 APK 下载。',
    packageLookup: true,
    permissions: {
      network: ['f-droid.org', '*.f-droid.org', '*.fau.de'],
      browser: false,
      download: true,
      install: false,
    },
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索关键词',
        description: '在 F-Droid 中搜索开源应用。',
        inputLabel: '关键词',
        placeholder: '例如 vlc',
        defaultInput: 'vlc',
      },
      {
        id: 'app-details',
        name: '获取应用详情',
        description: '读取应用版本、截图与 APK 下载链接。',
        inputLabel: '应用 URL',
        placeholder: '粘贴 F-Droid 应用详情页地址',
        defaultInput: 'https://f-droid.org/en/packages/org.videolan.vlc/',
      },
    ],
  },

  async catalog() {
    return {
      defaultTabId: 'multimedia',
      tabs: CATALOG_TABS.map((tab) => ({id: tab.id, name: tab.name, paged: true})),
    };
  },

  async catalogPage(tabId, page = 1) {
    const tab = CATALOG_TABS.find((item) => item.id === tabId);
    if (!tab) throw new TypeError(`无效的 F-Droid 目录标签：${tabId}`);
    const apps = await this.search(tab.query, page);
    return {
      apps,
      hasMore: apps.length >= 10,
    };
  },

  async search(query, page = 1) {
    const value = cleanText(query);
    if (!value) return [];
    const pageNum = Math.max(1, Number(page) || 1);
    const searchUrl = `${SEARCH_ORIGIN}/?q=${encodeURIComponent(value)}&page=${pageNum}`;
    const html = await fetchText(searchUrl);
    return parseCards(html, pageNum);
  },

  async packageLookupUrl(packageName) {
    const pkg = cleanText(packageName);
    if (!/^[a-zA-Z0-9._]+$/.test(pkg)) return null;
    return `${ORIGIN}/en/packages/${encodeURIComponent(pkg)}/`;
  },

  async details(idOrUrl) {
    const raw = cleanText(idOrUrl);
    let targetUrl = raw;
    if (!isPackageUrl(targetUrl)) {
      if (/^[a-zA-Z0-9._]+$/.test(raw)) {
        targetUrl = `${ORIGIN}/en/packages/${encodeURIComponent(raw)}/`;
      } else {
        throw new TypeError(`无效的 F-Droid 应用地址：${idOrUrl}`);
      }
    }
    const html = await fetchText(targetUrl);
    return parseDetails(html, targetUrl);
  },

  async debug(projectId, input) {
    const value = cleanText(input);
    if (projectId === 'search-keyword') {
      const results = await this.search(value, 1);
      return {title: '搜索完成', summary: `返回 ${results.length} 条结果`, data: results};
    }
    if (projectId === 'app-details') {
      const app = await this.details(value);
      return {
        title: '详情读取完成',
        summary: `已读取 ${app.name}；下载项 ${app.downloads.length} 个`,
        data: app,
      };
    }
    throw new Error(`未知调试项目：${projectId}`);
  },
};
