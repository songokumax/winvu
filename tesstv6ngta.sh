#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
set -e
sleep 1

IP_FILE="/root/ipv6_goc.list"
IFACE=$(ip -6 route get 2001:4860:4860::8888 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')

# 🔹 Hàm lấy tất cả IPv6 hiện tại của interface
get_current_ipv6() {
    ip -6 addr show dev "$IFACE" | grep "inet6" | awk '{print $2}'
}

# 🔹 Lưu IPv6 gốc (chỉ lần đầu)
if [ ! -f "$IP_FILE" ]; then
#    echo "📝 Đang lưu IPv6 gốc vào $IP_FILE..."
    get_current_ipv6 > "$IP_FILE"
#    echo "✅ Đã lưu IPv6 gốc. Chạy lại script để xoá IPv6 phụ sau này."
#    exit 0
fi

if command -v 3proxy >/dev/null 2>&1; then
    echo "✅ 3proxy đã được cài đặt trên hệ thống."
    IP_FILE="/root/ipv6_goc.list"
    IFACE=$(ip -6 route get 2001:4860:4860::8888 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
    get_current_ipv6() {
        ip -6 addr show dev "$IFACE" | grep "inet6" | awk '{print $2}'
    }
    if [ -f "$IP_FILE" ]; then
        mapfile -t GOC_IPV6 < "$IP_FILE"
        mapfile -t CUR_IPV6 < <(get_current_ipv6)
        echo "🧹 Đang dọn các IPv6 phụ và đóng port(nếu có,)..."
        for ip in "\${CUR_IPV6[@]}"; do
            keep=false
            for saved_ip in "\${GOC_IPV6[@]}"; do
                if [[ "$ip" == "$saved_ip" ]]; then
                    keep=true
                    break
                fi
            done
            if ! $keep; then
                ip -6 addr del "$ip" dev "$IFACE" > /dev/null 2>&1 || true
            fi
        done
        (grep -E 'proxy -6.*-p[0-9]+|socks -6.*-p[0-9]+' /etc/3proxy/3proxy.cfg | awk -F'-p' '{print $2}' | awk '{print $1}' | xargs -I {} ufw delete allow {}/tcp) > /dev/null 2>&1 || true
        echo "✅ Dọn dẹp hoàn tất các ipv6 phụ và đóng port."
    fi
    exit 0
fi
