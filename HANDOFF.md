# AccessDeck / ClipBar Handoff

## 当前状态

- 工作目录：`/Users/kevin/Developer/Code/LanrenwenStudio/AccessDeck`
- 分支：`main`
- 基线提交：`36084cb feat: sync quota reset countdowns across surfaces`
- 当前改动：**未提交、未推送**；没有执行生产/发布构建。
- `ClipBar.xcodeproj` 是 `xcodegen` 生成的工程，已被忽略；源文件是 `project.yml`。

## 已完成的工作

### 产品改名

- 公开品牌为 **AccessDeck**，内部工程与兼容性标识仍保留 ClipBar。
- 仍保留兼容性敏感的内部标识，不要因为目录改名而一起改动：
  - macOS Bundle ID：`com.lanrenwen.clipbar`
  - iOS Bundle ID：`com.lanrenwen.clipbar.ios`
  - Widget Bundle ID：`com.lanrenwen.clipbar.ios.widgets`
  - App Group：`group.com.lanrenwen.clipbar`
  - iOS 后台任务：`com.lanrenwen.clipbar.ios.refresh`
  - UserDefaults / iCloud KVS 中的 `clipbar.*` keys
  - 工程、target、module 的内部名称目前仍是 `ClipBar`

### 跨端同步

- `SettingsStore` 已改为 `@MainActor final class`，通过可注入的 `SettingsCloudStore` 抽象及 `UbiquitousSettingsCloudStore` 适配器同步可序列化设置。
- 云端 payload 包含 Unix timestamp；只有云端时间戳严格更新时才覆盖本地设置。
- 云端采用设置时不会再次写回云端，避免反馈循环。
- `AppModel` 监听云端设置变更，更新设置、重启轮询、刷新账户数据并同步 Widget 状态。
- `AppSettings`、`AppTheme`、`StatusQuotaDisplay`、`StatusQuotaWindow` 已支持 `Codable`。
- 已加入 macOS/iOS 的 `com.apple.developer.ubiquity-kvstore-identifier` entitlement。
- 额度快照通过 CLIProxyAPI 直连或 `clipbar-quota` 插件获取，不放入 iCloud KVS；Widget/cache 仍走现有本地 App Group 路径。

### 敏感凭据

- 新增 `Sources/ClipBar/Settings/SettingsSecretStore.swift`。
- `managementKey` 不再写入 UserDefaults，也不再进入 iCloud KVS 设置 payload；旧 `backendAccessToken` 仅执行一次性清理。
- 两者改用可同步的 iCloud Keychain（`kSecAttrSynchronizable`）。
- 已保留旧 UserDefaults 凭据迁移：首次读取时迁移到 Keychain 并删除旧 UserDefaults 值。
- Keychain service：`com.lanrenwen.clipbar.settings`。

## 当前未提交文件

除下列文件外，当前改动还包括 CPA 连接抽象、插件集成、旧 backend 删除和相关测试：

- `Sources/ClipBar/App/AppModel.swift`
- `Sources/ClipBar/ClipBar-iOS.entitlements`
- `Sources/ClipBar/ClipBar.entitlements`
- `Sources/ClipBar/Models/StatusQuotaWindow.swift`
- `Sources/ClipBar/Networking/ManagementClient.swift`
- `Sources/ClipBar/Networking/QuotaConnection.swift`（新增）
- `Sources/ClipBar/Settings/AppSettings.swift`
- `Sources/ClipBar/Settings/SettingsSecretStore.swift`（新增）
- `Sources/ClipBar/Settings/SettingsStore.swift`
- `Sources/ClipBar/UI/QuotaPopoverView.swift`
- `Sources/ClipBar/UI/SettingsView.swift`
- `Sources/ClipBar/iOS/ClipBarIOSApp.swift`
- `Sources/ClipBar/iOS/Views/DashboardView.swift`
- `Sources/ClipBar/iOS/Views/ServerSettingsView.swift`
- `Tests/ClipBarTests/AppSettingsTests.swift`
- `Tests/ClipBarTests/QuotaConnectionTests.swift`（新增）
- `project.yml`
- `Integrations/clipbar-quota-plugin/`（新增）
- `HANDOFF.md`（本文件）
- 旧 `backend/` 独立服务及 `QuotaBackendClient.swift` 已删除

## 验证结果

已通过：

```text
xcodegen generate
xcodebuild -project ClipBar.xcodeproj -scheme ClipBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
# 46 tests in 4 suites passed; exit status 0

git diff --check
```

插件已通过此前的 `go test ./...`、`go vet ./...`、`make check` 和格式检查；尚未构建或加载 c-shared 动态库。未执行生产/发布构建。

## 文件夹改名操作

建议在当前会话结束后，从父目录执行，避免当前 shell 的工作目录变成已移动路径：

```bash
cd /Users/kevin/Developer/Code/LanrenwenStudio
if [ -e AccessDeck ]; then
  echo 'AccessDeck already exists; aborting'
  exit 1
fi
mv ClipBar AccessDeck
cd AccessDeck
xcodegen generate
```

目录改名本身不会改变 Git 历史，也不会改变 Bundle ID、App Group、KVS key 或 Keychain service。改名后应重新打开：

```text
/Users/kevin/Developer/Code/LanrenwenStudio/AccessDeck/ClipBar.xcodeproj
```

目前只建议改**外层仓库目录名**。除非另有明确要求，不要同时把 `Sources/ClipBar`、`ClipBar.xcodeproj`、target/module 名称改成 `AccessDeck`，以免扩大兼容性风险。

## 后续工作

1. 改名后确认 `git status --short` 仍只包含上述未提交改动。
2. 重新运行 `xcodegen generate` 和 macOS/iOS 轻量构建检查。
3. 在同一 Apple ID 的 macOS 与 iPhone 真机上验证：
   - iCloud KVS 设置传播；
   - 新时间戳覆盖旧时间戳；
   - iCloud Keychain 凭据传播；
   - 后台刷新和 Widget 更新。
4. 检查签名环境下的 iCloud entitlement / provisioning；当前验证使用了 `CODE_SIGNING_ALLOWED=NO`。
5. 确认无误后再决定是否提交。当前不要自动 commit、push 或发布。

## 注意事项

- 不要把真实 `managementKey`、`backendAccessToken` 写进 handoff、日志或提交内容。
- UI 和真机交互效果尚未由 Agent 截图或自动点击验证，应由用户实际验收。
- 共享额度数据不再依赖独立 backend：macOS 与 iOS 分别通过配置的 CPA 直连或 `clipbar-quota` 插件连接刷新，并通过本地 App Group 缓存与 Widget 共享快照；合法的 provider `/v1/...` 接口仍由 provider 适配器直接调用。
