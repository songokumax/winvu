#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
set -e
sleep 1

echo "🔧 Đang cài đặt 3proxy..."

apt update > /dev/null 2>&1 && apt install -y git make gcc ufw curl > /dev/null 2>&1 || true
sleep 2

# Clone và build
cd /opt || exit
git clone https://github.com/z3APA3A/3proxy.git > /dev/null 2>&1 || true
cd 3proxy || exit
sleep 2
make -f Makefile.Linux > /dev/null 2>&1
sleep 2
# Copy file nhị phân
mkdir -p /etc/3proxy/logs
sleep 2
cp ./bin/3proxy /usr/local/bin/ > /dev/null 2>&1
sleep 2
chmod +x /usr/local/bin/3proxy

# Thông tin người dùng & danh sách port
USERNAME="bgsydushac"
PASSWORD="Nhgd*a5gatAGauneis"
PORT_LIST=(40001 40003)

CONFIG_FILE="/etc/3proxy/3proxy.cfg"

# Lấy địa chỉ IP công cộng
SERVER_IP=$(curl -s ipv4.icanhazip.com)

echo "⚙️ Đang tạo file cấu hình 3proxy..."
sleep 1

cat <<EOF > $CONFIG_FILE
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

auth strong
users $USERNAME:CL:$PASSWORD
EOF

for PORT in "${PORT_LIST[@]}"; do
    echo "allow $USERNAME" >> $CONFIG_FILE
    echo "socks -p$PORT -i$SERVER_IP -e$SERVER_IP" >> $CONFIG_FILE
done

echo "flush" >> $CONFIG_FILE
sleep 2
# Tạo systemd service
echo "🛠️ Tạo systemd service..."

cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sleep 2
# Khởi động dịch vụ
systemctl daemon-reload > /dev/null 2>&1
sleep 1
systemctl enable 3proxy > /dev/null 2>&1 || true
sleep 1
systemctl restart 3proxy || true
sleep 2
# Mở port firewall
echo "🚪 Mở các port trên firewall..."
for PORT in "${PORT_LIST[@]}"; do
    ufw allow $PORT/tcp || true
done
sleep 2
echo "✅ Cài đặt hoàn tất!"
#echo "🔐 Proxy SOCKS5 chạy trên IP: $SERVER_IP"
#echo "➡️ Ports: ${PORT_LIST[*]}"
#echo "👤 User: $USERNAME"
#echo "🔑 Pass: $PASSWORD"
