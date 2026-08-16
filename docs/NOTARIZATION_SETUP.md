# ClipBar Apple 官方公证与分发配置手册

本文档记录 ClipBar 接入 **Apple Developer ID 签名与苹果官方公证（Notarization）** 所需的 GitHub Secrets 配置说明。后续当你准备为 ClipBar 开启全自动公证时，按此配置即可。

---

## 🔑 GitHub Secrets 完整清单

在 GitHub 仓库 `LanrenwenStudio/ClipBar` -> **Settings** -> **Secrets and variables** -> **Actions** 中添加以下 Repository Secrets：

| Secret 名称 | 说明 | 生成 / 导出方式 |
| :--- | :--- | :--- |
| `DEVELOPER_ID_P12_BASE64` | Apple Developer ID Application 证书与私钥导出的 `.p12` 文件的 Base64 编码文本 | `base64 -i developer-id.p12 \| pbcopy` |
| `DEVELOPER_ID_P12_PASSWORD` | 导出 `.p12` 时设置的保护密码 | 字符串明文 |
| `ASC_API_KEY_BASE64` | App Store Connect API Key (`AuthKey_XXXXXX.p8`) 文件的 Base64 编码文本 | `base64 -i AuthKey_XXXXXX.p8 \| pbcopy` |
| `ASC_KEY_ID` | App Store Connect API Key ID（10 位字符） | 例如：`2X9R4HXF34` |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID（UUID 格式） | 例如：`57246542-96fe-1a63-e053-082e100a1409` |
| `HOMEBREW_TAP_TOKEN` | 用于向 `LanrenwenStudio/homebrew-apps` 提交 Cask 更新的 GitHub Token (PAT) | 具备 `repo` 权限的 Personal Access Token |

---

## 🛠️ 本地签名与公证验证命令

如果需要在本地终端手动执行签名与公证，可以在 `ClipBar` 根目录执行：

```bash
DEVID_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db" \
NOTARYTOOL_KEY_PATH="/path/to/AuthKey_XXXXXX.p8" \
NOTARYTOOL_KEY_ID="你的_ASC_KEY_ID" \
NOTARYTOOL_ISSUER_ID="你的_ASC_ISSUER_ID" \
DISTRIBUTION_MODE=developer-id \
./scripts/package-app.sh
```

构建完成后，产物位于 `dist/` 目录：
- `dist/clipbar-X.Y.Z.dmg`（带 Apple 公证 Ticket 与 `/Applications` 快捷方式）
- `dist/ClipBar.zip`

---

## 🚀 自动发版流程

配置好上述 Secrets 后，后续每次发布新版本只需在 `ClipBar` 仓库执行：

```bash
git tag v0.1.1
git push origin v0.1.1
```

GitHub Actions 将自动完成：
1. 双架构 Universal 应用编译（Apple Silicon + Intel）
2. Apple Developer ID 签名与 Hardened Runtime 加固
3. 提交至苹果服务器公证（`xcrun notarytool submit`）
4. 执行 `xcrun stapler staple` 盖章
5. 生成 Release 发布 `DMG` 与 `ZIP`
6. 自动同步更新 `LanrenwenStudio/homebrew-apps` 仓库的 Homebrew Cask
