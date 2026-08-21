# ClipBar

> 官网：[https://clipbar.lanrenwen.com](https://clipbar.lanrenwen.com) · [GitHub Releases](https://github.com/LanrenwenStudio/ClipBar/releases)

**ClipBar** 是一款专为搭配 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 使用的 macOS 原生菜单栏轻量看板。

你在本机使用 CLIProxyAPI 聚合多个 AI 平台（如 ChatGPT Plus/Team、Claude Pro/Team、Grok、Gemini 等）的订阅时，ClipBar 可以在 macOS 顶部菜单栏安静常驻，实时显示各账号的 **5 小时速率限制**、**周额度** 以及 **重置倒计时**，告别写代码写到一半突然遭遇 429 断流。

---

## 📦 安装与升级

### 方式一：Homebrew Cask（推荐）

通过烂人文工作室官方 Tap 仓库一键安装：

```bash
brew install --cask LanrenwenStudio/apps/clipbar
```

后续升级：

```bash
brew upgrade --cask clipbar
```

卸载：

```bash
brew uninstall --cask clipbar
```

### 方式二：直接下载 GitHub Releases

直接下载最新的通用 macOS Universal 应用包（Apple Silicon + Intel）：

- ⬇️ **最新版本下载**：[ClipBar.zip (GitHub Releases)](https://github.com/LanrenwenStudio/ClipBar/releases/latest/download/ClipBar.zip)
- 解压后将 `ClipBar.app` 拖入 `/Applications`（应用程序）文件夹即可。

---

## 🚀 详细配置与使用指南

### 第一步：开启 CLIProxyAPI 的管理接口

ClipBar 通过读取 CLIProxyAPI 的 Management API 来获取额度。在使用前，请确保 CLIProxyAPI 的配置文件（通常是 `config.yaml`）中开启了管理接口并设置了密钥：

```yaml
# CLIProxyAPI config.yaml 示例
remote-management:
  allow-remote: false # 仅限本机访问建议保持 false
  secret-key: "your-secret-token" # 设置一个你的管理密钥
```

启动 CLIProxyAPI 服务（默认端口为 `8317`）：

```bash
./cliproxyapi -config config.yaml
```

---

### 第二步：配置 ClipBar

1. 启动 **ClipBar.app**，菜单栏会出现 ClipBar 状态图标。
2. **右键点击** 菜单栏图标（或在面板底部点击齿轮 ⚙️ 打开偏好设置）：
   - **Management Base URL**：填入管理地址，例如 `http://127.0.0.1:8317`
   - **Secret Key**：填入你在 `config.yaml` 中设置的 `secret-key`
   - **刷新间隔**：支持 10 秒 ~ 60 分钟（默认 60 秒）
   - **状态栏展示**：可选择优先展示 5 小时速率限制窗口还是周额度
3. 点击 **测试连接**，连接成功后将自动开始轮询用量数据。

---

### 第三步：状态栏常驻查看

- **菜单栏摘要**：状态栏实时展示当前活跃渠道的最低/加权剩余额度百分比（如 `82%`），额度紧张时变色警示。
- **左键点击展开看板**：
  - **渠道切换 Tab**：点击 Codex、Claude、Grok 等 Tab 切换查看对应平台的账号列表。
  - **渠道汇总卡片**：展示该平台下所有账号的池化剩余总额度与下一次刷新倒计时。
  - **账号列表卡片**：列出每个登录账号的邮箱、当前 5 小时突发窗口使用量（如 `41/50`）、周用量及重置倒计时。

---

## 🔍 支持的渠道监控项

| 渠道 / 平台 | 监控额度维度 | 底层接口 / 来源 |
| :--- | :--- | :--- |
| **Codex / ChatGPT** | `5h` 突发限制 + `7d` 周期用量 | `/backend-api/wham/usage` |
| **Claude OAuth** | `5h` 速率限制 + `7d` 周期用量 | `/api/oauth/usage` |
| **Grok (xAI)** | 周额度 + 月度计费总额 | `/v1/billing`（与官方控制台一致） |
| **Gemini CLI** | 各模型桶剩余配额 | `retrieveUserQuota` |
| **Antigravity** | `5h` / 周额度（可切换优先窗口） | `retrieveUserQuotaSummary` |
| **Kimi** | `7d` 周期额度 + `5h` 速率限制 | `api.kimi.com/coding/v1/usages` |

---

## 🔒 隐私与安全性

- **100% 只读**：仅调用 Management API 的查询接口，不启动、不托管、不修改 CLIProxyAPI 进程。
- **完全本地运行**：管理地址与密钥仅存储在 macOS 本地 `UserDefaults`（`com.lanrenwen.clipbar`），零云端依赖，绝不向任何外部服务器上传凭据。

---

## 🛠️ 本地编译构建

本项目使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 管理工程配置，纯原生 Swift / SwiftUI 编写：

```bash
git clone https://github.com/LanrenwenStudio/ClipBar.git
cd ClipBar
xcodegen generate
xcodebuild -scheme ClipBar -destination 'platform=macOS' test
```

日常本地 Debug 运行：

```bash
xcodebuild -scheme ClipBar -configuration Debug -destination 'platform=macOS' build
open "$(xcodebuild -scheme ClipBar -configuration Debug -destination 'platform=macOS' -showBuildSettings | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/ClipBar.app"
```

---

Bundle ID：`com.lanrenwen.clipbar`
反馈与建议：[support@lanrenwen.com](mailto:support@lanrenwen.com) 或提交 GitHub Issue。
