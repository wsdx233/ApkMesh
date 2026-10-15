/** APKCube source for APK Mesh. */
const ORIGIN = 'https://apkcube.com';
const HOSTS = ['apkcube.com', 'www.apkcube.com'];
const IMAGE_HOSTS = ['icons.apkcube.com', 'play-lh.googleusercontent.com'];
const HEADERS = {
  Accept: 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.8',
  Referer: `${ORIGIN}/`,
  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36',
};

function decodeHtml(value) {
  return String(value || '')
    .replace(/&#x([0-9a-f]+);?/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);?/g, (_, decimal) => String.fromCodePoint(parseInt(decimal, 10)))
    .replace(/&(amp|lt|gt|quot|apos|nbsp);/gi, (_, entity) => ({
      amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
    })[entity.toLowerCase()] || `&${entity};`);
}

function cleanText(value) {
  return decodeHtml(String(value || '').replace(/\s+/g, ' ')).trim();
}

function textFromHtml(value) {
  return cleanText(String(value || '')
    .replace(/<script\b[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' '));
}

function attribute(tag, name) {
  const escaped = String(name).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = new RegExp(`\\b${escaped}\\s*=\\s*(["'])([\\s\\S]*?)\\1`, 'i').exec(tag || '');
  return match ? decodeHtml(match[2]).trim() : '';
}

function hostOf(url) {
  const match = /^https:\/\/([^/?#]+)/i.exec(String(url || '').trim());
  return match ? match[1].toLowerCase() : '';
}

function allowedUrl(value, base = ORIGIN, hosts = HOSTS) {
  const raw = cleanText(value);
  if (!raw) return '';
  let url = raw;
  if (url.startsWith('//')) url = `https:${url}`;
  else if (!/^https:\/\//i.test(url)) {
    if (/^https?:\/\//i.test(url)) return '';
    if (url.startsWith('/')) url = `${ORIGIN}${url}`;
    else {
      const cleanBase = String(base || ORIGIN).replace(/[?#].*$/, '');
      const prefix = /^https:\/\/[^/]+$/i.test(cleanBase)
        ? `${cleanBase}/`
        : cleanBase.replace(/\/[^/]*$/, '/');
      url = `${prefix}${url}`;
    }
  }
  if (!/^https:\/\/[^/?#]+(?:[/?#]|$)/i.test(url)) return '';
  const host = hostOf(url);
  if (!hosts.includes(host) || /@/.test(host)) return '';
  return url;
}

function isDetailUrl(url) {
  return /^https:\/\/(?:www\.)?apkcube\.com\/[a-z0-9][a-z0-9-]*\/[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+\/?(?:[?#].*)?$/i.test(url || '');
}

function packageFromUrl(url) {
  const match = /^https:\/\/(?:www\.)?apkcube\.com\/[^/?#]+\/([^/?#]+)\/?(?:[?#].*)?$/i.exec(url || '');
  return match ? cleanText(match[1]) : '';
}

function uniqueBy(items, key) {
  return (items || []).filter((item, index, all) => item && item[key] && all.findIndex((other) => other[key] === item[key]) === index);
}

function uniqueStrings(items) {
  return (items || []).filter((item, index, all) => item && all.indexOf(item) === index);
}

function extractVersion(value) {
  const match = /\bv?(\d+(?:\.\d+)+(?:[-._][a-z0-9]+)*)\b/i.exec(textFromHtml(value));
  return match ? match[1] : '';
}

function extractSize(value) {
  const match = /\b\d+(?:\.\d+)?\s*(?:B|KB|MB|GB|TB)\b/i.exec(textFromHtml(value));
  return match ? match[0] : '';
}

function metaContent(html, key, property = 'name') {
  const escaped = String(key).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = new RegExp(`<meta\\b[^>]*\\b${property}\\s*=\\s*["']${escaped}["'][^>]*>`, 'i').exec(html || '');
  return match ? attribute(match[0], 'content') : '';
}

function firstText(html, pattern) {
  const match = pattern.exec(html || '');
  return match ? textFromHtml(match[1]) : '';
}

function parseStructuredApp(html) {
  function visit(value) {
    if (!value || typeof value !== 'object') return null;
    if (Array.isArray(value)) {
      for (const item of value) {
        const found = visit(item);
        if (found) return found;
      }
      return null;
    }
    const type = value['@type'];
    const types = Array.isArray(type) ? type : [type];
    if (types.some((item) => String(item || '').toLowerCase() === 'softwareapplication')) return value;
    if (value.mainEntity) {
      const found = visit(value.mainEntity);
      if (found) return found;
    }
    if (value['@graph']) {
      const found = visit(value['@graph']);
      if (found) return found;
    }
    return null;
  }
  for (const match of String(html || '').matchAll(/<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    try {
      const found = visit(JSON.parse(match[1].trim()));
      if (found) return found;
    } catch (_) {
      // Ignore malformed or unrelated JSON-LD blocks.
    }
  }
  return {};
}

function structuredUrls(value, base, hosts = HOSTS) {
  const values = Array.isArray(value) ? value : value ? [value] : [];
  return uniqueStrings(values.map((item) => allowedUrl(typeof item === 'string' ? item : item && (item.contentUrl || item.url || item.content), base, hosts)).filter(Boolean));
}

function isDownloadPageUrl(url, detailUrl) {
  const detail = String(detailUrl || '').replace(/[?#].*$/, '').replace(/\/$/, '');
  const page = String(url || '').replace(/[?#].*$/, '').replace(/\/$/, '');
  return !!page && !!detail && page.toLowerCase() === `${detail.toLowerCase()}/download`;
}

function isDirectDownloadUrl(url) {
  if (!allowedUrl(url)) return false;
  const path = String(url).split(/[?#]/)[0].toLowerCase();
  if (/\/(?:download|download-token)(?:\/|$)/.test(path)) return false;
  return /\.(?:apk|xapk|apks|zip)$/i.test(path);
}

function parseSearchResults(html) {
  const results = [];
  for (const match of String(html || '').matchAll(/<a\b([^>]*\bhref\s*=\s*["'][^"']+["'][^>]*)>([\s\S]*?)<\/a>/gi)) {
    const tag = `<a${match[1]}>`;
    const id = allowedUrl(attribute(tag, 'href'));
    if (!isDetailUrl(id)) continue;
    const block = match[2];
    const image = /<img\b[^>]*>/i.exec(block);
    const name = cleanText(attribute(tag, 'aria-label') || attribute(tag, 'title') || firstText(block, /<h[1-6]\b[^>]*>([\s\S]*?)<\/h[1-6]>/i) || firstText(block, /<p\b[^>]*>([\s\S]*?)<\/p>/i) || (image && attribute(image[0], 'alt')) || textFromHtml(block));
    if (!name) continue;
    const metadata = textFromHtml(block);
    results.push({
      id,
      name: name.replace(/\s+(?:APK|Android App)\s*$/i, '').trim(),
      packageName: packageFromUrl(id),
      version: extractVersion(metadata),
      size: extractSize(metadata),
      updatedAt: '',
      category: '',
      iconUrl: image ? allowedUrl(attribute(image[0], 'data-src') || attribute(image[0], 'data-lazy-src') || attribute(image[0], 'src'), id, [...HOSTS, ...IMAGE_HOSTS]) : '',
      summary: '',
    });
  }
  return uniqueBy(results, 'id');
}

function labelledValue(html, label) {
  const escaped = String(label).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const definition = new RegExp(`<dt\\b[^>]*>\\s*${escaped}\\s*<\\/dt>\\s*<dd\\b[^>]*>([\\s\\S]*?)<\\/dd>`, 'i').exec(html || '');
  if (definition) return textFromHtml(definition[1]);
  const pattern = new RegExp(`(?:^|>)\\s*${escaped}\\b\\s*[:：]?\\s*(?:<[^>]+>\\s*){0,4}([^<\\n\\r]{1,120})`, 'i');
  const match = pattern.exec(html || '');
  return match ? cleanText(match[1]) : '';
}

function parseDetails(html, inputUrl) {
  const structured = parseStructuredApp(html);
  const canonicalTag = /<link\b[^>]*rel\s*=\s*["']canonical["'][^>]*>/i.exec(html || '');
  const id = allowedUrl(canonicalTag ? attribute(canonicalTag[0], 'href') : inputUrl, inputUrl);
  if (!isDetailUrl(id)) throw new Error('APKCube detail page did not expose a valid canonical URL');
  const structuredPackage = typeof structured.applicationId === 'string' ? structured.applicationId : (typeof structured.packageName === 'string' ? structured.packageName : (typeof structured.identifier === 'string' ? structured.identifier : ''));
  const packageCandidates = [structuredPackage, labelledValue(html, 'PACKAGE ID'), packageFromUrl(id)].map(cleanText);
  const packageName = packageCandidates.find((value) => /^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$/.test(value)) || packageFromUrl(id);
  const name = cleanText(structured.name || firstText(html, /<h1\b[^>]*>([\s\S]*?)<\/h1>/i) || metaContent(html, 'og:title', 'property'));
  if (!name || !packageName) throw new Error('APKCube detail page did not expose required app metadata');
  const iconUrls = structuredUrls(structured.image, id, [...HOSTS, ...IMAGE_HOSTS]);
  const screenshotUrls = structuredUrls(structured.screenshot, id, [...HOSTS, ...IMAGE_HOSTS]);
  const version = cleanText(structured.softwareVersion || labelledValue(html, 'VERSION')) || extractVersion(name);
  const size = extractSize(structured.fileSize || labelledValue(html, 'SIZE')) || extractSize(html);
  const updatedAt = cleanText(structured.datePublished || structured.dateModified || labelledValue(html, 'UPDATED'));
  const category = cleanText(structured.applicationCategory || structured.applicationSubCategory || labelledValue(html, 'CATEGORY'));
  const summary = cleanText(structured.description || metaContent(html, 'description') || metaContent(html, 'og:description', 'property'));
  const rawDownloadUrls = structuredUrls(structured.downloadUrl, id);
  const directUrls = rawDownloadUrls.filter(isDirectDownloadUrl);
  const pageCandidates = rawDownloadUrls.filter((url) => isDownloadPageUrl(url, id));
  const pageUrl = directUrls.length ? '' : (pageCandidates[0] || allowedUrl(`${id.replace(/\/$/, '')}/download`, id));
  const downloadCandidates = uniqueBy([
    ...directUrls.map((url) => ({label: `${name} APK`, url, size})),
    pageUrl ? {label: `${name} download page`, url: pageUrl, size} : null,
  ], 'url');
  return {
    id,
    name,
    packageName,
    version,
    size,
    updatedAt,
    category,
    iconUrl: iconUrls[0] || allowedUrl(metaContent(html, 'og:image', 'property'), id, [...HOSTS, ...IMAGE_HOSTS]),
    summary,
    description: summary,
    screenshots: screenshotUrls,
    comments: [],
    downloadCandidates,
  };
}

async function fetchJson(url, referer, options = {}) {
  let text;
  try {
    text = await fetchText(url, referer, {
      ...options,
      headers: {Origin: ORIGIN, 'Sec-Fetch-Site': 'same-origin', ...(options.headers || {})},
    });
  } catch (error) {
    throw new Error(`APKCube API ${url}: ${String(error && error.message || error)}`);
  }
  let value;
  try {
    value = JSON.parse(String(text || ''));
  } catch (_) {
    throw new Error(`APKCube API ${url} returned invalid JSON`);
  }
  if (!value || typeof value !== 'object') throw new Error(`APKCube API ${url} returned an invalid response`);
  if (value.error) {
    const error = value.error;
    throw new Error(`APKCube ${error.code || 'API_ERROR'}: ${error.message || 'Request refused'}`);
  }
  return value;
}

async function fetchText(url, referer = ORIGIN, options = {}) {
  const requestOptions = {...options, headers: {...HEADERS, Referer: referer, ...(options.headers || {})}};
  return apkmesh.request(url, requestOptions);
}

function notFound(error) {
  return /\b(?:HTTP\s+|status(?:\s+code)?\s*[:=]?\s*)404\b/i.test(String(error && error.message || error || ''));
}

async function fetchPage(url, referer) {
  try {
    return await fetchText(url, referer);
  } catch (error) {
    if (notFound(error)) return null;
    throw error;
  }
}

async function resolveCandidate(candidate) {
  const candidateUrl = candidate && allowedUrl(candidate.url);
  if (!candidateUrl) return [];
  if (isDirectDownloadUrl(candidateUrl)) {
    return [{label: candidate.label || 'APK', url: candidateUrl, size: candidate.size || '', headers: {...HEADERS, Referer: ORIGIN}}];
  }
  // Only label/url/size/headers survive Flutter's candidate serialization.
  const detailUrl = candidateUrl.replace(/\/download\/?(?:[?#].*)?$/i, '');
  if (!isDownloadPageUrl(candidateUrl, detailUrl) || !isDetailUrl(detailUrl)) return [];
  const packageName = packageFromUrl(detailUrl);
  const apiBase = `${ORIGIN}/api/apps/${encodeURIComponent(packageName)}`;
  const listing = await fetchJson(`${apiBase}/apks`, candidateUrl);
  if (!Array.isArray(listing.apks)) throw new Error('APKCube has no ready APK builds; downloading may require its browser verification');
  const builds = listing.apks.filter((build) => build && /^\d+$/.test(String(build.apkId || '')));
  const build = builds.find((item) => item.isLatest === true) || builds[0];
  if (!build) throw new Error('APKCube returned no available APK builds');
  const tokenPayload = await fetchJson(`${apiBase}/download-token`, candidateUrl, {method: 'POST'});
  if (typeof tokenPayload.token !== 'string' || !tokenPayload.token) throw new Error('APKCube did not provide a download page token');
  const response = await fetchJson(`${ORIGIN}/api/downloads/request`, candidateUrl, {
    method: 'POST',
    body: JSON.stringify({packageName, apkId: String(build.apkId), install: false, pageToken: tokenPayload.token}),
    headers: {'Content-Type': 'application/json'},
  });
  // The public client consumes response.url. Never substitute the HTML page.
  const url = allowedUrl(response.url);
  if (!isDirectDownloadUrl(url)) {
    throw new Error('APKCube did not return a permitted binary download URL');
  }
  return [{label: `${String(candidate.label || 'APK').replace(/download page/i, '').trim()} ${String(build.format || 'APK').toUpperCase()}`.trim(), url, size: candidate.size || '', headers: {...HEADERS, Referer: candidateUrl}}];
}

async function reportProgress(requestId, index, downloads, error) {
  if (!requestId) return;
  try {
    await apkmesh.detailProgress(requestId, {index, downloads: downloads || [], error: error ? String(error) : null});
  } catch (_) {
    // Progress delivery must not abort resolution.
  }
}

globalThis.source = {
  manifest: {
    id: 'apkcube',
    name: 'APKCube',
    version: '1.0.0',
    minApiVersion: 1,
    homepage: `${ORIGIN}/`,
    description: '读取 APKCube 公开搜索、详情、截图和 APK 下载项。',
    packageLookup: true,
    permissions: {
      network: ['apkcube.com', 'www.apkcube.com', 'icons.apkcube.com', 'play-lh.googleusercontent.com'],
      browser: false,
      download: true,
      install: false,
    },
    debugProjects: [
      {id: 'search-keyword', name: '搜索关键词', description: '检查 APKCube 搜索与分页结果。', inputLabel: '关键词', placeholder: '例如 chatgpt', defaultInput: 'chatgpt'},
      {id: 'app-details', name: '获取应用详情', description: '读取元数据、截图和公开 APK 下载项。', inputLabel: '详情 URL', placeholder: '粘贴 apkcube.com 详情 URL', defaultInput: 'https://apkcube.com/chatgpt/com.openai.chatgpt'},
    ],
  },

  async search(query, page = 1) {
    const value = cleanText(query);
    if (value.length < 2) throw new TypeError('搜索关键词至少需要 2 个字符');
    const number = Math.max(1, Math.floor(Number(page) || 1));
    const suffix = number > 1 ? `&page=${number}` : '';
    const html = await fetchPage(`${ORIGIN}/search?q=${encodeURIComponent(value)}${suffix}`);
    return html === null ? [] : parseSearchResults(html);
  },

  async packageLookupUrl(packageName) {
    const value = cleanText(packageName);
    if (!/^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$/.test(value)) return '';
    const html = await fetchPage(`${ORIGIN}/search?q=${encodeURIComponent(value)}`);
    if (html === null) return '';
    // Next.js streams exact-package redirects as meta refresh, not HTTP 3xx.
    for (const match of String(html).matchAll(/<meta\b[^>]*http-equiv\s*=\s*["']refresh["'][^>]*>/gi)) {
      const target = /(?:^|;)\s*url\s*=\s*(.+)$/i.exec(attribute(match[0], 'content'));
      const url = target ? allowedUrl(target[1]) : '';
      if (isDetailUrl(url) && packageFromUrl(url) === value) return url;
    }
    const canonical = /<link\b[^>]*rel\s*=\s*["']canonical["'][^>]*>/i.exec(html);
    const url = canonical ? allowedUrl(attribute(canonical[0], 'href')) : '';
    if (isDetailUrl(url) && packageFromUrl(url) === value) return url;
    const result = parseSearchResults(html).find((item) => item.packageName === value);
    return result ? result.id : '';
  },

  async detailsMetadata(url) {
    const id = allowedUrl(url);
    if (!isDetailUrl(id)) throw new TypeError('无效的 APKCube 详情地址');
    return parseDetails(await fetchText(id, ORIGIN), id);
  },

  async resolveDownloads(candidates, requestId) {
    const resolved = [];
    const errors = [];
    for (let index = 0; index < (candidates || []).length; index += 1) {
      try {
        const downloads = await resolveCandidate(candidates[index]);
        if (downloads.length) resolved.push(...downloads);
        await reportProgress(requestId, index, downloads, null);
      } catch (error) {
        await reportProgress(requestId, index, [], error);
        errors.push(String(error && error.message || error));
      }
    }
    if (errors.length && (!requestId || !resolved.length)) throw new Error(errors.join('; '));
    return uniqueBy(resolved, 'url');
  },

  async details(url) {
    const app = await this.detailsMetadata(url);
    app.downloads = await this.resolveDownloads(app.downloadCandidates);
    delete app.downloadCandidates;
    return app;
  },

  async debug(projectId, input) {
    const value = cleanText(input);
    if (projectId === 'search-keyword') {
      const apps = await this.search(value, 1);
      return {title: '搜索完成', summary: `APKCube 返回 ${apps.length} 条结果`, data: apps};
    }
    if (projectId === 'app-details') {
      const app = await this.details(value);
      return {title: '详情读取完成', summary: `${app.name}：${app.downloads.length} 个下载项`, data: app};
    }
    throw new Error(`未知调试项目：${projectId}`);
  },
};
