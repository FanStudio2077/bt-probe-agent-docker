#!/bin/sh
# 卸载直接安装在宿主机上的 bt-probe-agent（systemd 方式）
set -eu

echo "[1/5] stop & disable systemd units"
systemctl stop bt-probe-agent bt-probe-agent-updater.path 2>/dev/null || true
systemctl disable bt-probe-agent bt-probe-agent-updater.path 2>/dev/null || true

echo "[2/5] try official uninstall"
if command -v bt-probe-agent >/dev/null 2>&1; then
    bt-probe-agent uninstall 2>/dev/null || true
fi

echo "[3/5] remove systemd unit files"
rm -f /etc/systemd/system/bt-probe-agent.service \
      /etc/systemd/system/bt-probe-agent-updater.service \
      /etc/systemd/system/bt-probe-agent-updater.path
systemctl daemon-reload 2>/dev/null || true

echo "[4/5] remove binary and data"
rm -f /usr/local/bin/bt-probe-agent
rm -rf /etc/bt-probe-agent /var/lib/bt-probe-agent /run/bt-probe-agent

echo "[5/5] done. remaining check:"
systemctl status bt-probe-agent --no-pager 2>&1 | head -3 || true
echo "OK"
