#!/bin/sh
set -e

# ==============================================================================
# 脚本配置 (Script Configuration)
# ==============================================================================

BEST_IP_FILE="/wgcf/best_ips.txt"
CONFIG_FILE="/wgcf/config.json" # Usque 配置文件路径
RECONNECT_FLAG_FILE="/wgcf/reconnect.flag"
OPTIMIZE_INTERVAL="${OPTIMIZE_INTERVAL:-21600}"
WARP_CONNECT_TIMEOUT="${WARP_CONNECT_TIMEOUT:-5}"
BEST_IP_COUNT="${BEST_IP_COUNT:-20}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-60}"
MAX_FAILURES="${MAX_FAILURES:-10}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-5}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-3}"

# ==============================================================================
# 工具函数 (Utility Functions)
# ==============================================================================

red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }

# ==============================================================================
# IP优选相关函数 (IP Selection Functions)
# ==============================================================================

run_ip_selection() {
    local ip_version_flag=""; [ "$1" = "-6" ] && ip_version_flag="-ipv6"
    green "🚀 开始优选 WARP Endpoint IP..."
    /usr/local/bin/warp -t "$WARP_CONNECT_TIMEOUT" ${ip_version_flag} > /dev/null
    if [ -f "result.csv" ]; then
        green "✅ 优选完成，正在处理结果..."
        # 放宽筛选条件，只要能通就行
        awk -F, '$3!="timeout ms" {print $1}' result.csv | sed 's/[[:space:]]//g' | head -n "$BEST_IP_COUNT" > "$BEST_IP_FILE"
        if [ -s "$BEST_IP_FILE" ]; then
            green "✅ 已生成包含 $(wc -l < "$BEST_IP_FILE") 个IP的优选列表。"
        else
            red "⚠️ 未能筛选出任何可用的IP，将使用默认地址。"
            echo "engage.cloudflareclient.com:2408" > "$BEST_IP_FILE"
        fi
        rm -f result.csv
    else
        red "⚠️ 未生成优选结果，将使用默认地址。"; echo "engage.cloudflareclient.com:2408" > "$BEST_IP_FILE"
    fi
}

# ==============================================================================
# 代理和连接核心功能 (Proxy and Core Connection Functions)
# ==============================================================================

_downwgcf() {
    yellow "正在清理 WireGuard 接口..."; wg-quick down wgcf >/dev/null 2>&1 || echo "wgcf 接口不存在或已关闭。"; yellow "清理完成。"; exit 0
}

update_wg_endpoint() {
    if [ ! -s "$BEST_IP_FILE" ]; then
        red "❌ 优选IP列表为空！将执行一次紧急IP优选..."
        run_ip_selection "$1"
    fi
    local random_ip=$(shuf -n 1 "$BEST_IP_FILE")
    green "🔄 已从优选列表随机选择新 Endpoint: $random_ip"
    sed -i "s/^Endpoint = .*$/Endpoint = $random_ip/" /etc/wireguard/wgcf.conf
}

_startProxyServices() {
    local HOST_IP="${HOST:-0.0.0.0}"

    # --- 启动 SOCKS5 代理 (无认证) ---
    if ! pgrep -f "usque socks" > /dev/null; then
        yellow "Starting Usque SOCKS5 proxy service..."
        local SOCKS5_PORT="${SOCKS5_PORT:-${PORT:-1080}}"
        # 移除了认证参数
        local SOCKS_COMMAND="usque socks -l ${HOST_IP}:${SOCKS5_PORT} -b wgcf"
        green "✅ SOCKS5 代理配置: ${HOST_IP}:${SOCKS5_PORT} | 认证: 已禁用"
        eval "${SOCKS_COMMAND} &"
    fi

    # --- (可选) 启动 HTTP 代理 (无认证) ---
    if [ -n "$HTTP_PORT" ]; then
        if ! pgrep -f "usque http-proxy" > /dev/null; then
            yellow "Starting Usque HTTP proxy service..."
            # 移除了认证参数
            local HTTP_COMMAND="usque http-proxy -l ${HOST_IP}:${HTTP_PORT} -b wgcf"
            green "✅ HTTP 代理配置: ${HOST_IP}:${HTTP_PORT} | 认证: 已禁用"
            eval "${HTTP_COMMAND} &"
        fi
    fi
}

