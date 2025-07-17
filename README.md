# WARP Proxy Container

一个功能强大且稳定的 Docker 容器，通过 Cloudflare WARP 提供 SOCKS5 和 HTTP 代理服务。

## ✨ 特性

- **WARP 网络**: 所有流量通过 Cloudflare WARP 网络，隐藏真实 IP。
- **智能 IP 优选**: 定期自动扫描并切换到最优的 Cloudflare Endpoint IP。
- **断线自动重连**: 7x24 小时监控连接状态，断开后自动尝试重连。
- **SOCKS5 & HTTP 代理**: 同时提供两种常用代理协议。
- **持久化支持**: 支持通过挂载卷来持久化 WARP 和 Usque 的注册信息。
- **多架构支持**: 支持 `linux/amd64` 和 `linux/arm64` 架构。

## 🚀 如何使用

```bash
docker run -d \
  --name warp-proxy \
  --restart always \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  -v /lib/modules:/lib/modules \
  -v $(pwd)/wgcf:/wgcf \
  -p 1080:1080 \
  -p 8080:8080 \
  -e SOCKS5_PORT=1080 \
  -e HTTP_PORT=8080 \
  -e USER=your_user \
  -e PASSWORD=your_pass \
  your_dockerhub_username/warp-proxy:latest
```

## 环境变量

| 变量 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `SOCKS5_PORT` | `1080` | SOCKS5 代理监听端口。 |
| `HTTP_PORT` | (无) | **必填以启用HTTP代理**。HTTP 代理监听端口。 |
| `USER` | (无) | SOCKS5 和 HTTP 代理的用户名。 |
| `PASSWORD` | (无) | SOCKS5 和 HTTP 代理的密码。 |
| `HOST` | `0.0.0.0` | 代理监听的 IP 地址。 |
| `OPTIMIZE_INTERVAL` | `21600` | IP 优选的周期（秒），默认 6 小时。 |
| `HEALTH_CHECK_INTERVAL`| `60` | 连接健康检查的周期（秒）。 |

## 📁 持久化

为了避免每次重启容器都重新注册 WARP 和 Usque，强烈建议您将 `/wgcf` 目录挂载到宿主机上。

- `-v $(pwd)/wgcf:/wgcf`

首次运行后，此目录将包含 `wgcf-account.toml` 和 `config.json` 等文件。
