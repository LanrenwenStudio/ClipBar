# AccessDeck / AccessDeck Handoff

## 当前状态

- 工作目录：`/Users/kevin/Developer/Code/LanrenwenStudio/AccessDeck`
- 分支：`main`
- 当前提交：`744edc3 feat: migrate AccessDeck to CLIProxyAPI integrations`
- 分支：`main`，比 `origin/main` 超前 3 个提交；当前工作区包含 CPA 默认地址、Widget 5 小时标签动态化及对应测试，**未提交、未推送**。
- 未执行生产/发布构建；已执行 macOS 测试、iOS Simulator Debug 构建，并使用本地 Apple Development 证书完成 iPhone 真机临时签名、覆盖安装和启动。
- `AccessDeck.xcodeproj` 是 `xcodegen` 生成的工程，已被忽略；源文件是 `project.yml`。

## 已完成的工作

### 产品改名

- 公开品牌为 **AccessDeck**，内部工程与兼容性标识仍保留 AccessDeck。
- 仍保留兼容性敏感的内部标识，不要因为目录改名而一起改动：
  - macOS Bundle ID：`com.lanrenwen.accessdeck`
  - iOS Bundle ID：`com.lanrenwen.accessdeck.ios`
  - Widget Bundle ID：`com.lanrenwen.accessdeck.ios.widgets`
  - App Group：`group.com.lanrenwen.accessdeck`
  - iOS 后台任务：`com.lanrenwen.accessdeck.ios.refresh`
  - UserDefaults / iCloud KVS 中的 `clipbar.*` keys
  - 工程、target、module 的内部名称目前仍是 `AccessDeck`

### 跨端同步

- `SettingsStore` 已改为 `@MainActor final class`，通过可注入的 `SettingsCloudStore` 抽象及 `UbiquitousSettingsCloudStore` 适配器同步可序列化设置。
- 云端 payload 包含 Unix timestamp；只有云端时间戳严格更新时才覆盖本地设置。
- 云端采用设置时不会再次写回云端，避免反馈循环。
- `AppModel` 监听云端设置变更，更新设置、重启轮询、刷新账户数据并同步 Widget 状态。
- `AppSettings`、`AppTheme`、`StatusQuotaDisplay`、`StatusQuotaWindow` 已支持 `Codable`。
- 已加入 macOS/iOS 的 `com.apple.developer.ubiquity-kvstore-identifier` entitlement。
- 额度快照通过 CLIProxyAPI 直连获取，不放入 iCloud KVS；Widget/cache 仍走现有本地 App Group 路径。

### 敏感凭据

- 新增 `Sources/AccessDeck/Settings/SettingsSecretStore.swift`。
- `managementKey` 不再写入 UserDefaults，也不再进入 iCloud KVS 设置 payload；旧 `backendAccessToken` 仅执行一次性清理。
- 两者改用可同步的 iCloud Keychain（`kSecAttrSynchronizable`）。
- 已保留旧 UserDefaults 凭据迁移：首次读取时迁移到 Keychain 并删除旧 UserDefaults 值。
- Keychain service：`com.lanrenwen.accessdeck.settings`。

## 当前未提交文件

当前提交 `744edc3` 已包含 CPA 连接抽象、插件集成、旧 backend 删除和相关测试。提交后的未提交改动包括 CPA 默认连接地址、iOS CPA 地址预设、iOS 与 macOS 一致的 Direct/Plugin 二选一连接方式切换、锁屏/多渠道 Widget 的动态 5 小时标签及对应测试：

- `Sources/AccessDeck/Models/StatusBarSummary.swift`
- `Sources/AccessDeck/Models/WidgetSnapshot.swift`
- `Sources/AccessDeckWidgets/LockScreenMultiProviderWidget.swift`
- `Sources/AccessDeckWidgets/LockScreenQuotaWidget.swift`
- `Sources/AccessDeckWidgets/SegmentedMultiProviderWidget.swift`
- `Sources/AccessDeckWidgets/SegmentedSingleProviderWidget.swift`
- `Sources/AccessDeckWidgets/SingleProviderQuotaCard.swift`
- `Sources/AccessDeckWidgets/TripleProviderWidget.swift`
- `Tests/AccessDeckTests/StatusBarSummaryTests.swift`
- `Sources/AccessDeck/Settings/AppSettings.swift`
- `Sources/AccessDeck/Settings/SettingsStore.swift`
- `Sources/AccessDeck/iOS/Views/ServerSettingsView.swift`
- `Tests/AccessDeckTests/AppSettingsTests.swift`

> 下方列表是 `744edc3` 已提交的迁移文件，非本次未提交改动。

