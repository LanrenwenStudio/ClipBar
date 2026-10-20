#!/usr/bin/env bash
# AccessDeck - 软路由 Codex Plus 调度器同步与部署脚本
set -euo pipefail

ROUTER_HOST="${ROUTER_HOST:-root@192.168.1.3}"
REMOTE_BASE="/root/CLIProxyAPI"
REMOTE_SCHEDULER_DIR="${REMOTE_BASE}/plus-scheduler"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== AccessDeck Codex Scheduler Deployment ==="
echo "Target: ${ROUTER_HOST}"

# 1. 检查 SSH 连通性
ssh -o BatchMode=yes -o ConnectTimeout=8 "${ROUTER_HOST}" 'echo "SSH connection verified."'

# 2. 远端目录创建
ssh "${ROUTER_HOST}" "mkdir -p -m 700 ${REMOTE_SCHEDULER_DIR}"

# 3. 同步新调度核心代码与测试套件
echo "Syncing scheduler.cjs and test.cjs..."
scp "${SCRIPT_DIR}/scheduler.cjs" "${ROUTER_HOST}:${REMOTE_SCHEDULER_DIR}/scheduler.cjs"
scp "${SCRIPT_DIR}/test.cjs" "${ROUTER_HOST}:${REMOTE_SCHEDULER_DIR}/test.cjs"

# 4. 设置安全权限并建立软链接兼容
ssh "${ROUTER_HOST}" "
  chmod 600 ${REMOTE_SCHEDULER_DIR}/scheduler.cjs
  chmod 600 ${REMOTE_SCHEDULER_DIR}/test.cjs
  ln -sf ${REMOTE_SCHEDULER_DIR}/scheduler.cjs ${REMOTE_BASE}/activate-plus-accounts.cjs
"

# 5. 远端运行独立测试套件
echo "Running test suite on router..."
ssh "${ROUTER_HOST}" "node ${REMOTE_SCHEDULER_DIR}/test.cjs"

# 6. 配置并启动 procd 只读状态 HTTP 服务（8318 端口）
echo "Configuring procd service for status API (port 8318)..."
ssh "${ROUTER_HOST}" 'cat << "EOF" > /etc/init.d/cpa-plus-scheduler-api
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=95
STOP=10

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/node /root/CLIProxyAPI/plus-scheduler/scheduler.cjs --serve
    procd_set_param respawn 3600 5 0
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF
chmod 755 /etc/init.d/cpa-plus-scheduler-api
/etc/init.d/cpa-plus-scheduler-api enable
/etc/init.d/cpa-plus-scheduler-api restart
'

# 7. 验证状态接口响应
echo "Verifying local status endpoint..."
sleep 2
ssh "${ROUTER_HOST}" 'curl -s http://127.0.0.1:8318/health'
echo ""

echo "=== Deployment & Verification Completed Successfully ==="
