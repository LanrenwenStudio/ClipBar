# AccessDeck Handoff

## 当前连接架构

- macOS 与 iOS 仅使用 CPA Management API 直连，没有连接模式切换或独立 backend。
- `QuotaConnectionFactory.make()` 创建 `ManagementClient`、`QuotaService` 与 `DirectQuotaConnection`。
- 账号列表通过 `/v0/management/auth-files` 获取，上游额度请求通过 `/v0/management/api-call` 转发。
- 默认 CPA 地址为 `http://192.168.1.3:8317`；Management Key 不写入文档、日志或提交。
- 旧 Go/C ABI 集成目录及其测试、构建配置和说明已删除。
- `SettingsStore` 保留旧 `clipbar.connectionMode` 偏好键删除语句，用于清理已有安装的历史配置。
- Google 请求的 `pluginType: GEMINI` 是上游协议字段，必须保留。

## 当前额度行为

- 菜单栏仅在已知的 5 小时和周额度都耗尽时隐藏渠道；仍有一个额度窗口可用时保持可见。
- Codex 账号卡片显示可用重置卡数量，包含 0 张；usage 缺少数量时只读查询 `/wham/rate-limit-reset-credits`。
- 查询不到数量时显示「重置卡：暂不可用」，不猜测数量、不提供兑换操作。
- macOS 与 iOS 共用 `QuotaService` 和 `QuotaParser`；Widget 通过本地 App Group 共享额度快照。

## 配置与兼容性

- macOS Bundle ID：`com.lanrenwen.accessdeck`
- iOS Bundle ID：`com.lanrenwen.accessdeck.ios`
- Widget Bundle ID：`com.lanrenwen.accessdeck.ios.widgets`
- App Group：`group.com.lanrenwen.accessdeck`
- iOS 后台任务：`com.lanrenwen.accessdeck.ios.refresh`
- 保留现有 UserDefaults / iCloud KVS 的 `clipbar.*` keys，避免丢失已有配置。
- Management Key 使用可同步 iCloud Keychain，service 为 `com.lanrenwen.accessdeck.settings`；旧 UserDefaults 凭据迁移后删除。
- iCloud KVS 只同步设置，不存储凭据或额度快照；仅接受更新的云端时间戳，应用云端设置时不再次写回。
- `AccessDeck.xcodeproj` 由 `project.yml` 经 `xcodegen` 生成。

## 本地开发安装

- 使用 Debug 配置和现有 Apple Development 签名覆盖安装，不卸载、不清除配置。
- 开发者团队：`X37879TD5Q`。
- Mac 安装位置：`/Applications/AccessDeck.app`。
- 两端本地开发产物目录：`.build/local-install/DerivedData`、`.build/local-install/iOS-device`。
- 真机安装使用 `xcrun devicectl device install app`；手机锁屏可能阻止自动启动，但不代表安装失败。
- 不执行生产构建、上传、提交、推送或部署，除非用户明确授权。
- UI 和真机交互效果由用户亲自验收，不擅自截图或模拟点击。

## 本次验证结果

- macOS 无签名本地回归：46 项测试、4 个测试套件通过。
- macOS 与 iOS Debug 签名编译均通过。
- Mac 已覆盖安装至 `/Applications/AccessDeck.app`，签名校验通过，进程启动成功。
- iPhone 已覆盖安装 `com.lanrenwen.accessdeck.ios`，设备返回启动成功。
- 未卸载或清除配置，未提交、推送、上传或发布。真实账号的重置卡数量与界面效果仍由用户验收。

## Widget 重置卡展示

- 共享快照新增可选 `resetCreditCount`，旧快照缺失该字段仍可解码。
- Codex 汇总未禁用账号卡数；0 正常显示，任一参与账号未知时显示 `--`。
- 普通连续/分段单渠道、多渠道及锁屏圆形、矩形、行内、多渠道布局已接入。
- 本次 StatusBarSummaryTests 15 项通过，包含卡数汇总、未知、禁用、溢出与旧快照兼容检查。
- macOS 与包含 Widget 扩展的 iOS Debug 签名编译通过，已覆盖安装并启动两端开发版。
- 未自动进行 UI 验收，Widget 实际布局及刷新效果由用户查看；未提交、推送或发布。

