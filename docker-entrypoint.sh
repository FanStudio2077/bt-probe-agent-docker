#!/bin/sh
# 容器入口：首次启动自动申请绑定链接，然后以前台方式运行 bt-probe-agent
set -eu

BIN=/usr/local/bin/bt-probe-agent

mkdir -p "$(dirname "$BT_PROBE_CONFIG_PATH")" "$BT_PROBE_STATE_DIR" "$BT_PROBE_RUN_DIR"

echo "[entrypoint] bt-probe-agent container starting (cmd: $*)"

first=start
if [ $# -gt 0 ]; then
    first=$1
fi

case "$first" in
    start)
        if [ ! -s "$BT_PROBE_CONFIG_PATH" ]; then
            echo "[entrypoint] 未找到身份配置，正在申请绑定链接 / no identity found, requesting activation link..."
            "$BIN" public-activate --control-plane-url "$TBT_CONTROL_PLANE_URL" --endpoint "$TBT_AGENT_ENDPOINT" || \
                echo "[entrypoint] 激活申请失败，可稍后执行: docker exec <容器名> bt-probe-agent public-activate"
        fi
        exec "$BIN" start
        ;;
    activate|public-activate)
        exec "$BIN" public-activate --control-plane-url "$TBT_CONTROL_PLANE_URL" --endpoint "$TBT_AGENT_ENDPOINT"
        ;;
    *)
        exec "$BIN" "$@"
        ;;
esac
