/**
 * 5Play 源适配器
 * 知名 Android 游戏与 Mod 平台
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
    id: 'fiveplay',
    name: '5Play',
    version: '1.0.0',
    homepage: 'https://5play.org/',
    description: '丰富多样的 Android 游戏与应用下载平台',
    permissions: {
      network: ['5play.org', '*.5play.org', '*.r2.cloudflarestorage.com'],
      browser: false,
      download: true,
      install: false
    },
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索应用',
        description: '在 5Play 中搜索应用或游戏。',
        inputLabel: '关键词',
        placeholder: '例如 subway surfers',
        defaultInput: 'subway surfers'
      },
      {
        id: 'app-details',
        name: '获取应用详情',
        description: '获取应用详情与直链下载项。',
        inputLabel: '应用详情页 URL',
        placeholder: '例如 https://5play.org/15-subway-surfers.html',
        defaultInput: 'https://5play.org/15-subway-surfers.html'
      }
    ]
  },

  async search(query, page = 1) {
    if (!query || !query.trim()) return [];
    const pageNum = Number(page) || 1;
    let url =
      'https://5play.org/?do=search&subaction=search&story=' +
      encodeURIComponent(query.trim());
    if (pageNum > 1) {
      url += `&search_start=${pageNum}`;
    }

    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) return [];

    const results = [];
    const itemRegex = /<div class=["']search-item item["']>([\s\S]*?)<\/div>\s*<i class=/gi;
    let match;

    while ((match = itemRegex.exec(html)) !== null) {
      const content = match[1];

      const linkMatch = /<a[^>]+href=["'](https:\/\/5play\.org\/[^"']+\.html)["'][^>]*>([\s\S]*?)<\/a>/i.exec(content);
      if (!linkMatch) continue;

      const itemUrl = linkMatch[1];
      const title = cleanText(linkMatch[2].replace(/<[^>]+>/g, ''));

      const imgMatch = /<img[^>]+src=["']([^"']+)["']/i.exec(content);
      const iconUrl = imgMatch ? imgMatch[1] : '';

      const catMatch = /<div class=["']search-item-cat["']>([\s\S]*?)<\/div>/i.exec(content);
      const category = catMatch ? cleanText(catMatch[1].replace(/<[^>]+>/g, '')) : '';

      results.push({
        id: itemUrl,
        name: title,
        packageName: '',
        version: '',
        size: '',
        category,
        iconUrl,
        summary: ''
      });
    }

    return results;
  },

  async details(idOrUrl) {
    const url = idOrUrl.startsWith('http') ? idOrUrl : `https://5play.org/${idOrUrl}.html`;
    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) {
      throw new Error('Failed to load 5Play detail page');
    }

    // Title
    const titleMatch = /<h1[^>]*>([\s\S]*?)<\/h1>/i.exec(html);
    const name = titleMatch ? cleanText(titleMatch[1].replace(/<[^>]+>/g, '')) : '5Play App';

    // Summary / Mod info from page title
    let summary = '';
    const pageTitleMatch = /<title>([\s\S]*?)<\/title>/i.exec(html);
    if (pageTitleMatch) {
      const fullTitle = cleanText(pageTitleMatch[1]);
      const modInTitle = /\(([^)]+)\)/.exec(fullTitle);
      if (modInTitle) {
        summary = modInTitle[1];
      }
    }

    // Description from meta
    let description = '';
    const metaDesc = /<meta\s+name=["']description["']\s+content=["']([^"']*)["']/i.exec(html);
    if (metaDesc) {
      description = cleanText(metaDesc[1]);
    }

    // Icon (first posts/ image with width="200")
    let iconUrl = '';
    const iconMatch = /<img[^>]+width=["']200["'][^>]+src=["'](https:\/\/cdn\.5play\.org\/posts\/[^"']+)["']/i.exec(html) ||
      /<figure class=["']cover["']>\s*<img[^>]+src=["'](https:\/\/cdn\.5play\.org\/posts\/[^"']+)["']/i.exec(html);
    if (iconMatch) {
      iconUrl = iconMatch[1];
    }

    // Screenshots (/medium/ images)
    const screenshots = [];
    const screenRegex = /<img[^>]+src=["'](https:\/\/cdn\.5play\.org\/posts\/[^"']*medium\/[^"']+)["']/gi;
    let sMatch;
    while ((sMatch = screenRegex.exec(html)) !== null) {
      screenshots.push(sMatch[1]);
    }

    // Version from title or meta
    let version = '';
    const verMatch = /[\s_]([\d.]+)\s*(?:APK|Мод)/i.exec(name) || /[\s_]([\d.]+)\s*(?:APK|Мод)/i.exec(pageTitleMatch?.[1] || '');
    if (verMatch) {
      version = verMatch[1];
    }

    // Downloads from CDN links
    const downloads = [];
    const cdnRegex = /href=["'](https:\/\/5play\.org\/index\.php\?do=cdn&amp;id=\d+|https:\/\/5play\.org\/index\.php\?do=cdn&id=\d+)["']/gi;
    let cMatch;
    const cdnUrls = [];
    while ((cMatch = cdnRegex.exec(html)) !== null) {
      const cdnLink = cMatch[1].replace(/&amp;/g, '&');
      if (!cdnUrls.includes(cdnLink)) {
        cdnUrls.push(cdnLink);
      }
    }

    for (const cdnLink of cdnUrls) {
      try {
        const cdnHtml = await apkmesh.request(cdnLink, {
          headers: { ...HEADERS, Referer: url }
        });

        const r2Match = /href=["'](https:\/\/[^"']*r2\.cloudflarestorage\.com\/[^"']+)["']/i.exec(cdnHtml);
        if (r2Match) {
          const directUrl = decodeHtml(r2Match[1]);
          downloads.push({
            label: summary ? `MOD APK (${summary})` : (version ? `Download APK (${version})` : 'Download APK'),
            url: directUrl,
            size: ''
          });
        }
      } catch (_) {
        // continue
      }
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
      summary,
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
      return this.details(input || 'https://5play.org/15-subway-surfers.html');
    }
    throw new Error(`Unknown debug project: ${projectId}`);
  }
};
