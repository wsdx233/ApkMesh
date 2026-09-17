/**
 * APKHome 源适配器
 * 经典 Android 应用与 Mod 游戏平台
 */

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
};

function decodeHtml(html) {
  if (!html) return '';
  return html
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&#8211;/g, '-')
    .replace(/&#8217;/g, "'");
}

function cleanText(text) {
  return decodeHtml((text || '').replace(/\s+/g, ' ')).trim();
}

globalThis.source = {
  manifest: {
    id: 'apkhome',
    name: 'APKHome',
    version: '1.0.0',
    homepage: 'https://apkhome.io/',
    description: '历史悠久的 Android 应用与 Mod 游戏下载站',
    permissions: {
      network: ['apkhome.io', 'apkhome.net', '*.apkhome.net'],
      browser: false,
      download: true,
      install: false
    },
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索应用',
        description: '在 APKHome 中搜索应用或 Mod。',
        inputLabel: '关键词',
        placeholder: '例如 subway surfers',
        defaultInput: 'subway surfers'
      },
      {
        id: 'app-details',
        name: '获取应用详情',
        description: '获取应用详情与 APK 直链下载。',
        inputLabel: '应用详情页 URL',
        placeholder: '例如 https://apkhome.net/subway-surfers-mod-apk/',
        defaultInput: 'https://apkhome.net/subway-surfers-mod-apk/'
      }
    ]
  },

  async search(query, page = 1) {
    if (!query || !query.trim()) return [];
    const pageNum = Number(page) || 1;
    const url =
      pageNum === 1
        ? 'https://apkhome.io/?s=' + encodeURIComponent(query.trim())
        : `https://apkhome.io/page/${pageNum}/?s=` + encodeURIComponent(query.trim());

    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) return [];

    const results = [];
    const cardRegex = /<a[^>]+href=["'](https:\/\/apkhome\.net\/[^"']+\/)["'][^>]*class=["']card-link["'][^>]*title=["']([^"']*)["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match;

    while ((match = cardRegex.exec(html)) !== null) {
      const itemUrl = match[1];
      const title = decodeHtml(match[2] || '');
      const content = match[3];

      // Extract image URL from data-lzl-bg or src
      const bgMatch = /data-lzl-bg=["']([^"']+)["']/i.exec(content);
      let iconUrl = bgMatch ? bgMatch[1] : '';
      if (!iconUrl) {
        const srcMatch = /src=["'](https:\/\/cdn\.apkhome\.net\/[^"']+)["']/i.exec(content);
        iconUrl = srcMatch ? srcMatch[1] : '';
      }

      // Extract mod info / summary
      const modMatch = /class=["']mod-info-badge["'][^>]*>([\s\S]*?)<\/div>/i.exec(content);
      const summary = modMatch ? cleanText(modMatch[1].replace(/<[^>]+>/g, '')) : '';

      // Extract category from data-cat
      const catMatch = /data-cat=["']([^"']*)["']/i.exec(content);
      const category = catMatch ? cleanText(catMatch[1]) : '';

      // Try extracting version from title
      const verMatch = /MOD\s+APK\s+([\d.]+)/i.exec(title) || /v?([\d.]+)/i.exec(title);
      const version = verMatch ? verMatch[1] : '';

      results.push({
        id: itemUrl,
        name: title,
        packageName: '',
        version,
        size: '',
        category,
        iconUrl,
        summary
      });
    }

    return results;
  },

  async details(idOrUrl) {
    const url = idOrUrl.startsWith('http') ? idOrUrl : `https://apkhome.net/${idOrUrl}/`;
    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) {
      throw new Error('Failed to load APKHome detail page');
    }

    // Title
    const titleMatch = /<h1[^>]*>([\s\S]*?)<\/h1>/i.exec(html);
    const name = titleMatch ? cleanText(titleMatch[1].replace(/<[^>]+>/g, '')) : 'APKHome App';

    // Description
    let description = '';
    const descMatch = /<article[^>]*>([\s\S]*?)<\/article>/i.exec(html);
    if (descMatch) {
      description = cleanText(descMatch[1].replace(/<script\b[\s\S]*?<\/script>/gi, '').replace(/<[^>]+>/g, ' '));
      if (description.length > 500) {
        description = description.substring(0, 500) + '...';
      }
    }

    // Icon & Screenshots
    let iconUrl = '';
    const screenshots = [];
    const imgRegex = /<img[^>]+src=["'](https:\/\/cdn\.apkhome\.net\/wp-content\/uploads\/[^"']+)["']/gi;
    let iMatch;
    while ((iMatch = imgRegex.exec(html)) !== null) {
      const src = iMatch[1];
      if (src.includes('cropped-') || src.includes('banner')) continue;
      if (!iconUrl) {
        iconUrl = src;
      } else if (!screenshots.includes(src)) {
        screenshots.push(src);
      }
    }

    // Version from title
    const verMatch = /MOD\s+APK\s+([\d.]+)/i.exec(name) || /v?([\d.]+)/i.exec(name);
    const version = verMatch ? verMatch[1] : '';

    // Downloads
    const downloads = [];
    const seenUrls = new Set();
    const apkRegex = /href=["'](https:\/\/dl\d*\.apkhome\.net\/[^"']+\.apk)["']/gi;
    let aMatch;
    while ((aMatch = apkRegex.exec(html)) !== null) {
      const dlUrl = aMatch[1];
      if (seenUrls.has(dlUrl)) continue;
      seenUrls.add(dlUrl);

      const filename = dlUrl.split('/').pop() || 'app.apk';
      downloads.push({
        label: filename,
        url: dlUrl,
        size: ''
      });
    }

    return {
      id: url,
      name,
      packageName: '',
      version,
      size: '',
      updatedAt: '',
      category: '',
      iconUrl,
      summary: '',
      description,
      screenshots,
      downloads,
      comments: []
    };
  },

  async debug(projectId, input) {
    if (projectId === 'search-keyword') {
      return this.search(input || 'subway surfers', 1);
    }
    if (projectId === 'app-details') {
      return this.details(input || 'https://apkhome.net/subway-surfers-mod-apk/');
    }
    throw new Error(`Unknown debug project: ${projectId}`);
  }
};
