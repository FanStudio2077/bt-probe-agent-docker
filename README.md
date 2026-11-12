# bt-probe-agent（Docker 容器版）

把**宝塔网络拨测节点**（`bt-probe-agent`）跑在 Docker 容器里，避免直接安装在宿主机上，实现环境隔离。

[![build-and-publish](https://github.com/FanStudio2077/bt-probe-agent-docker/actions/workflows/build-and-publish.yml/badge.svg)](https://github.com/FanStudio2077/bt-probe-agent-docker/actions/workflows/build-and-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/fanstudio2077/bt-probe-agent.svg)](https://hub.docker.com/r/fanstudio2077/bt-probe-agent)
[![Docker Image Size](https://img.shields.io/docker/image-size/fanstudio2077/bt-probe-agent/latest)](https://hub.docker.com/r/fanstudio2077/bt-probe-agent)

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

## 镜像地址

| 仓库 | 地址 |
|---|---|
| Docker Hub | `fanstudio2077/bt-probe-agent:latest`（amd64 / arm64） |
| GHCR | `ghcr.io/fanstudio2077/bt-probe-agent:latest`（amd64 / arm64） |

```bash
docker pull fanstudio2077/bt-probe-agent:latest
# 或
docker pull ghcr.io/fanstudio2077/bt-probe-agent:latest
```

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