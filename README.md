# bt-probe-agent（Docker 容器版）

把**宝塔网络拨测节点**（`bt-probe-agent`）跑在 Docker 容器里，避免直接安装在宿主机上，实现环境隔离。

[![build-and-publish](https://github.com/FanStudio2077/bt-probe-agent-docker/actions/workflows/build-and-publish.yml/badge.svg)](https://github.com/FanStudio2077/bt-probe-agent-docker/actions/workflows/build-and-publish.yml)

---

## 特性

- **一键部署**：官方 `curl ... | sudo bash` 的等价容器化版本，不需要 systemd
- **首次启动自动申请绑定链接**：`docker logs` 里直接拿到绑定 URL
- **身份持久化**：配置与状态保存在 `/data` 数据卷，重启/升级不丢失绑定
- **多架构**：`linux/amd64`、`linux/arm64`（GitHub Actions 自动构建）
- **构建可校验**：二进制从宝塔官方地址下载，并用官方 SHA-256 校验
- **最小权限**：仅保留 `NET_RAW`（ping/traceroute/portscan 需要），开启 `no-new-privileges`
- **不挂载宿主机目录**：容器只能看到自己的数据卷

## 工作原理

宝塔官方安装脚本实际上做了三件事：

1. 下载静态链接的 Go 二进制 `bt-probe-agent`（带 SHA-256 校验）
2. 写入 systemd unit
3. 执行 `public-activate` 生成绑定链接，然后由 systemd 启动 `bt-probe-agent start`

容器里不需要 systemd，所以本镜像直接：

- 构建时下载并校验二进制
- 首次启动时执行 `public-activate` 打印绑定 URL
- 然后 `exec bt-probe-agent start` 以前台进程运行

## 快速开始

### 方式一：docker run

```bash
docker run -d \
  --name bt-probe-agent \
  --restart unless-stopped \
  --cap-add=NET_RAW \
  --security-opt=no-new-privileges:true \
  -v bt-probe-agent-data:/data \
  fanstudio2077/bt-probe-agent:latest
```

看绑定链接：

```bash
docker logs bt-probe-agent
```

输出示例：

```text
[entrypoint] 未找到身份配置，正在申请绑定链接 / no identity found, requesting activation link...
Agent 公共激活身份已新建: uuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx config=/data/config.json
请在浏览器完成绑定:
  URL: https://t.bt.cn/activate/XXXX-XXXX
  user_code: XXXX-XXXX
  状态: waiting_login
```

浏览器打开上面的 URL，登录宝塔账号确认绑定即可。绑定后状态会变成 `pending_review`（等待平台审核），审核通过后自动变为 `active`。

### 方式二：docker compose

```bash
docker compose up -d
docker compose logs -f
```

## 日常运维

```bash
docker logs -f bt-probe-agent                                             # 实时日志
docker exec bt-probe-agent bt-probe-agent status                          # 运行状态
docker exec bt-probe-agent cat /data/state/activation.json                # 激活状态
docker restart bt-probe-agent                                             # 重启
```

绑定链接过期（默认 15 分钟）后重新生成：

```bash
docker exec bt-probe-agent bt-probe-agent public-activate \
  --control-plane-url https://t.bt.cn \
  --endpoint wss://t.bt.cn/ws/agent
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `BT_PROBE_CONFIG_PATH` | `/data/config.json` | 身份配置文件 |
| `BT_PROBE_STATE_DIR` | `/data/state` | 持久状态目录（日志、自检库等） |
| `BT_PROBE_RUN_DIR` | `/run/bt-probe-agent` | 运行时目录（pid、socket） |
| `BT_PROBE_LOG_MODE` | `file` | 日志模式：`file` 或 `journald`（容器内建议 `file`） |
| `TBT_CONTROL_PLANE_URL` | `https://t.bt.cn` | 控制面地址 |
| `TBT_AGENT_ENDPOINT` | `wss://t.bt.cn/ws/agent` | 网关地址 |

日志同时输出到容器 stdout/stderr 和 `/data/state/log/agent.log`。

## 构建镜像

```bash
# 本机架构
docker build -t bt-probe-agent:latest .

# 指定版本 / 自定义下载地址
docker build \
  --build-arg TBT_VERSION=1.1.60 \
  --build-arg TBT_DOWNLOAD_BASE_URL=https://t.bt.cn/agent/download \
  -t bt-probe-agent:1.1.60 .

# 多架构 + 推送（需要先 docker login）
docker buildx build --platform linux/amd64,linux/arm64 \
  -t fanstudio2077/bt-probe-agent:latest --push .
```

## 自动发布（GitHub Actions）

`.github/workflows/build-and-publish.yml` 会在 push 到 `main` 或打 `v*` tag 时：

- 构建 `linux/amd64` + `linux/arm64` 镜像
- 推送到 **GHCR**：`ghcr.io/<owner>/bt-probe-agent`
- 若配置了以下 Secrets，同时推送到 **Docker Hub**

在仓库 Settings → Secrets and variables → Actions 中配置：

| Secret | 说明 |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token（不要用登录密码） |

## 升级

```bash
docker pull fanstudio2077/bt-probe-agent:latest
docker rm -f bt-probe-agent            # 注意：不要加 -v，不要删除数据卷
docker run -d ... fanstudio2077/bt-probe-agent:latest   # 数据卷保留，绑定不丢失
```

## 卸载

```bash
docker rm -f bt-probe-agent
docker volume rm bt-probe-agent-data   # 会丢失身份，需要重新绑定
```

## 安全说明

- 容器内以 root 运行（`bt-probe-agent` 需要发送 raw socket 做 ping/traceroute），但 **root 仅限容器命名空间内**
- 只授予 `NET_RAW` 一个 capability，开启 `no-new-privileges`
- **不挂载** 宿主机目录，宿主文件系统不可见
- 数据卷 `/data` 只存放 agent 自己的配置、状态和日志

> 该 agent 是**网络拨测**用途（http/tcp/ping/dns/traceroute/portscan），容器走 bridge 网络，出口公网 IP 与宿主机一致。如果宝塔侧需要采集宿主机的 CPU/内存/磁盘，容器内看到的是容器资源，请评估是否符合需求。

## 网络隔离：仅允许中国大陆 IP（推荐，用于通过审核）

部分场景下（例如宝塔拨测节点审核）要求节点**不能访问境外网络、不能走代理**。本仓库提供一个可选的出站防火墙方案：

1. 容器使用独立 bridge 网络（不要用默认 bridge / host 网络）：

```bash
docker network create --driver bridge --subnet 172.30.66.0/24 --gateway 172.30.66.1 btprobe-net

docker run -d \
  --name bt-probe-agent \
  --restart unless-stopped \
  --network btprobe-net \
  --cap-add=NET_RAW \
  --security-opt=no-new-privileges:true \
  -v bt-probe-agent-data:/data \
  fanstudio2077/bt-probe-agent:latest
```

2. 在宿主机安装并启用出站防火墙（nftables）：

```bash
install -m 0755 scripts/egress-cn-only.sh /usr/local/sbin/btprobe-egress.sh
install -m 0644 systemd/btprobe-egress.service /etc/systemd/system/
install -m 0644 systemd/btprobe-egress.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now btprobe-egress.service btprobe-egress.timer
```

规则效果（对 `172.30.66.0/24` 生效）：

- 允许：已建立连接、中国大陆 IP（`/etc/btprobe/cn.zone`，每周自动更新）
- 丢弃：其余所有出站（含境外 IP、宿主机内网/代理端口）

3. 验证：

```bash
# 境内正常
docker exec bt-probe-agent curl -s -o /dev/null -w '%{http_code}\n' -m 8 https://www.baidu.com
# 境外应超时/失败
docker exec bt-probe-agent curl -s -o /dev/null -w '%{http_code}\n' -m 8 https://www.google.com
```

> 注意：
> - 该模式下节点只能拨测境内目标；如果宝塔平台给你派发境外拨测任务，会失败，请先确认审核方的要求。
> - 若宿主机装了宝塔面板/防火墙插件，其规则重载可能清掉自定义规则，`btprobe-egress.timer` 每 10 分钟会自动补回。
> - 卸载宿主机上直接安装的 agent 可执行：`sh scripts/uninstall-host-agent.sh`

## 常见问题

**Q: 日志里一直是 `pending_review` 怎么办？**

绑定已成功提交，等待宝塔平台审核。这一步与容器无关，审核通过后会通过 WSS 自动推送 `status=active`，不需要重启容器。

**Q: 绑定链接过期了？**

见上文「日常运维」，用 `docker exec ... public-activate` 重新生成。

**Q: 容器内 DNS 偶尔解析失败（`nslookup` 超时）？**

部分宿主机（尤其装了代理/软路由的机器）上 Docker 内嵌 DNS 到上游的 UDP 查询会间歇性超时，dockerd 日志可见 `[resolver] failed to query external DNS server`。给容器显式指定国内 DNS 即可绕过内嵌 DNS 的上游解析：

```bash
docker run ... --dns 223.5.5.5 --dns 119.29.29.29 ...
```

**Q: 宿主机装了 Clash/V2Ray 等代理，容器会不会走代理？**

不会。容器不会继承宿主机的代理环境变量；若宿主机还配置了 Docker 守护进程代理（`/etc/systemd/system/docker.service.d/proxy.conf`），那只作用于**镜像拉取**，不影响容器内进程。配合「仅中国大陆 IP」出站规则，容器也访问不到宿主机上的代理端口（如 `127.0.0.1:7890` / `192.168.x.x:7890`）。

**Q: 容器一直重启？**

`docker logs bt-probe-agent` 查看原因。常见是首次启动时无法访问 `t.bt.cn`（网络/DNS），可以先确认容器内可访问外网。

**Q: Apple Silicon / ARM 服务器能用吗？**

可以，GitHub Actions 会构建 `linux/arm64` 镜像；`docker buildx` 本地构建也支持。

## 声明

- 本项目仅提供**容器封装**（Dockerfile、入口脚本、文档），代码采用 MIT 协议
- `bt-probe-agent` 二进制由宝塔官方发布，版权归宝塔所有；镜像构建时从官方地址下载并校验 SHA-256，**本仓库不包含也不重新分发该二进制**
- 使用本镜像即表示你同意遵守宝塔相关的服务条款；请仅用于你有权使用的服务器