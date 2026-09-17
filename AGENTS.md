# AccessDeck 项目协作规范

本项目遵循父目录 `AGENTS.md` 的共用规范，以下规则为补充，不放宽构建、提交或发布的授权限制。

## Apple 开发者服务：优先使用 ASC CLI

- 涉及 App Store Connect、Bundle Identifier 注册、Capabilities、签名证书、Provisioning Profiles 等 Apple 开发者服务操作时，**优先使用 ASC CLI（命令为 `asc`）**，不要默认要求用户通过 Xcode 或网页手动操作。
- 本项目默认使用用户自己的 `kevin` 认证配置，调用时显式指定 `asc --profile kevin ...`，避免误用其他账号。
- 操作前通过 `asc auth status` 和对应子命令的 `--help` 核实认证状态及命令语法；涉及签名时核对团队。当前已确认 `kevin` 对应团队为 `X37879TD5Q`。
- 优先复用有效证书和匹配的描述文件。不得擅自撤销证书、删除远端资源或更换开发者团队。
- ASC CLI 无法完成或权限不足时，先说明具体限制，再请用户通过 Xcode 或网页补充操作；不要仅因 Xcode 未登录就认定无法完成签名配置。
- ASC CLI 用于 Apple 开发者服务管理；本地编译仍使用 `xcodebuild`，工程生成使用 `xcodegen`。
- 不得输出 API 私钥、认证令牌或其他凭据。上传构建、提交审核、发布等操作仍须获得用户明确授权。