- iOS 首页多渠道按用户最新要求恢复原双列卡片布局，移除渠道卡片重置卡汇总行；账号详情与 Widget 重置卡显示保留。
- 锁屏多渠道小组件排版紧凑化与留白优化：
  - 根因：此前为防止满额裁切收窄了进度条，导致进度条与右侧胶囊之间的 `Spacer` 留白过大，视觉上产生明显断层与松散感；
  - 优化：
    - 进度条宽度适度扩展为 36pt（分段微胶囊提升为 10 段，兼顾精细度与视觉饱满度），自然吸收多余空白；
    - 调整 `Spacer` 弹性，保证整行既不紧绷两边截断，又消除中间突兀的巨大空隙；
    - 整体布局左右对称自然、饱满且紧凑一体；
  - 47 项单元测试全部通过，Debug 构建覆盖安装并自动启动至手机。
- 修复桌面多渠道小组件双 100% 时胶囊内换行折叠问题：
  - 根因：胶囊内 `Text(compactPercent(splitWindows.fiveHour))` 未限制 `.lineLimit(1)` 与 `.fixedSize()`，当 5 小时额度和周额度同时达到 100%（最长宽度）时，SwiftUI 在水平空间受挤压时自动将 `100%` 折行显示成了两行（`100` 在上，`%` 和 `5h` 在下）；
  - 修复：
    - 胶囊内部各 Text 及胶囊 HStack 强制加入 `.lineLimit(1)` 与 `.fixedSize(horizontal: true, vertical: false)`；
    - 右侧数值容器设置 `.layoutPriority(2)` 与 `.fixedSize(horizontal: true, vertical: false)`，确保数值区享有最高排版优先级，绝不折行；
    - 3 渠道场景的 `percentFontSize` 从 10.0pt 精修微调为 9.5pt，字重由 heavy 微调为 bold，排版呼吸感更佳；
  - 47 项单元测试全部通过，Debug 编译成功并覆盖安装至手机。
- 修复 Antigravity 配额常驻 100% 无法反映实际损耗问题：
  - 根因 1（User-Agent 过期导致 Google 过滤 Gemini 模型）：此前请求头写死旧 UA `antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)`，Google 服务端将旧版客户端视为过时版本，在配额响应中完全隐去了主力使用的 `Gemini Models` 分组，仅返回了未使用的第三方模型分组（`Claude and GPT models`，额度始终为 100%）。
  - 根因 2（端点优先度倒置）：此前端点列表中优先请求了 Google 内部每日测试节点 `daily-cloudcode-pa`，其过滤规则更严苛；未优先使用生产环境 `cloudcode-pa`。
  - 根因 3（多模型分组稀释瓶颈）：`QuotaParser` 此前将各模型分组简单做算术平均。若某分组有损耗（如 80%）而另一未使用的分组为 100%，平均计算会掩盖真实瓶颈。
  - 修复：
    - 将 User-Agent 同步升级为 CPA 官方规范 `antigravity/hub/2.23.0 darwin/arm64`，经真实接口请求验证，全量正常返回 `Gemini Models`（含实时 5h 及周额度真实损耗）与 `Claude and GPT models`；
    - 调整端点优先顺序，生产环境 `cloudcode-pa.googleapis.com` 置顶；
    - 改进 `QuotaParser.antigravityGroupedWindow`，对各模型分组选取最受限（lowest remaining）的真实瓶颈分组及对应重置倒计时，确保任何分组有消耗都能及时准确反应；
    - 扩充 auth file 内 `project_id` 的多路径容错解析（涵盖 `projectId`、`installed.project_id`、`web.project_id` 等）；
  - 48 项单元测试（新增多分组瓶颈选择测试用例）全部通过；
  - iOS 端已重新构建并安装启动；
  - macOS 端已使用对应 Development 证书和描述文件重新编译 Release 版本，成功覆盖安装至 `/Applications/AccessDeck.app`，签名严格校验通过，旧进程已优雅重启并已恢复运行。
