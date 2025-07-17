WARP + Usque 代理容器：终极版
一个功能强大、高可用、全自动的 Docker 容器，通过 Cloudflare WARP 提供 SOCKS5 和 HTTP 代理服务。

✨ 项目特性
全文件固化: 所有核心工具 (usque, warp, wgcf) 均在构建时安装到镜像中，容器启动后无需从网络下载任何依赖，确保了在任何网络环境下的稳定启动。

智能 WARP 检测: 通过 curl --interface wgcf 直接测试 WireGuard 网络接口的连通性，精确判断 WARP 隧道是否真实可用，避免了代理服务的假活状态。

双重恢复机制:

连接自愈: 高频次（可配置）的健康检查能快速发现连接中断，并通过自动更换优选 IP 的方式实现“连接级”的快速恢复。

容器级熔断: 当连续多次“自愈”失败后（可配置），脚本会主动退出，以触发 Docker 的 restart 策略，实现“容器级”的恢复，从容应对网络抖动或 IP 被封锁等疑难杂症。

定时 IP 优选与热重载:

后台定时（默认6小时，可配置）自动执行 Cloudflare Endpoint IP 优选，持续更新本地的高质量 IP 池。

优选完成后，通过“信号”机制，立即无缝地重启 WireGuard 连接以应用最新的优选 IP，无需等待下一次断线。

全参数可配: 从代理端口、认证信息到各种健康检查的时间、次数阈值，均可通过 Docker 环境变量进行灵活配置，无需修改代码或重建镜像。

功能完备: 同时提供 SOCKS5 和 HTTP 代理服务，并完整支持用户名/密码认证。

多架构支持: Dockerfile 和 CI/CD 流程完整支持 linux/amd64 和 linux/arm64 两种主流架构，一次构建，多平台适用。

最佳实践构建: 采用多阶段 Docker 构建，最终镜像基于轻量化的 alpine，体积小、更安全。

📁 最终文件清单
在您的项目根目录中，请确保拥有以下 3 个核心文件：

Dockerfile: 用于构建镜像的蓝图。

run.sh: 容器启动后运行的主脚本。

.github/workflows/release.yml: 用于在发布 Release 时自动构建和推送镜像的 GitHub Actions 工作流。

🚀 完整操作流程
步骤一：在 GitHub 上准备仓库
创建仓库: 在 GitHub 创建一个新仓库，例如 warp-usque-proxy。

上传文件: 将下面提供的 Dockerfile, run.sh, 和 .github/workflows/release.yml 这三个文件上传到您的仓库中。

步骤二：发布 Release 并自动构建
进入 Release 页面: 在您的 GitHub 仓库页面，点击 "Releases" -> "Draft a new release"。

创建版本号: 输入一个版本号，例如 v1.0.0。

发布: 点击 "Publish release"。

等待构建: GitHub Actions 会自动被触发。进入 "Actions" 标签页，您可以看到工作流正在执行。成功后，它会自动完成以下任务：

构建 linux/amd64 和 linux/arm64 的多架构镜像。

将镜像推送到您仓库关联的 GitHub Container Registry (GHCR)。

将两个架构的镜像分别打包成 .tar 文件，并作为附件上传到您刚刚发布的 Release 中。

步骤三：在服务器上部署
您可以选择两种方式获取镜像：

方式A (推荐): 从 GHCR 拉取

# 首先登录 GHCR (只需操作一次)
# 使用您的 GitHub 用户名和 Personal Access Token (PAT)
echo "YOUR_PAT" | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# 拉取镜像
docker pull ghcr.io/YOUR_USERNAME/warp-usque-proxy:latest

方式B: 从 Release 附件加载

# 从您的 GitHub Release 页面下载对应架构的 .tar 文件，例如 usque-proxy-arm64-v1.0.0.tar
# 上传到服务器后执行：
docker load -i usque-proxy-arm64-v1.0.0.tar

步骤四：启动容器
以下是一个功能齐全的启动命令示例。

# 为了持久化 WARP 和 Usque 的账户信息，先在主机上创建一个目录
mkdir -p /opt/warp-data

docker run -d \
   --name warp-proxy \
   --restart unless-stopped \
   --cap-add NET_ADMIN \
   -v /lib/modules:/lib/modules \
   -v /opt/warp-data:/wgcf \
   -p 1080:1080 \
   -p 8080:8080 \
   -e HTTP_PORT=8080 \
   -e USER=myuser \
   -e PASSWORD=mypassword \
   ghcr.io/YOUR_USERNAME/warp-usque-proxy:latest

--cap-add NET_ADMIN 和 -v /lib/modules:/lib/modules 是运行 WireGuard 所必需的。

-v /opt/warp-data:/wgcf 实现了账户信息的持久化，强烈推荐。

通过 -e 可以设置所有可配置的环境变量。

现在，您的代理服务已经成功运行！
