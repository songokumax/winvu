#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
set -e
sleep 1

if command -v 3proxy >/dev/null 2>&1; then
    echo "✅ 3proxy đã được cài đặt trên hệ thống."
    IP_FILE="/root/ipv6_goc.list"
    IFACE=$(ip -6 route get 2001:4860:4860::8888 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
    get_current_ipv6() {
        ip -6 addr show dev "$IFACE" | grep "inet6" | awk '{print $2}' > /dev/null 2>&1 || true
    }
    if [ -f "$IP_FILE" ]; then
        mapfile -t GOC_IPV6 < "$IP_FILE" > /dev/null 2>&1 || true
        mapfile -t CUR_IPV6 < <(get_current_ipv6) > /dev/null 2>&1 || true
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
( sudo apt install -y ufw && yes | sudo ufw enable ) > /dev/null 2>&1 || true
echo "🔧 Đang cài đặt 3proxy, vui lòng đợi..."
cd /opt > /dev/null 2>&1 || true
git clone https://github.com/z3APA3A/3proxy.git > /dev/null 2>&1 || true
cd 3proxy  > /dev/null 2>&1 || true
make -f Makefile.Linux > /dev/null 2>&1 || true
sleep 2
useradd -r -s /sbin/nologin 3proxy > /dev/null 2>&1 || true
mkdir -p /etc/3proxy /var/log/3proxy > /dev/null 2>&1 || true
cp /opt/3proxy/bin/3proxy /usr/bin/3proxy > /dev/null 2>&1 || true
sleep 2
cat <<EOF > /etc/3proxy/3proxy.cfg
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
log /var/log/3proxy/3proxy.log D
auth none
EOF
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
sleep 1
systemctl daemon-reexec > /dev/null 2>&1 || true
systemctl enable --now 3proxy > /dev/null 2>&1 || true
systemctl restart 3proxy > /dev/null 2>&1 || true
sleep 1
