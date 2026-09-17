/**
 * Modded-1 源适配器
 * 精选 Android 应用与 Mod 游戏下载平台
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
    id: 'modded1',
    name: 'Modded-1',
    version: '1.0.0',
    homepage: 'https://modded-1.com/',
    description: '精选 Android 应用与 Mod 游戏下载平台',
    permissions: {
      network: ['modded-1.com', '*.modded-1.com'],
      browser: false,
      download: true,
      install: false
    },
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索应用',
        description: '在 Modded-1 中搜索应用或 Mod。',
        inputLabel: '关键词',
        placeholder: '例如 subway surfers',
        defaultInput: 'subway surfers'
      },
      {
        id: 'app-details',
        name: '获取应用详情',
        description: '获取应用详情与 APK 直链下载。',
        inputLabel: '应用详情页 URL',
        placeholder: '例如 https://modded-1.com/games/action/subway-surfers-city',
        defaultInput: 'https://modded-1.com/games/action/subway-surfers-city'
      }
    ]
  },

  async search(query, page = 1) {
    if (!query || !query.trim()) return [];
    const pageNum = Number(page) || 1;
    const url =
      pageNum === 1
        ? 'https://modded-1.com/?s=' + encodeURIComponent(query.trim())
        : `https://modded-1.com/page/${pageNum}/?s=` + encodeURIComponent(query.trim());

    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) return [];

    const results = [];
    const postRegex = /<a[^>]+href=["'](https:\/\/modded-1\.com\/(?:apps|games)\/[^/]+\/[^/"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match;
    const seen = new Set();

    while ((match = postRegex.exec(html)) !== null) {
      const itemUrl = match[1];
      if (seen.has(itemUrl)) continue;
      seen.add(itemUrl);

      const content = match[2];
      const imgMatch = /<img[^>]+src=["']([^"']+)["']/i.exec(content);
      const iconUrl = imgMatch ? imgMatch[1] : '';

      // Title
      const titleMatch = /<h\d[^>]*>([\s\S]*?)<\/h\d>/i.exec(content) || /<div class=["']app-name["'][^>]*>([\s\S]*?)<\/div>/i.exec(content);
      let name = titleMatch ? cleanText(titleMatch[1].replace(/<[^>]+>/g, '')) : '';

      if (!name) {
        const slug = itemUrl.split('/').pop() || '';
        name = slug.replace(/-/g, ' ');
      }

      // Excerpt / summary
      const summaryMatch = /<p[^>]*class=["'][^"']*truncate[^"']*["'][^>]*>([\s\S]*?)<\/p>/i.exec(content) ||
        /<div[^>]*class=["'][^"']*app-mod[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(content);
      const summary = summaryMatch ? cleanText(summaryMatch[1].replace(/<[^>]+>/g, '')) : '';

      results.push({
        id: itemUrl,
        name,
        packageName: '',
        version: '',
        size: '',
        category: '',
        iconUrl,
        summary
      });
    }

    return results;
  },

  async details(idOrUrl) {
    const url = idOrUrl.startsWith('http') ? idOrUrl : `https://modded-1.com/${idOrUrl}`;
    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) {
      throw new Error('Failed to load Modded-1 detail page');
    }

    // Title
    const titleMatch = /<h1[^>]*>([\s\S]*?)<\/h1>/i.exec(html);
    const name = titleMatch ? cleanText(titleMatch[1].replace(/<[^>]+>/g, '')) : 'Modded-1 App';

    // Icon
    const iconMatch = /<div class=["'][^"']*app-icon[^"']*["'][^>]*>\s*<img[^>]+src=["']([^"']+)["']/i.exec(html) ||
      /<img[^>]+src=["'](https:\/\/static\.modded-1\.com\/[^"']+)["']/i.exec(html);
    const iconUrl = iconMatch ? iconMatch[1] : '';

    // Description
    let description = '';
    const descMatch = /<div class=["'][^"']*entry-content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(html);
    if (descMatch) {
      description = cleanText(descMatch[1].replace(/<script\b[\s\S]*?<\/script>/gi, '').replace(/<[^>]+>/g, ' '));
      if (description.length > 500) {
        description = description.substring(0, 500) + '...';
      }
    }

    // Table info (Version, Size, Mod Features, Updated On)
    let version = '';
    let size = '';
    let summary = '';
    let updatedAt = '';

    const verMatch = /<th>Version<\/th>\s*<td>([^<]+)<\/td>/i.exec(html);
    if (verMatch) version = cleanText(verMatch[1]);

    const sizeMatch = /<th>Size<\/th>\s*<td>([^<]+)<\/td>/i.exec(html);
    if (sizeMatch) size = cleanText(sizeMatch[1]);

    const modMatch = /<th>MOD Features<\/th>\s*<td>([^<]+)<\/td>/i.exec(html);
    if (modMatch) summary = cleanText(modMatch[1]);

    const dateMatch = /<th>Updated On<\/th>\s*<td>([^<]+)<\/td>/i.exec(html);
    if (dateMatch) updatedAt = cleanText(dateMatch[1]);

    // Screenshots
    const screenshots = [];
    const imgRegex = /<img[^>]+src=["'](https:\/\/modded-1\.com\/wp-content\/uploads\/[^"']+)["']/gi;
    let iMatch;
    while ((iMatch = imgRegex.exec(html)) !== null) {
      const src = iMatch[1];
      if (!src.includes('cropped-') && !screenshots.includes(src)) {
        screenshots.push(src);
      }
    }

    // Downloads
    const downloads = [];
    const downMatch = /<a[^>]+href=["'](https:\/\/modded-1\.com\/[^"']*\/download\/[^"']*)["']/i.exec(html);
    if (downMatch) {
      const downPageUrl = downMatch[1];
      try {
        const downHtml = await apkmesh.request(downPageUrl, { headers: { ...HEADERS, Referer: url } });
        const dlRegex = /<a[^>]+href=["'](https:\/\/dl\.modded-1\.com\/\d+)["'][^>]*>([\s\S]*?)<\/a>/gi;
        let dMatch;
        while ((dMatch = dlRegex.exec(downHtml)) !== null) {
          downloads.push({
            label: summary ? `MOD APK (${summary})` : (version ? `Download APK (${version})` : 'Download APK'),
            url: dMatch[1],
            size
          });
        }
      } catch (_) {
        // failed loading download page
      }
    }

    return {
      id: url,
      name,
      packageName: '',
      version,
      size,
      updatedAt,
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
      return this.details(input || 'https://modded-1.com/games/action/subway-surfers-city');
    }
    throw new Error(`Unknown debug project: ${projectId}`);
  }
};
