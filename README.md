# ClipBar

macOS 菜单栏小工具，用来看本机 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 里订阅账号的额度。

这是 demo：只读 Management API，不启动、不修改 CLIProxyAPI。

## 它看什么

状态栏按渠道汇总剩余额度。点开后按渠道列出账号：

- **Codex / ChatGPT**：`5h` / `7d`（`/backend-api/wham/usage`）
- **Claude OAuth**：`5h` / `7d`（`/api/oauth/usage`）
- **Gemini CLI**：模型桶剩余（`retrieveUserQuota`）
- **Antigravity**：5 小时 / 周额度（`retrieveUserQuotaSummary`，状态栏可切换优先窗口）
- **Kimi**：7 天额度 / 5 小时速率限制（`api.kimi.com/coding/v1/usages`）
- **Grok**：周额度 / 月额度（`cli-chat-proxy.grok.com/v1/billing`，和官方管理页同一条路径）

## 使用

1. 本机先跑 CLIProxyAPI，默认 `http://127.0.0.1:8317`
2. config 里设置 `remote-management.secret-key`
3. 打开 ClipBar，右键状态栏打开设置，填管理地址和密钥
4. 菜单栏会出现剩余百分比，左键点开看每个订阅账号

## 本地构建

```bash
cd ClipBar
xcodegen generate
xcodebuild -scheme ClipBar -destination 'platform=macOS' test
```

Debug 包在 DerivedData 里。日常预览：

```bash
xcodebuild -scheme ClipBar -configuration Debug -destination 'platform=macOS' build
open "$(xcodebuild -scheme ClipBar -configuration Debug -destination 'platform=macOS' -showBuildSettings | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/ClipBar.app"
```

## 设置

存在本机 `UserDefaults`：

- 管理地址，默认 `http://127.0.0.1:8317`
- 管理密钥
- 刷新间隔，默认 60 秒
- 登录时启动
- 状态栏汇总优先窗口，默认 5 小时，可切换为周额度

密钥只发给你填的 Management API，不会上传到别处。

## 还不做的事

- 不内嵌、不托管 CLIProxyAPI 进程
- 不做 OAuth 登录、账号增删
- 未接 App Store / 官网更新通道

## Homebrew 安装

发布 GitHub Release 后，可以直接通过 Cask 安装：

```bash
brew install --cask https://raw.githubusercontent.com/LanrenwenStudio/ClipBar/main/Casks/clipbar.rb
```

卸载：

```bash
brew uninstall --cask clipbar
```

给 `v*` tag 创建 Release 时，GitHub Actions 会自动构建通用 macOS 包并上传 `ClipBar.zip`。当前构建使用本机临时签名；正式分发前仍需换成 Apple Developer ID 签名并完成公证。

Bundle ID：`com.lanrenwen.clipbar`
