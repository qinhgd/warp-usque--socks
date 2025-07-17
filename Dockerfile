# 使用一个轻量级的 Alpine 镜像
FROM alpine:latest

# 设置平台架构参数，用于下载正确的二进制文件
ARG TARGETARCH

# 安装所有运行时所需的依赖
RUN apk add --no-cache \
    curl \
    gawk \
    iproute2 \
    wireguard-tools \
    iptables \
    ip6tables \
    tar

# 关键修复：修补 wg-quick 脚本，以避免在 Docker 中因权限问题出错
RUN sed -i 's/sysctl -q net.ipv4.conf.all.src_valid_mark=1/#&/' /usr/bin/wg-quick

# =========================================================================
#  安装 Usque (从 v1.4.1 Release 下载预编译版)
# =========================================================================
ARG USQUE_VERSION=v1.4.1
# FIX: Download the correct .tar.gz archive, extract it, and clean up.
RUN curl -fL -o usque.tar.gz "https://github.com/Diniboy1123/usque/releases/download/${USQUE_VERSION}/usque-linux-${TARGETARCH}.tar.gz" && \
    tar -xzf usque.tar.gz && \
    mv usque /usr/local/bin/usque && \
    chmod +x /usr/local/bin/usque && \
    rm usque.tar.gz

# =========================================================================
#  安装其他工具
# =========================================================================
# 下载并安装 'warp' IP 优选工具
RUN curl -L -o /usr/local/bin/warp "https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-${TARGETARCH}" && \
    chmod +x /usr/local/bin/warp

# 下载并安装 'wgcf' 账户管理工具
ARG WGCF_VERSION=v2.2.19
RUN curl -fL -o /usr/local/bin/wgcf "https://github.com/ViRb3/wgcf/releases/download/${WGCF_VERSION}/wgcf_${WGCF_VERSION#v}_linux_${TARGETARCH}" && \
    chmod +x /usr/local/bin/wgcf

# 复制核心运行脚本
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

# 创建工作目录
WORKDIR /wgcf

# 设置容器入口点
ENTRYPOINT ["/usr/local/bin/run.sh"]
