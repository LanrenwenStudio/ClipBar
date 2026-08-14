# ClipQuota

macOS 菜单栏小工具，用来看本机 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 里订阅账号的额度。

这是 demo：只读 Management API，不启动、不修改 CLIProxyAPI。

## 它看什么

状态栏显示最低剩余额度。点开后按渠道列出账号：

- **Codex / ChatGPT**：`5h` / `7d`（`/backend-api/wham/usage`）
- **Claude OAuth**：`5h` / `7d`（`/api/oauth/usage`）
- **Gemini CLI**：模型桶剩余（`retrieveUserQuota`）
- **Antigravity**：模型剩余（`fetchAvailableModels`）
- **xAI / Grok**：周额度 / 月额度（`cli-chat-proxy.grok.com/v1/billing`，和官方管理页同一条路径）

## 使用

1. 本机先跑 CLIProxyAPI，默认 `http://127.0.0.1:8317`
2. config 里设置 `remote-management.secret-key`
3. 打开 ClipQuota，在设置里填管理地址和密钥
4. 菜单栏会出现剩余百分比，点开看每个订阅账号

## 本地构建

```bash
cd ClipQuota
xcodegen generate
xcodebuild -scheme ClipQuota -destination 'platform=macOS' test
```

Debug 包在 DerivedData 里。日常预览：

```bash
xcodebuild -scheme ClipQuota -configuration Debug -destination 'platform=macOS' build
open "$(xcodebuild -scheme ClipQuota -configuration Debug -destination 'platform=macOS' -showBuildSettings | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/ClipQuota.app"
```

## 设置

存在本机 `UserDefaults`：

- 管理地址，默认 `http://127.0.0.1:8317`
- 管理密钥
- 刷新间隔，默认 60 秒

密钥只发给你填的 Management API，不会上传到别处。

## 还不做的事

- 不内嵌、不托管 CLIProxyAPI 进程
- 不做 OAuth 登录、账号增删
- 不做 Kimi 订阅额度
- 未接 App Store / Homebrew / 官网更新通道（发版前再补）

Bundle ID：`com.lanrenwen.clipquota`
