#!/bin/sh
# 只允许 bt-probe-agent 容器访问中国大陆 IP，其余出站流量全部丢弃。
#
# 用法（在宿主机执行）：
#   install -m 0755 scripts/egress-cn-only.sh /usr/local/sbin/btprobe-egress.sh
#   /usr/local/sbin/btprobe-egress.sh
#
# 依赖：nftables、curl、docker；容器需运行在 172.30.66.0/24 网络（可用 SUBNET 覆盖）。
set -eu

ZONE=${BT_PROBE_CN_ZONE:-/etc/btprobe/cn.zone}
TABLE=${BT_PROBE_NFT_TABLE:-btprobe}
STATE=${BT_PROBE_NFT_STATE:-/etc/btprobe/applied.sha256}
SUBNET=${BT_PROBE_SUBNET:-172.30.66.0/24}
URL=${BT_PROBE_CN_URL:-https://ispip.clang.cn/all_cn.txt}

mkdir -p "$(dirname "$ZONE")"

# 每周刷新一次中国大陆 IP 段列表；下载失败则保留旧列表
if [ ! -s "$ZONE" ] || [ -n "$(find "$ZONE" -mtime +7 2>/dev/null)" ]; then
    tmp="$ZONE.tmp"
    if curl -fsSL --max-time 30 "$URL" -o "$tmp" && [ -s "$tmp" ]; then
        mv -f "$tmp" "$ZONE"
    else
        rm -f "$tmp"
        [ -s "$ZONE" ] || { echo "no zone list available" >&2; exit 1; }
    fi
fi

want=$(sha256sum "$ZONE" | cut -d' ' -f1)
if nft list table inet "$TABLE" >/dev/null 2>&1 && [ -f "$STATE" ] && [ "$(cat "$STATE")" = "$want" ]; then
    exit 0
fi
nft list table inet "$TABLE" >/dev/null 2>&1 && nft delete table inet "$TABLE" || true

{
    echo "table inet $TABLE {"
    echo "  set cn { type ipv4_addr; flags interval; elements = {"
    awk 'NF { printf "    %s,\n", $0 }' "$ZONE"
    echo "  } }"
    echo "  chain forward {"
    echo "    type filter hook forward priority -15; policy accept;"
    echo "    ip saddr $SUBNET ct state established,related accept"
    echo "    ip saddr $SUBNET ip daddr @cn accept"
    echo "    ip saddr $SUBNET drop"
    echo "  }"
    echo "}"
} > "${ZONE%.zone}.nft"
nft -f "${ZONE%.zone}.nft"
echo "$want" > "$STATE"
echo "btprobe egress rules applied (subnet=$SUBNET)"