- 增强 macOS 端渠道显隐配置与快捷操作入口：
  - 根因：此前 macOS 虽然在底层的 `hiddenStatusItemIDs` 实现了状态栏渠道过滤，但 UI 入口过于隐蔽（Tab 3 命名为「渠道外观」，每行仅有一个无文字标签且与上下排序箭头并排的 10.5pt 小图标；Tab 2「菜单栏」中完全没有渠道开关；下拉主面板亦无任何显隐操作或右键菜单），导致用户难以发现并以为无法设置；
  - 优化：
    1. 「设置」->「菜单栏」（Menu Bar）：新增专门的「状态栏显示渠道」配置区块，直接列出所有已配置渠道，并配有独立的 Toggle 开关及「已在状态栏隐藏」警示胶囊，直观清晰；
    2. 「设置」->「渠道管理」（Channels）：分类 Tab 重构命名为「渠道管理」（图标 `server.rack`），明确该 Tab 的功能；列表每行的小眼睛按钮增加高亮圆圈背景、醒目颜色与完整 Tooltip，隐藏时展示「已隐藏」徽标；
    3. 下拉面板（Popover）快速切换：
       - 顶栏渠道 Tab 支持**鼠标右键上下文菜单**：可直接右键点击任一渠道选择「在状态栏隐藏此渠道」或「在状态栏显示此渠道」，亦可快速直达「渠道设置…」；
       - 若渠道已在状态栏隐藏，Tab 胶囊内自动展示醒目的 `eye.slash` 警示小图标；
       - 渠道概览卡片顶部在被隐藏时展示「已在状态栏隐藏」胶囊按钮，点击即可直接恢复显示；
  - 单元测试覆盖新增的渠道显隐切换持久化逻辑（共 48 项测试全部通过）；已完成 macOS Release 重新构建与签名，并覆盖安装重启至 `/Applications/AccessDeck.app`。
- 同步完善 iOS 端渠道显隐配置、看板真实隐藏与小组件过滤：
  - 根因：此前 iOS 端设置页（`ServerSettingsView`）中完全缺失渠道显示/隐藏管理区；而在主看板中，被隐藏的渠道只被降为 0.7 透明度并打上小图标，依然占据看板卡片空间，并未真正不显示；且多渠道小组件也未过滤隐藏渠道；
  - 优化：
    1. 「设置」（右上角齿轮 -> `ServerSettingsView`）：新增专门的「渠道显示与管理」Section，每个渠道配备独立 Toggle 开关与「已隐藏」橙色标签，支持直接关闭/开启任意渠道在看板与小组件中的展示；
    2. 主看板（`DashboardView`）：
       - 真正执行过滤：被隐藏的渠道从看板双列卡片中彻底移除，不再占位显示；
       - 顶栏动态指示：右上角「渠道管理」按钮常驻（不再受数量限制而消失），若存在隐藏渠道时直接显示 `(N个已隐藏)` 警示徽标；全隐藏时展示引导恢复的空状态；
       - 长按卡片快捷隐藏：卡片增加 Context Menu 菜单「在看板中隐藏此渠道」；
    3. 小组件同步过滤（`WidgetDataStore`）：生成快照时严格跳过被隐藏的渠道，保证桌面与锁屏多渠道小组件与 App 端保持一致；
  - 49 项单元测试全部通过；iOS 客户端已重新编译安装启动至 iPhone，macOS Release 客户端同步重新构建更新。

## Codex Plus 额度智能调度接管

