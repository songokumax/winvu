#!/bin/bash
set -e

COUNT=10                        # Số lượng proxy
START_PORT=10000                # Port bắt đầu
USER_PASS_LIST=("user1:pass1" "user2:pass2")   # Danh sách user
CONFIG_PATH="/usr/local/3proxy"
BIN_PATH="/usr/local/3proxy/bin"
IFACE=$(ip -6 route show default | awk '{print $5}' | head -n1)

echo "========================"
echo "📦 Cài đặt 3proxy"
echo "========================"

apt update -qq && apt install -y git gcc make curl net-tools build-essential

cd /opt
rm -rf 3proxy || true
git clone https://github.com/z3APA3A/3proxy.git > /dev/null 2>&1 || true
cd 3proxy
make -f Makefile.Linux
mkdir -p "$BIN_PATH"
cp bin/3proxy "$BIN_PATH/"   # ✅ sửa lại đường dẫn nhị phân đúng

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
    ip -6 addr add "$IPV6"/64 dev "$IFACE" preferred_lft 0 valid_lft forever deprecated || true
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
