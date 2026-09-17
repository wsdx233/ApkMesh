<div align="center">
  <img src="web/icons/Icon-512.png" alt="APK Mesh Logo" width="128" height="128" />
  <h1>APK Mesh</h1>
  <p>基于 Flutter 构建的开源 APK 源聚合客户端</p>
</div>

---

## 项目概述

APK Mesh 是一个跨平台的 APK 源聚合客户端。它采用去中心化的源脚本架构，源脚本使用 JavaScript (QuickJS) 编写。宿主应用为这些脚本提供受控的隐藏浏览器自动化、网络抓取、文件下载以及应用安装能力，从而实现多源 APK 资源的统一检索与管理。

当前版本提供主页分类、聚合搜索、下载管理、源管理以及应用设置等核心功能。在 Android 平台上，系统会自动扫描并加载 `assets/sources/` 目录下的内置源脚本（如 APKVision、APKMirror、APKTodo 等）。

## 核心特性

* **受控的脚本沙盒**：通过 QuickJS 引擎执行源脚本，所有网络请求、浏览器导航和下载行为均受严格的清单（Manifest）权限策略约束。
* **无头浏览器自动化**：内置 Headless WebView，支持基于 CSS 选择器的 DOM 查询、动态页面等待以及反爬策略绕过。
* **高级安装机制**：在 Android 平台上，支持调用系统默认安装器，同时支持配置 Shizuku 实现无 root 权限的静默安装。
* **灵活的源管理**：支持从 HTTPS URL 远程导入 `.js` 源文件，或通过系统文件选择器导入独立的 `.js` 及打包的 `.zip` 源脚本。
* **独立开发者工具**：配套提供完全独立的 Python CLI 调试器，无需 Android 环境即可在桌面端进行源脚本的开发、录制、回放与 Trace 调试。

## 界面语言

支持简体中文和 English。在「设置 → 界面语言」中可选择「跟随系统」「简体中文」或「English」，切换立即生效并在重启后保留。默认跟随系统：中文系统使用简体中文，其他系统使用英文。

界面语言与「翻译设置」中的目标语言相互独立；源站返回的名称、描述、分类和源脚本输出仍保留原文或使用现有的内容翻译功能。Android 的通知和安装提示同步使用界面语言。

本地化文案位于 `lib/l10n/app_en.arb` 和 `lib/l10n/app_zh.arb`，使用 Flutter 官方 `gen-l10n` 生成类型安全的接口。修改文案后运行 `flutter gen-l10n`；新增语言时同时更新语言选项、系统语言回退规则和 Android `res/values-*` 文案。不要手工修改生成的 `app_localizations*.dart` 文件。

## 免责声明与合规性

本软件仅作为技术聚合工具，**不托管、不分发任何 APK 文件**。内置的演示源脚本仅用于验证宿主接口和技术可行性，不代表对相关站点内容的认可。

* **用户责任**：请仅启用您有权访问的源。用户需自行确认目标应用的版权、分发许可、文件签名及安全性。
* **开发者约束**：源脚本作者不得编写或分发用于解析明显侵权内容、绕过合法访问控制、窃取用户凭据或传播恶意软件的脚本。
* **免责声明**：使用者对导入的源、搜索的结果、下载的文件和安装的行为承担全部法律责任。软件作者不对第三方源及其提供的内容承担任何直接或间接责任。

## 架构说明

QuickJS 宿主桥接逻辑位于 `lib/core/source_runtime.dart`，Android 平台的具体实现位于 `lib/core/quickjs_source_io.dart` 与 `lib/core/host_factory_io.dart`：

1. `flutter_js` 在 Android 中运行 QuickJS，并通过异步消息总线注册 `apkmesh.*` 原生能力。
2. `flutter_inappwebview` 提供隔离的无头浏览器环境，所有资源加载均按源 Manifest 的域名白名单进行严格拦截与校验。
3. 下载模块采用流式 HTTP 传输，重定向链路受白名单保护。
4. 有关 JavaScript 源脚本的 API 契约和宿主能力详情，请参阅 [Source API 文档](docs/source-api.md)。

## 开发指南

### 环境要求

* Flutter SDK `^3.12.2`
* Android Studio / Xcode (用于原生平台编译)

### 构建与运行

```bash
# 获取依赖
flutter pub get

# 运行项目
flutter run

# 执行测试用例
flutter test
```

### Python 源调试器

项目包含一个功能完整的 Python 调试器，位于 `tools/source_debugger/` 目录，专为源脚本开发者设计。

**环境初始化：**
```bash
cd tools/source_debugger
uv sync
uv run playwright install chromium
```

**常用调试命令：**
```bash
# 查看源清单及能力声明
uv run apkmesh-debug ../../assets/sources/apkvision.js inspect

# 在线搜索测试
uv run apkmesh-debug ../../assets/sources/apkvision.js search minecraft

# 录制网络请求及 DOM 快照以供离线回放
uv run apkmesh-debug --mode record --record-dir fixtures/apkvision \
  ../../assets/sources/apkvision.js search minecraft
```

## 开源协议

本项目采用 MIT 协议开源。详情请参阅 [LICENSE](LICENSE) 文件。