- `Sources/AccessDeck/App/AppModel.swift`
- `Sources/AccessDeck/AccessDeck-iOS.entitlements`
- `Sources/AccessDeck/AccessDeck.entitlements`
- `Sources/AccessDeck/Models/StatusQuotaWindow.swift`
- `Sources/AccessDeck/Networking/ManagementClient.swift`
- `Sources/AccessDeck/Networking/QuotaConnection.swift`（新增）
- `Sources/AccessDeck/Settings/AppSettings.swift`
- `Sources/AccessDeck/Settings/SettingsSecretStore.swift`（新增）
- `Sources/AccessDeck/Settings/SettingsStore.swift`
- `Sources/AccessDeck/UI/QuotaPopoverView.swift`
- `Sources/AccessDeck/UI/SettingsView.swift`
- `Sources/AccessDeck/iOS/AccessDeckIOSApp.swift`
- `Sources/AccessDeck/iOS/Views/DashboardView.swift`
- `Sources/AccessDeck/iOS/Views/ServerSettingsView.swift`
- `Tests/AccessDeckTests/AppSettingsTests.swift`
- `Tests/AccessDeckTests/QuotaConnectionTests.swift`
- `project.yml`
- `HANDOFF.md`（本文件）
- 旧 `backend/` 独立服务及 `QuotaBackendClient.swift` 已删除

## 验证结果

已通过：

```text
xcodegen generate
xcodebuild -project AccessDeck.xcodeproj -scheme AccessDeck \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
# 46 tests in 4 suites passed; exit status 0

xcodebuild -project AccessDeck.xcodeproj -scheme AccessDeck-iOS \
  -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
# BUILD SUCCEEDED；iOS 连接方式为 Direct/Plugin 二选一分段切换。

xcodebuild -project AccessDeck.xcodeproj -scheme AccessDeck-iOS \
  -configuration Debug -destination 'id=00008101-001A78C61ED2001E' build
# 正式工程签名仍受本机 Xcode-managed profile 缺少 iCloud / ubiquity-kvstore entitlement 影响。
# 随后使用本地有效 Apple Development 证书和 App Group 允许的临时签名配置完成真机包组装与安装。

xcrun devicectl device install app --device 00008101-001A78C61ED2001E \
  /tmp/AccessDeck-iOSManualAssemble/AccessDeck.app
# App installed: com.lanrenwen.accessdeck.ios

xcrun devicectl device process launch --device 00008101-001A78C61ED2001E \
  com.lanrenwen.accessdeck.ios
# Launched application

git diff --check
```

锁屏 Widget 5 小时标签已统一使用最近重置时间的整小时桶：`5h`、`4h`、`3h`、`2h`、`1h`；小于 1 小时也显示 `1h`。覆盖了锁屏单渠道、多渠道，以及普通/分段多渠道和单渠道卡片。UI 实际效果仍需用户在设备上验收。

插件已通过此前的 `go test ./...`、`go vet ./...`、`make check` 和格式检查；尚未构建或加载 c-shared 动态库。未执行生产/发布构建。

CPA 直连默认值：`AppSettings.default.baseURL` 及 iOS 的 LAN 预设均为 `http://192.168.1.3:8317`，默认模式为 Direct；管理密钥仍从 Keychain 读取，未写入本文件。当前 macOS 偏好设置已显示该 CPA 地址和 Direct 相关字段，旧 backend URL/token 会在 `SettingsStore.load()` 中清理。

## 文件夹改名操作

建议在当前会话结束后，从父目录执行，避免当前 shell 的工作目录变成已移动路径：

```bash
cd /Users/kevin/Developer/Code/LanrenwenStudio
if [ -e AccessDeck ]; then
  echo 'AccessDeck already exists; no rename needed'
else
  mv ClipBar AccessDeck
fi
cd AccessDeck
xcodegen generate
```

目录改名本身不会改变 Git 历史，也不会改变 Bundle ID、App Group、KVS key 或 Keychain service。改名后应重新打开：

```text
/Users/kevin/Developer/Code/LanrenwenStudio/AccessDeck/AccessDeck.xcodeproj
```

目前只建议改**外层仓库目录名**。除非另有明确要求，不要同时把 `Sources/AccessDeck`、`AccessDeck.xcodeproj`、target/module 名称改成 `AccessDeck`，以免扩大兼容性风险。

## 后续工作

1. 提交 `HANDOFF.md` 与当前 13 个源码/测试文件。
2. 改名后确认 `git status --short` 仍只包含上述未提交改动。
3. 在同一 Apple ID 的 macOS 与 iPhone 真机上验证：
   - iCloud KVS 设置传播；
   - 新时间戳覆盖旧时间戳；
   - iCloud Keychain 凭据传播；
   - 后台刷新和 Widget 更新。
4. 检查正式签名环境下的 iCloud entitlement / provisioning；本次真机安装使用的是去除未获 profile 授权的 iCloud KVS entitlement 后、通过 App Group profile 完成的临时开发签名包。iCloud KVS 真机行为仍需具备正确 capability 的正式 profile 后验证。
5. 确认无误后再决定是否发布。

## 注意事项

- 不要把真实 `managementKey`、`backendAccessToken` 写进 handoff、日志或提交内容。
- UI 和真机交互效果尚未由 Agent 截图或自动点击验证，应由用户实际验收。
- 共享额度数据通过 CLIProxyAPI 直连刷新，并通过本地 App Group 缓存与 Widget 共享快照；合法的 provider `/v1/...` 接口由 provider 适配器直接调用。
