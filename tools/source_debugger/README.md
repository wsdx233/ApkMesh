# APK Mesh Source Debugger

独立的 Python 源调试器，用于在不安装 Android 应用、不连接 Android 设备的情况下执行 APK Mesh JavaScript 源。

它实现了当前 Source API 的主要宿主能力：

- QuickJS 执行源脚本；
- `apkmesh.request()` 的 GET/POST、字符串请求体和逐跳白名单重定向（301/302/303 将 POST 转为 GET；307/308 保留方法和请求体；跨 origin 移除显式凭据）；
- Playwright 无头 Chromium 作为浏览器宿主；
- `waitFor`、`waitForUrlChange`、`query`、`queryAll` 的 CSS/属性查询契约；
- 独立目录保存下载文件；
- `install()` 明确报告 Android 能力不可用；
- live 请求、录制和完全离线的精确 URL fixture 回放；
- 请求、响应、浏览器导航、选择器和异常 trace。

## 初始化

需要 Python 3.12+ 和已经安装的 `uv`：

```bash
cd tools/source_debugger
uv sync
uv run playwright install chromium
```

`playwright install chromium` 只需要执行一次，用于下载 Playwright 自己管理的浏览器。它不需要 Android SDK 或 Android 设备。

选项要放在源文件路径之前；例如 `--json`、`--mode replay` 和 `--trace`。


```bash
uv run apkmesh-debug [选项] SOURCE [操作参数]
```

查看源 manifest：

```bash
uv run apkmesh-debug ../../assets/sources/apkvision.js inspect
```

在线搜索（live 模式是默认值）：

```bash
uv run apkmesh-debug --mode live --trace traces/search.json ../../assets/sources/apkvision.js search minecraft
uv run apkmesh-debug --mode replay --fixture-dir examples/fixtures/demo examples/fixture_demo.js package-search com.example.demo
```

录制 HTTP 响应和浏览器最终 DOM 页面快照，生成可离线回放的目录：

```bash
uv run apkmesh-debug --mode record --record-dir fixtures/apkvision \
  ../../assets/sources/apkvision.js search minecraft
```

在线读取详情：

```bash
uv run apkmesh-debug ../../assets/sources/apkvision.js details \
  https://apkvision.org/games/arcade/minecraft-pe-apk-55409/
```

运行源声明的调试项目：

```bash
uv run apkmesh-debug ../../assets/sources/apkvision.js debug \
  search-keyword minecraft
```

机器可读输出：

```bash
uv run apkmesh-debug --json ../../assets/sources/apkvision.js search minecraft
```

检查源主页目录标签：

```bash
uv run python examples/check_catalog.py ../../assets/sources/apkvision.js
```

该脚本使用与调试器相同的 QuickJS/HTTP 宿主，在线调用源的 `catalog()`，再通过 `catalogPage(tabId, 1)` 检查每个标签的首屏结果、分页声明和 `hasMore`。临时只检查前 3 个标签时使用 `--limit 3`。标签 ID 按源返回值原样传递，不假设具体 URL 或站点结构；旧 `home()`/`category()` 源仍可使用兼容检查。

## 离线回放

回放目录包含一个 `replay.json`，响应可以直接写入 `body`，也可以通过 `body_file` 引用文件：

```json
{
  "responses": {
    "GET https://example.test/?s=demo": {
      "status": 200,
      "headers": {"content-type": "text/html; charset=utf-8"},
      "body_file": "search-demo.html"
    }
  }
}
```

执行回放时，未登记的 URL 会失败，不会访问网络：

```bash
uv run apkmesh-debug --mode replay --fixture-dir fixtures/example \
  ../../assets/sources/example.js search demo
```

源专属的测试代码和录制 fixture 放在 `tests/sources/<source>/` 下，该目录仅用于本地调试，并由 `.gitignore` 忽略。通用宿主测试留在 `tests/` 根目录；添加新源测试时，只在对应源目录调用该源声明的 `debug()` 项目。

## 测试

```bash
uv run pytest tests --ignore=tests/sources
```

该命令只运行通用宿主和运行时测试。源专属测试需要显式运行 `uv run pytest tests/sources/<source>`，其 fixture 不会自动创建。需要完全断网执行时，必须显式使用 `--mode replay`；回放中未登记的 URL 会失败，不会访问网络。正式调试第三方源前，应确认自己有权访问相关站点，并遵守站点条款。
