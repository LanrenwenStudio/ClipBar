# ClipBar

> 官网：[https://clipbar.lanrenwen.com](https://clipbar.lanrenwen.com) · [GitHub Releases](https://github.com/LanrenwenStudio/ClipBar/releases)

macOS 菜单栏小工具，用来看本机 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 里订阅账号的额度与速率限制。

100% 只读本地 Management API，不启动、不托管、不修改 CLIProxyAPI 进程。

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

## 🔍 它看什么

状态栏按渠道汇总剩余额度。点开后按渠道列出每个账号与重置倒计时：

- **Codex / ChatGPT**：`5h` / `7d` 窗口（`/backend-api/wham/usage`）
- **Claude OAuth**：`5h` / `7d` 速率限制（`/api/oauth/usage`）
- **Grok (xAI)**：周额度 / 月额度（`cli-chat-proxy.grok.com/v1/billing`）
- **Gemini CLI**：模型桶剩余配额（`retrieveUserQuota`）
- **Antigravity**：5 小时 / 周额度（`retrieveUserQuotaSummary`，状态栏可切换优先窗口）
- **Kimi**：7 天额度 / 5 小时速率限制（`api.kimi.com/coding/v1/usages`）

---

## 🚀 使用步骤

1. 本机先运行 CLIProxyAPI，默认地址 `http://127.0.0.1:8317`
2. 在配置文件中开启并设置 `remote-management.secret-key`
3. 打开 ClipBar，右键状态栏图标打开设置，填入管理地址和密钥
4. 菜单栏会出现剩余额度百分比，左键点开查看每个订阅账号详情

---

## 🛠️ 本地构建

```bash
cd ClipBar
xcodegen generate
xcodebuild -scheme ClipBar -destination 'platform=macOS' test
```

Debug 包在 DerivedData 里。日常本地预览：

```bash
xcodebuild -scheme ClipBar -configuration Debug -destination 'platform=macOS' build
open "$(xcodebuild -scheme ClipBar -configuration Debug -destination 'platform=macOS' -showBuildSettings | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/ClipBar.app"
```

---

## ⚙️ 设置项

所有配置均保存在本机 `UserDefaults`（`com.lanrenwen.clipbar`）：

- **管理地址**：默认 `http://127.0.0.1:8317`
- **管理密钥**：仅向你填写的 Management API 发送，绝不上传到任何云端
- **刷新间隔**：支持 10 秒至 60 分钟（默认 60 秒）
- **登录时启动**：开机自启开关
- **状态栏优先窗口**：默认 5 小时，可切换为周额度
- **隐藏无额度账号**：保持状态栏与弹窗面板清爽

---

## 🔒 边界说明（还不做的事）

- 不内嵌、不托管 CLIProxyAPI 进程
- 不做 OAuth 登录与账号增删改
- 密钥仅保存在本地，100% 离线与只读

---

Bundle ID：`com.lanrenwen.clipbar`
