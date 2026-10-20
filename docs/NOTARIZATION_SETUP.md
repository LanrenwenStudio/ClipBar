# AccessDeck Apple 官方公证与分发配置手册

本文档记录 AccessDeck 在本机执行 Apple Developer ID 签名与苹果官方公证所需的配置。禁止使用 GitHub Actions；构建、公证、上传及发布均需用户明确授权。

## 本机凭据

- Developer ID Application 证书及私钥安装在本机 Keychain 中，不需要向 GitHub 上传 `.p12` 或 Base64 证书。
- 公证 API Key `.p8` 保存在仓库外，通过 `NOTARYTOOL_KEY_PATH` 指定。
- 设置对应的 `NOTARYTOOL_KEY_ID`、`NOTARYTOOL_ISSUER_ID`；这些值必须与本机 API Key 一致。
- 本机 GitHub CLI 鉴权用于获授权后的 Release 上传；不依赖 GitHub Actions Secrets。
- 不把证书、私钥、API Token 或密码提交到 Git。

---

## 🛠️ 本地签名与公证验证命令

用户明确授权发版后，在 `AccessDeck` 根目录使用现有本地打包脚本：

```bash
DEVID_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db" \
NOTARYTOOL_KEY_PATH="/path/to/AuthKey_XXXXXX.p8" \
NOTARYTOOL_KEY_ID="你的_ASC_KEY_ID" \
NOTARYTOOL_ISSUER_ID="你的_ASC_ISSUER_ID" \
DISTRIBUTION_MODE=developer-id \
./scripts/package-app.sh
```

构建完成后，产物位于 `dist/` 目录：
- `dist/accessdeck-X.Y.Z.dmg`（带 Apple 公证 Ticket 与 `/Applications` 快捷方式）
- `dist/AccessDeck.zip`

---

## 本地发布流程

1. 确认版本、分发渠道及明确发布授权。
2. 在本机运行上面的 `./scripts/package-app.sh`，完成 Developer ID 签名、公证与产物打包。
3. 对最终产物核对签名、公证和 SHA-256；仅上传实际成功生成的产物。
4. 获授权后使用本机 `gh release create` 或 `gh release upload` 上传 DMG/ZIP。
5. 在本地更新 `LanrenwenStudio/homebrew-apps` 对应 Cask 的版本、SHA-256 和资产 URL。提交和推送另获授权。

GitHub 仅保存源码和 Release 资产；推送标签或分支不构成发版，不得触发、重跑或重新启用 Actions。
