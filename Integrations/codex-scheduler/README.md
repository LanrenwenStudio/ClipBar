# AccessDeck - Codex Plus 额度智能调度器

由 AccessDeck 统一维护的 Codex Plus 账号额度自适应调度模块。

## 架构说明

- **执行层**：运行在软路由（ImmortalWrt / 192.168.1.3）上，具备 24 小时常开与 Node 18 环境。
- **定时调度**：由 root crontab 每半小时触发一次 `--tick`，受 `/tmp/cpa-plus-activation.lock` 互斥保护。
- **状态服务**：由 procd 托管运行 `scheduler.cjs --serve`，监听 `192.168.1.3:8318`，提供只读 `/status` 与 `/health` API，供 AccessDeck（macOS & iOS 客户端）及本地脚本查询展示。
- **持久化状态**：保存于 `/root/CLIProxyAPI/plus-scheduler/state.json`，包含 30 天采样历史、当日 AI 规划记录与去重执行历史。
- **私有配置**：`/root/CLIProxyAPI/plus-scheduler/config.json` 包含 AI 规划所用的 API Key 与模型配置（文件权限 0600，不写入代码库或日志）。

## 核心语义与约束

1. **窗口唤醒不是自动刷新额度**：最小请求仅用于在空闲期启动五小时窗口，绝不保证或强制刷新/重置额度。
2. **严格单执行器**：同一时点只处理一次，调用前落盘去重（started），防止重复请求。
3. **每日预算与间隔**：每账号每日最多 3 次实际尝试，相邻调用必须间隔至少 4 小时；已有活跃窗口（used > 0 且 reset 在未来）自动跳过。
4. **AI 规划**：每天北京时间 04:00 后首次运行由 AI（gpt-6.1-sol）规划当天时点，每天至多规划一次。

## 命令说明

```bash
# 完整定时轮询（采样 -> 规划 -> 执行唤醒）
node scheduler.cjs --tick

# 仅执行额度采样并记录
node scheduler.cjs --sample

# 采样并尝试当天 AI 规划
node scheduler.cjs --plan

# 采样并检查执行当前半小时内的时点
node scheduler.cjs --execute

# 查看当前状态 JSON
node scheduler.cjs --status

# 启动局域网只读状态服务（8318 端口）
node scheduler.cjs --serve
```

## 测试与部署

```bash
# 本地运行回归测试
node test.cjs

# 部署并验证到软路由
./deploy.sh
```
