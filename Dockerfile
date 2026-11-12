# syntax=docker/dockerfile:1.7
FROM alpine:3.20

ARG TBT_VERSION=latest
ARG TBT_DOWNLOAD_BASE_URL=https://t.bt.cn/agent/download
ARG TARGETARCH

LABEL org.opencontainers.image.title="bt-probe-agent" \
      org.opencontainers.image.description="宝塔网络拨测节点 bt-probe-agent 的容器化封装" \
      org.opencontainers.image.url="https://github.com/FanStudio2077/bt-probe-agent-docker" \
      org.opencontainers.image.source="https://github.com/FanStudio2077/bt-probe-agent-docker" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="$TBT_VERSION"

# 从宝塔官方发布地址下载静态二进制，并用官方 SHA-256 校验。
# 二进制版权归宝塔所有，本仓库仅提供容器封装，不重新分发二进制。
RUN set -eux; \
    apk add --no-cache ca-certificates curl; \
    arch="$TARGETARCH"; \
    if [ -z "$arch" ]; then \
        case "$(uname -m)" in \
            x86_64|amd64)  arch=amd64 ;; \
            aarch64|arm64) arch=arm64 ;; \
            *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
        esac; \
    fi; \
    base=$(printf '%s' "$TBT_DOWNLOAD_BASE_URL" | sed 's:/*$::'); \
    artifact="bt-probe-agent-linux-$arch"; \
    url="$base/$TBT_VERSION/$artifact"; \
    echo "Downloading $url"; \
    curl -fsSL --retry 3 --retry-delay 2 "$url" -o /usr/local/bin/bt-probe-agent; \
    curl -fsSL --retry 3 --retry-delay 2 "$url.sha256" -o /tmp/agent.sha256; \
    want=$(cut -d ' ' -f 1 /tmp/agent.sha256); \
    got=$(sha256sum /usr/local/bin/bt-probe-agent | cut -d ' ' -f 1); \
    [ "$want" = "$got" ] || { echo "SHA-256 mismatch: want=$want got=$got" >&2; exit 1; }; \
    echo "SHA-256 OK: $got"; \
    chmod 0755 /usr/local/bin/bt-probe-agent; \
    rm -f /tmp/agent.sha256 /var/cache/apk/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

ENV BT_PROBE_CONFIG_PATH=/data/config.json \
    BT_PROBE_STATE_DIR=/data/state \
    BT_PROBE_RUN_DIR=/run/bt-probe-agent \
    BT_PROBE_LOG_MODE=file \
    TBT_CONTROL_PLANE_URL=https://t.bt.cn \
    TBT_AGENT_ENDPOINT=wss://t.bt.cn/ws/agent

VOLUME ["/data"]
ENTRYPOINT ["/bin/sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["start"]
