#!/bin/bash
set -e

COUNT=10                        # Số lượng proxy
START_PORT=10000                # Port bắt đầu
USER_PASS_LIST=("user1:pass1" "user2:pass2")   # Danh sách user
CONFIG_PATH="/usr/local/3proxy"
BIN_PATH="/usr/local/3proxy/bin"

echo "========================"
echo "🔎 Kiểm tra IPv6 hỗ trợ"
echo "========================"

# Kiểm tra IPv6 có tồn tại
if ! ip -6 addr show scope global | grep -v "temporary" | grep -v "dynamic" | grep -q inet6; then
    echo "❌ VPS không có IPv6. Dừng script."
    exit 1
fi

# Lấy địa chỉ IPv6 đầu tiên
TEST_IPV6=$(ip -6 addr show scope global | grep inet6 | head -n1 | awk '{print $2}' | cut -d'/' -f1)
IFACE=$(ip -6 route show default | awk '{print $5}' | head -n1)

# Gán thử 1 IPv6 random và kiểm tra outbound
TEMP_IP="${TEST_IPV6%::*}:$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2)"
echo "[+] Thử gán IPv6: $TEMP_IP"
if ip -6 addr add "$TEMP_IP/64" dev "$IFACE" 2>/dev/null; then
    echo "[+] Ping thử 2001:4860:4860::8888 (Google DNS)..."
    PING_RESULT=$(ping -6 -c 2 -W 3 -I "$IFACE" 2001:4860:4860::8888 2>&1)
    ip -6 addr del "$TEMP_IP/64" dev "$IFACE"

    if echo "$PING_RESULT" | grep -q "0 received"; then
        echo "❌ IPv6 không có outbound Internet. Dừng script."
        exit 1
    else
        echo "✅ IPv6 có outbound Internet."
    fi
else
    echo "❌ VPS không cho gán thêm IPv6. Dừng script."
    exit 1
fi

echo "========================"
echo "📦 Cài đặt 3proxy"
echo "========================"

apt update -qq && apt install -y gcc make wget curl net-tools unzip build-essential

cd /opt
wget -q https://github.com/z3APA3A/3proxy/archive/refs/heads/master.zip
unzip -qo master.zip
cd 3proxy-master
make -f Makefile.Linux
mkdir -p "$BIN_PATH"
cp src/3proxy "$BIN_PATH/"

echo "========================"
echo "🌐 Lấy IPv6 prefix"
echo "========================"

IPV6_LINE=$(ip -6 addr show scope global | grep -v "temporary" | grep -v "dynamic" | head -n1 | awk '{print $2}')
IPV6_PREFIX=$(echo $IPV6_LINE | cut -d':' -f1-4 | tr ':' '\n' | paste -sd: -)
echo "✅ IPv6 Prefix: $IPV6_PREFIX"

# Hàm sinh IPv6 mới
gen_ipv6() {
    echo "${IPV6_PREFIX}:$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2)"
}

echo "========================"
echo "🧩 Gán IPv6 và tạo cấu hình"
echo "========================"

IP_LIST=()
PORT_LIST=()

for ((i=0; i<COUNT; i++)); do
    IPV6=$(gen_ipv6)
    PORT=$((START_PORT + i))
    ip -6 addr add "$IPV6"/64 dev "$IFACE"
    IP_LIST+=("$IPV6")
    PORT_LIST+=("$PORT")
done

echo "========================"
echo "🛡️ Mở port firewall (nếu có UFW)"
echo "========================"

if command -v ufw &>/dev/null; then
    for port in "${PORT_LIST[@]}"; do
        ufw allow "$port"/tcp
    done
    echo "✅ Đã mở port trên UFW"
else
    echo "⚠️ UFW không được cài, bỏ qua phần mở port"
fi

echo "========================"
echo "📁 Tạo cấu hình 3proxy"
echo "========================"

mkdir -p "$CONFIG_PATH"

cat <<EOF > "$CONFIG_PATH/3proxy.cfg"
daemon
maxconn 200
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
EOF

for ((i=0; i<COUNT; i++)); do
    PORT=${PORT_LIST[$i]}
    IP=${IP_LIST[$i]}
    echo "users $(IFS=,; echo "${USER_PASS_LIST[*]}" | sed 's/:/:CL:/g')" >> "$CONFIG_PATH/3proxy.cfg"
    echo "auth strong" >> "$CONFIG_PATH/3proxy.cfg"
    echo "allow *" >> "$CONFIG_PATH/3proxy.cfg"
    echo "proxy -6 -n -a -p$PORT -i0.0.0.0 -e$IP" >> "$CONFIG_PATH/3proxy.cfg"
    echo "" >> "$CONFIG_PATH/3proxy.cfg"
done

echo "========================"
echo "⚙️ Tạo systemd service"
echo "========================"

cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH/3proxy $CONFIG_PATH/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo "========================"
echo "✅ Danh sách proxy đã tạo"
echo "========================"

for ((i=0; i<COUNT; i++)); do
    IP=${IP_LIST[$i]}
    PORT=${PORT_LIST[$i]}
    for up in "${USER_PASS_LIST[@]}"; do
        IFS=':' read -r u p <<< "$up"
        echo "$u:$p@[$IP]:$PORT"
    done
done
