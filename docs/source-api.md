# APK Mesh Source API v1

源是由 QuickJS 执行的单个 JavaScript 文件。脚本必须设置 `globalThis.source`，其中包含 `manifest`、`search()` 和 `details()`。宿主会验证返回值并在展示前附加源标识。源还可以可选实现 `catalog()` 和 `catalogPage()`，为主页提供由源定义的内容标签及分页列表。

## 必需接口

```js
globalThis.source = {
  manifest: {
    id: 'example',
    name: 'Example',
    version: '1.0.0',
    minApiVersion: 1,
    homepage: 'https://example.com',
    description: 'Example source metadata.',
    packageLookup: true,
    permissions: {
      network: ['example.com', '*.example.com'],
      browser: true,
      download: true,
      install: false,
    },
    debugProjects: [
      {
        id: 'search-keyword',
        name: '搜索关键词',
        description: '调用 search() 并在调试面板中显示请求和结果。',
        inputLabel: '关键词',
        placeholder: '例如 minecraft',
        defaultInput: 'minecraft',
      },
    ],
  },
  async search(query, page) {},
  async packageLookupUrl(packageName) {},
  async details(idOrUrl) {},
};
```

`manifest.description` 可选，用于在源管理页展示源说明。

源可以通过 `packageLookup: true` 声明包名查找能力，并实现 `packageLookupUrl(packageName)`。该接口必须返回一个可以直接交给 `details()` 解析的精确 URL；返回空值表示该源不支持该包名。宿主只会对已启用且声明该能力的源调用此接口，不会遍历普通搜索结果。详情返回的包名仍会与输入值进行精确比较，单个源失败不会阻止其他源返回结果。

`search(query, page)` 中 `page` 从 1 开始。宿主会在用户继续滚动搜索结果时请求后续页；源返回空数组表示该源没有更多结果。搜索页请求如果收到 HTTP 404，也应视为没有更多结果并返回空数组。源应保证同一查询的页码结果稳定，并避免跨页重复返回相同 `id`。其他请求失败则作为源错误处理，不应误判为分页结束。

`details()` 返回完整应用对象，并增加 `description`、`screenshots`、`comments` 和 `downloads`。详情可用 `summary` 表示版本说明或简短信息；`downloads` 每项包含 `label`、`url` 和 `size`，可选 `headers` 用于需要 Referer 等请求头的下载。`screenshots` 是截图 URL 数组；源应在解析懒加载图片时同时检查 `src`、`data-src` 等属性。

源可以额外实现分阶段详情接口：`detailsMetadata(idOrUrl)` 返回不包含最终下载直链的详情主体，并在 `downloadCandidates` 中返回待解析的下载候选项；`resolveDownloads(candidates, requestId)` 解析这些候选项。解析过程中可调用 `apkmesh.detailProgress(requestId, update)`，其中 `update` 包含候选项 `index`，以及 `download` 或 `downloads`（一个候选项可以产生多个最终文件），失败时包含 `error`。宿主会按候选项顺序逐项更新 UI；只有拿到最终下载对象后才会显示可下载操作，实际下载时仍执行源权限校验。未实现这两个可选接口的源继续使用一次性 `details()`。

`downloadCandidates` 中会跨 Flutter 消息桥保留的字段仅有 `label`、`url`、`size` 和可选 `headers`。解析器必须能从这些字段恢复所需信息，不能依赖候选项中的自定义字段。

## 可选主页目录接口

```js
async catalog() {
  return {
    defaultTabId: 'featured',
    tabs: [
      { id: 'featured', name: '推荐', paged: false },
      { id: 'games', name: '游戏', paged: true },
      { id: 'apps', name: '应用', paged: true },
    ],
  };
}

async catalogPage(tabId, page) {
  const apps = tabId === 'featured'
    ? await this.search('featured', 1)
    : await loadCatalogPage(tabId, page);
  return {
    apps,
    hasMore: tabId !== 'featured' && apps.length > 0,
  };
}
```

`catalog()` 返回有序的 `tabs` 数组。每个标签必须包含稳定且非空的 `id`、用于展示的 `name` 和布尔值 `paged`，可包含 `description`。宿主不解释标签 ID，也不假设第一个标签是推荐、主页或分类；源可以按站点结构自由提供推荐、应用、游戏、更新或任意分类标签。`defaultTabId` 可选，必须指向返回的标签；省略或无效时宿主使用第一个标签。

宿主只会立即加载当前标签，不会在主页初始化时请求所有标签内容。`catalogPage(tabId, page)` 中 `page` 从 1 开始，返回 `{ apps, hasMore }`。`apps` 字段与 `search()` 的应用摘要数组相同；`hasMore` 表示成功加载当前页后是否仍可请求下一页。`paged: false` 的标签只请求第 1 页，并应返回 `hasMore: false`。分页请求收到 HTTP 404 时应返回空数组和 `hasMore: false`；其他失败必须作为源错误抛出，不能误报为末页。源应保持跨页 ID 稳定并避免重复结果。

