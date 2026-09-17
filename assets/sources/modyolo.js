/**
 * MODYOLO 源适配器
 * 流行 Android 应用与 Mod 游戏下载平台
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

function extractAttr(tag, name) {
  const match = new RegExp(`${name}=["']([^"']*)["']`, 'i').exec(tag || '');
  return match ? decodeHtml(match[1]).trim() : '';
}

globalThis.source = {
  manifest: {
    id: 'modyolo',
    name: 'MODYOLO',
    version: '1.0.0',
    homepage: 'https://modyolo.com/',
    description: '海量流行 Android 应用与 Mod 游戏下载平台',
    permissions: {
      network: ['modyolo.com', '*.modyolo.com'],
      browser: false,
      download: true,
      install: false
    },
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索应用',
        description: '在 MODYOLO 中搜索应用或 Mod。',
        inputLabel: '关键词',
        placeholder: '例如 subway surfers',
        defaultInput: 'subway surfers'
      },
      {
        id: 'app-details',
        name: '获取应用详情',
        description: '获取应用详情和直链下载项。',
        inputLabel: '应用详情页 URL',
        placeholder: '例如 https://modyolo.com/subway-surfers.html',
        defaultInput: 'https://modyolo.com/subway-surfers.html'
      }
    ]
  },

  async search(query, page = 1) {
    if (!query || !query.trim()) return [];
    const pageNum = Number(page) || 1;
    const url =
      pageNum === 1
        ? 'https://modyolo.com/?s=' + encodeURIComponent(query.trim())
        : `https://modyolo.com/page/${pageNum}/?s=` + encodeURIComponent(query.trim());

    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) return [];

    const results = [];
    const cardRegex = /<a[^>]+class=["'][^"']*archive-post[^"']*["'][^>]*href=["']([^"']+)["'][^>]*title=["']([^"']*)["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match;

    while ((match = cardRegex.exec(html)) !== null) {
      const itemUrl = match[1];
      const title = decodeHtml(match[2] || '');
      const content = match[3];

      const imgMatch = /<img[^>]+src=["']([^"']+)["']/i.exec(content);
      const iconUrl = imgMatch ? imgMatch[1] : '';

      // Extract version and size spans
      const alignMatches = [];
      const spanRegex = /<span[^>]+class=["'][^"']*align-middle[^"']*["'][^>]*>([\s\S]*?)<\/span>/gi;
      let sMatch;
      while ((sMatch = spanRegex.exec(content)) !== null) {
        const text = cleanText(sMatch[1]);
        if (text && text !== '+') {
          alignMatches.push(text);
        }
      }

      const version = alignMatches[0] || '';
      const size = alignMatches[1] || '';
      const summary = alignMatches.slice(2).join(' ') || '';

      results.push({
        id: itemUrl,
        name: title,
        packageName: '',
        version,
        size,
        category: '',
        iconUrl,
        summary
      });
    }

    return results;
  },

  async details(idOrUrl) {
    const url = idOrUrl.startsWith('http') ? idOrUrl : `https://modyolo.com/${idOrUrl}.html`;
    const html = await apkmesh.request(url, { headers: HEADERS });
    if (!html) {
      throw new Error('Failed to load MODYOLO detail page');
    }

    // Title
    const titleMatch = /<h1[^>]*>([\s\S]*?)<\/h1>/i.exec(html);
    const name = titleMatch ? cleanText(titleMatch[1].replace(/<[^>]+>/g, '')) : 'MODYOLO App';

    // Icon
    const iconMatch = /<div class=["'][^"']*flex-shrink-0[^"']*["'][^>]*>[\s\S]*?<img[^>]+src=["']([^"']+)["']/i.exec(html);
    const iconUrl = iconMatch ? iconMatch[1] : '';

    // Summary / short info
    let summary = '';
    const modMatch = /<div class=["']bg-warning[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(html);
    if (modMatch) {
      summary = cleanText(modMatch[1].replace(/<[^>]+>/g, ''));
    }

    // Description
    let description = summary;
    const descMatch = /<div[^>]+id=["']entry-content["'][^>]*>([\s\S]*?)<\/div>/i.exec(html) ||
      /<div class=["'][^"']*entry-content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(html);
    if (descMatch) {
      description = cleanText(descMatch[1].replace(/<[^>]+>/g, ' '));
    }

    // Version / Size
    let version = '';
    let size = '';
    const verMatch = /<th>Version<\/th>\s*<td>([^<]+)<\/td>/i.exec(html);
    if (verMatch) version = cleanText(verMatch[1]);
    const sizeMatch = /<th>Size<\/th>\s*<td>([^<]+)<\/td>/i.exec(html);
    if (sizeMatch) size = cleanText(sizeMatch[1]);

    // Screenshots
    const screenshots = [];
    const imgRegex = /<img[^>]+src=["'](https:\/\/modyolo\.com\/wp-content\/uploads\/[^"']+)["']/gi;
    let iMatch;
    while ((iMatch = imgRegex.exec(html)) !== null) {
      const src = iMatch[1];
      if (!src.includes('150x150') && !screenshots.includes(src)) {
        screenshots.push(src);
      }
    }

    // Download page link
    const downMatch = /href=["'](https:\/\/modyolo\.com\/download\/[^"']+)["']/i.exec(html);
    const downloads = [];

    if (downMatch) {
      const downPageUrl = downMatch[1];
      try {
        const downHtml = await apkmesh.request(downPageUrl, { headers: { ...HEADERS, Referer: url } });
        // Look for download subpage options
        const subRegex = /href=["'](https:\/\/modyolo\.com\/download\/[^"']+\/\d+)["'][^>]*>([\s\S]*?)<\/a>/gi;
        const subLinks = [];
        let sMatch;
        while ((sMatch = subRegex.exec(downHtml)) !== null) {
          subLinks.push({
            url: sMatch[1],
            text: cleanText(sMatch[2].replace(/<[^>]+>/g, ' '))
          });
        }

        // If sublinks exist, resolve up to 3 links
        const targetLinks = subLinks.length > 0 ? subLinks.slice(0, 3) : [{ url: downPageUrl + '/1', text: 'Download APK' }];

        for (const target of targetLinks) {
          try {
            const ajaxRes = await apkmesh.request('https://modyolo.com/wp-admin/admin-ajax.php?action=k_get_download', {
              headers: {
                ...HEADERS,
                'Referer': target.url,
                'X-Requested-With': 'XMLHttpRequest'
              }
            });

            const linkMatch = /href=["'](https:\/\/files[^"']+\.apk)["']/i.exec(ajaxRes);
            if (linkMatch) {
              const fileUrl = linkMatch[1];
              downloads.push({
                label: target.text || (version ? `MOD APK (${version})` : 'Download APK'),
                url: fileUrl,
                size
              });
            }
          } catch (_) {
            // continue with next download option
          }
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
      return this.details(input || 'https://modyolo.com/subway-surfers.html');
    }
    throw new Error(`Unknown debug project: ${projectId}`);
  }
};