_check_connection() {
    local check_url="https://www.cloudflare.com/cdn-cgi/trace"
    local curl_opts="-s -m ${HEALTH_CHECK_TIMEOUT}"
    for i in $(seq 1 "$HEALTH_CHECK_RETRIES"); do  
        if curl --interface wgcf ${curl_opts} ${check_url} 2>/dev/null | grep -q "warp=on"; then  
            return 0
        fi  
        if [ "$i" -lt "$HEALTH_CHECK_RETRIES" ]; then sleep 1; fi  
    done  
    return 1
}

# ==============================================================================
# 主运行函数 (Main Execution Function)
# ==============================================================================

runwgcf() {
    trap '_downwgcf' ERR TERM INT
    
    yellow "服务初始化..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        yellow "Usque 配置文件 (config.json) 未找到，开始自动注册..."
        if echo 'y' | usque register; then
            green "✅ Usque 自动注册成功！"
        else
            red "❌ Usque 自动注册失败，脚本将退出。"
            exit 1
        fi
    else
        green "✅ Usque 配置文件已存在，跳过注册。"
    fi

    if [ ! -e "wgcf-account.toml" ]; then
        yellow "WGCF 账户文件 (wgcf-account.toml) 未找到，开始自动注册..."
        wgcf register --accept-tos
        green "✅ WGCF 自动注册成功！"
    else
        green "✅ WGCF 账户文件已存在，跳过注册。"
    fi

    [ ! -e "wgcf-profile.conf" ] && wgcf generate
    cp wgcf-profile.conf /etc/wireguard/wgcf.conf
    
    [ "$1" = "-6" ] && sed -i 's/AllowedIPs = 0.0.0.0\/0/#AllowedIPs = 0.0.0.0\/0/' /etc/wireguard/wgcf.conf
    [ "$1" = "-4" ] && sed -i 's/AllowedIPs = ::\/0/#AllowedIPs = ::\/0/' /etc/wireguard/wgcf.conf
    
    [ ! -f "$BEST_IP_FILE" ] && run_ip_selection "$@"

    (  
        while true; do  
            sleep "$OPTIMIZE_INTERVAL"  
            yellow "🔄 [定时任务] 开始更新IP列表..."  
            wg-quick down wgcf >/dev/null 2>&1 || true  
            run_ip_selection "$@"  
            touch "$RECONNECT_FLAG_FILE"  
            yellow "🔄 [定时任务] IP列表更新完成，已发送重连信号。"  
        done  
    ) &  

    while true; do  
        local failure_count=0  
        while true; do  
            update_wg_endpoint "$@"  
            wg-quick up wgcf  
            if _check_connection "$@"; then  
                green "✅ WireGuard 连接成功！"  
                failure_count=0  
                break  
            else  
                failure_count=$((failure_count + 1))  
                red "❌ 连接失败 (${failure_count}/${MAX_FAILURES})，正在更换IP重试..."  
                if [ "$failure_count" -ge "$MAX_FAILURES" ]; then  
                    red "❌ 连续 ${MAX_FAILURES} 次连接失败，将退出以触发容器重启..."  
                    exit 1  
                fi  
                wg-quick down wgcf >/dev/null 2>&1 || true  
                sleep 3  
            fi  
        done  

        _startProxyServices  

        green "进入连接监控模式..."  
        while true; do  
            if [ -f "$RECONNECT_FLAG_FILE" ]; then  
                yellow "🔔 收到定时优选任务的重连信号，将立即刷新连接..."  
                rm -f "$RECONNECT_FLAG_FILE"  
                wg-quick down wgcf >/dev/null 2>&1 || true  
                break 
            fi  

            sleep "$HEALTH_CHECK_INTERVAL"  
            
            if ! _check_connection "$@"; then  
                red "💔 连接已断开！将立即尝试自动重连..."  
                wg-quick down wgcf >/dev/null 2>&1 || true  
                break
            fi  
        done  
    done
}

# ==============================================================================
# 脚本入口 (Script Entrypoint)
# ==============================================================================

cd /wgcf
runwgcf "$@"