主页目录仍只使用用户在源管理中选择的单个主页源，搜索结果继续由所有启用源聚合。旧版 `home()`/`category()` 源仍由 Flutter 宿主兼容：推荐内容和每个分类会转换为不可分页标签；新源应实现 `catalog()`/`catalogPage()`。

`debugProjects` 是可选的调试项目声明。调试面板会按声明生成输入框和运行按钮，并调用 `debug(projectId, input)`。项目应返回 `{ title, summary, data }`，其中 `data` 会以结构化文本显示在运行结果下方。项目可以复用 `search()`、`details()` 或其他已声明的宿主能力；例如详情项目调用 `apkmesh.browser.open()` 时，面板会同步显示活动 WebView，点击标签即可打开可视化查看器。

### 内置源懒加载 sidecar

Source API 仍以单个 JavaScript 文件为完整、可导入的源格式。应用内置大量源时，可以为资产脚本增加同名的 `<script>.manifest.json` sidecar，例如 `apkvision.js.manifest.json`。宿主启动时从 sidecar 读取源目录信息和权限，不创建 QuickJS 运行时；源第一次执行时才加载脚本，并重新读取脚本自身的 manifest。

sidecar 复制脚本 manifest 的 `id`、`name`、`version`、`homepage`、`description`、`permissions` 和 `debugProjects`，并增加宿主预计算的能力声明：

```json
{
  "capabilities": {
    "catalog": true,
    "detailProgress": true,
    "packageLookup": false
  }
}
```

修改内置脚本 manifest 或可选接口时必须同步更新 sidecar。宿主首次激活脚本时会拒绝 sidecar 与脚本 manifest ID 不一致的源；没有 sidecar 的资产和用户导入的单文件源继续通过执行脚本读取 manifest，不影响第三方源兼容性。

`permissions.network` 支持精确主机名、`*.example.com` 子域名规则，以及显式的 `'*'` 任意主机权限。`'*'` 仍只允许 `http`/`https`，并会在每一次重定向时重新执行策略检查；它只应由用户明确信任、需要临时下载主机的源声明。

```js
async debug(projectId, input) {
  if (projectId === 'search-keyword') {
    const results = await this.search(input);
    return {
      title: '搜索完成',
      summary: `返回 ${results.length} 条结果`,
      data: results,
    };
  }
  throw new Error(`未知调试项目：${projectId}`);
}
```

## 宿主能力

- `apkmesh.request(url, options)`：返回响应文本的 HTTP 请求，受 manifest 网络权限限制；`options.headers` 为请求头，`options.method` 默认为 `GET`，也支持 `POST`，其他方法会拒绝。`options.body` 为可选字符串（JSON 需自行 `JSON.stringify()` 并设置 `Content-Type`）。`network: ['*']` 可显式允许任意 `http/https` 主机。每次重定向重新检查权限，最多跟随 6 次；POST 遇到 301/302/303 转为 GET 并移除请求体及实体头，307/308 保留方法和请求体；跨 origin 移除显式 Cookie、Authorization 和 Proxy-Authorization。Flutter 与 Python 宿主使用相同规则，失败会保留可观察的错误信息。
- `apkmesh.browser.open(url)`：打开隔离的隐藏 WebView 标签页，支持 `waitFor`、`waitForUrlChange`、`query` 和 `queryAll`。`waitForUrlChange` 会等待页面导航或 WebView 下载事件产生不同 URL，并返回该 URL，适用于由页面 JavaScript 生成下载地址的站点。
- `apkmesh.download(url, options)`：创建受 manifest 网络权限和下载权限约束的下载任务并返回本地文件路径。`options` 可包含 `fileName` 和额外 HTTP `headers`。
- `apkmesh.install(filePath)`：源声明 `permissions.install: true` 后，可经用户确认调用系统安装器；源不能静默安装。Shizuku 安装只能由应用界面的“安装”按钮发起，源直接调用时不会获得 Shizuku 特权。Android 会在需要时先打开未知来源安装权限页面。
- `apkmesh.detailProgress(requestId, update)`：向宿主报告分阶段详情中的下载项解析结果；只能用于源声明的 `resolveDownloads()` 调用，不能替代权限检查。

源脚本调用的能力均按 manifest 权限授权；安装权限仅约束脚本调用 `apkmesh.install()`，不限制用户在应用界面点击“安装”处理已下载的 APK。网络重定向的每一跳都会重新检查协议和 manifest 网络权限；`network: ['*']` 是源对临时下载主机的显式信任声明，下载内容和第三方源的安全性仍由使用者自行确认。脚本没有任意文件读写、系统命令、Cookie 导出或后台安装权限。生产构建中是否内置第三方源，应根据站点授权、条款和安全审阅结果明确决定。