### 1. 最新架构模式演进（Mac 客户端驱动采样、统计与规划）
- **Mac 端自主驱动**：
  - 按照用户明确指令，不再由软路由定时脚本发起额度采样。Mac 端 AccessDeck 日常会每 5~10 分钟自动轮询 CPA 获取最新额度，采样天然具备更高时效性。
  - 新建原生 `CodexSchedulerEngine.swift`：由 Mac 端直接在每次轮询完成后接收两个 Codex Plus 账号数据，自动记录历史样本（`codex-samples-history.json`，保留 30 天）、执行 48 半小时槽负载聚合统计、在每天 04:00 后首次运行由 AI 规划当天时点，并在到期时点执行空闲窗口受限唤醒。
  - 本地状态路径：`~/Library/Application Support/AccessDeck/codex-scheduler-state.json`，原子落盘并异步镜像同步给软路由，供软路由 8318 端口及查看脚本读取。
- **软路由端定时任务停用**：
  - 软路由上的 root cron 定时调度任务已安全注释停用（`# */30 * * * * ...`），彻底避免双执行器冲突。
  - 软路由上的 `cpa-plus-scheduler-api`（8318 端口）作为只读镜像服务继续运行，软路由其他 4 项 cron 任务（CPA/Keeper 更新、OpenClash、mamabake 备份）完全保留。

### 2. 状态平滑过渡与安全
- 切换前已将旧脚本、状态与 crontab 完整备份至软路由 `/root/CLIProxyAPI/backup-scheduler-pre-accessdeck/`（权限 0700/0600）。
- 原有 `/root/CLIProxyAPI/plus-scheduler/state.json` 中的历史采样点（14 个样本）、当日 AI 规划记录与时点跳过记录已完整导入 Mac 本地存储并实现双向兼容器。

### 3. AccessDeck 客户端（macOS & iOS）集成
- **模型与网络**：新增 `CodexSchedulerStatus.swift`、`CodexSchedulerClient.swift` 与 `CodexSchedulerEngine.swift`。
- **UI 交互**：
  - 通用详情面板 `CodexSchedulerDetailView`：直观展示调度健康状态（是否滞后）、今日 AI 计划生成时间与理由、各账号 5h/周额度与安排时点、今日执行/跳过记录与中文原因。
  - macOS 客户端：在 `ProviderSummaryCard` 中为 Codex 渠道增加「Plus 额度智能调度」胶囊入口，点击直达详情弹窗。
  - iOS 客户端：在 `ProviderDetailView` 中为 Codex 渠道增加「Plus 额度智能调度」状态卡片，支持点击进入完整计划与记录页面。
- **本地脚本更新**：`/Users/kevin/Desktop/MyConfig/查看额度计划.command` 已重构为纯净 Python3 脚本，优先直读 Mac 本地文件（0.05秒极速响应），并保留局域网 HTTP 与 SSH 双重回退。

### 4. 验证结果与已知未验证事项
- **单元测试**：54 项测试全部通过（新增了兼容解码、调度校验、激活判定与 URL 推导测试）。
- **实际运行证据**：
  - 软路由上的 cron 任务已成功注释停用，crontab 检查确认无活动定时 tick 冲突；
  - 软路由 8318 状态服务健康检查正常；
  - Mac 本地历史样本已完整导入并保存（14 个样本及完整时点与计划）；
  - 本地 `查看额度计划.command` 运行成功，瞬间展示最新状态与今日规划记录；
  - macOS Release 版本覆盖安装重启至 `/Applications/AccessDeck.app`；iOS Debug 版本安装启动至真机。
- **运行环境与尚未验证事项说明**：
  - **设备环境确认**：Mac 宿主为 7×24 小时常开的桌面主机 Mac mini（系统电源实测 `sleep 0`、`disksleep 0`），无合盖睡眠与离线中断问题，具备常驻轮询、采样与定时规划的绝佳稳定性；
  - **真实唤醒效果观测**：当前两个 Codex Plus 账号 5 小时额度均处于使用中/耗尽活跃状态，执行器严格按照规则跳过了最小请求（避免无谓消耗）；空闲期真实唤醒的自然触发与重置时间后延效果尚待自然轮转观察。
