#!/bin/bash
set -e

random() {
  tr </dev/urandom -dc A-Za-z0-9 | head -c5
  echo
}

declare -a array=(0 1 2 3 4 5 6 7 8 9 a b c d e f)

ip64() {
  printf "%s%s%s%s" "${array[$RANDOM % 16]}" "${array[$RANDOM % 16]}" "${array[$RANDOM % 16]}" "${array[$RANDOM % 16]}"
}

gen64() {
  printf "%s:%s:%s:%s:%s\n" "$1" "$(ip64)" "$(ip64)" "$(ip64)" "$(ip64)"
}

install_3proxy() {
  printf "Đang cài đặt 3proxy...\n"
  local URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
  wget -qO- "$URL" | bsdtar -xvf- || { echo "Lỗi: Tải 3proxy thất bại"; exit 1; }
  cd 3proxy-3proxy-0.8.6 || { echo "Lỗi: Không thể chuyển vào thư mục 3proxy"; exit 1; }

  # 👉 Sửa lỗi multiple definition của biến 'authnserver'
  sed -i 's/^struct nserver authnserver;/extern struct nserver authnserver;/' src/proxy.h

  make -f Makefile.Linux || { echo "Lỗi: Biên dịch 3proxy thất bại"; exit 1; }
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat} || { echo "Lỗi: Không thể tạo thư mục 3proxy"; exit 1; }
  cp src/3proxy /usr/local/etc/3proxy/bin/ || { echo "Lỗi: Không thể copy file 3proxy"; exit 1; }

  # 👉 Thay vì dùng init.d, dùng systemd
  cat >/etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable 3proxy || { echo "Lỗi: Không thể enable dịch vụ 3proxy"; exit 1; }

  cd "$WORKDIR"
}





gen_3proxy() {
  local tmp_config=$(mktemp)
  printf "daemon\n" > "$tmp_config"
  printf "maxconn 1000\n" >> "$tmp_config"
  printf "nscache 65536\n" >> "$tmp_config"
  printf "timeouts 1 5 30 60 180 1800 15 60\n" >> "$tmp_config"
  printf "setgid 65535\n" >> "$tmp_config"
  printf "setuid 65535\n" >> "$tmp_config"
  printf "flush\n" >> "$tmp_config"
  printf "auth strong\n" >> "$tmp_config"

  printf "users $(awk -F/ 'BEGIN{ORS=\"\";} {print \$1 \":CL:\" \$2 \" \"}' \"${WORKDATA}\")\n" >> "$tmp_config"

    while IFS='/' read user pass ip4 port ip6; do
      printf "auth strong\n" >> "$tmp_config"
      printf "allow %s\n" "$user" >> "$tmp_config"
      printf "proxy -6 -n -a -p %s -i %s -e %s\n" "$port" "$ip4" "$ip6" >> "$tmp_config"
      printf "flush\n" >> "$tmp_config"
    done < "$WORKDATA"
  cp "$tmp_config" /usr/local/etc/3proxy/3proxy.cfg || { echo "Lỗi: Copy cấu hình 3proxy thất bại"; exit 1; }
}

gen_proxy_file_for_user() {
  awk -F '/' '{print $3 ":" $4 ":" $1 ":" $2}' "$WORKDATA" > proxy.txt
}

upload_proxy() {
  local PASS=$(random)
  zip --password "$PASS" proxy.zip proxy.txt || { echo "Lỗi: Nén file proxy thất bại"; exit 1; }
  local URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)

  printf "\nProxy đã sẵn sàng! Định dạng: IP:CỔNG:LOGIN:PASS\n"
  printf "Tải về từ: %s\n" "$URL"
  printf "Mật khẩu: %s\n" "$PASS"
  printf "\nLưu ý: Hãy nhớ mật khẩu này để giải nén file proxy.zip\n"
}

install_jq() {
  printf "Đang cài đặt jq...\n"
  wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 || { echo "Lỗi: Tải jq thất bại"; exit 1; }
  chmod +x ./jq || { echo "Lỗi: Không thể cấp quyền chạy cho jq"; exit 1; }
  cp jq /usr/bin || { echo "Lỗi: Không thể copy jq vào /usr/bin"; exit 1; }
}

gen_data() {
  local count=0
  while [ "$count" -lt "$COUNT" ]; do
    local port=$(($FIRST_PORT + $count))
    printf "usr%s/pass%s/%s/%s/%s\n" "$(random)" "$(random)" "$IP4" "$port" "$(gen64 "$IP6")"
    ((count++))
  done
}

gen_iptables() {
  local tmp_iptables=$(mktemp)
  local ip_count=0
    while [ "$ip_count" -lt ${#ALLOWED_IPS[@]} ]; do
         local allowed_ip="${ALLOWED_IPS[$ip_count]}"
            while IFS='/' read user pass ip4 port ip6; do
                 printf "firewall-cmd --permanent --add-port=%s/tcp --add-source=%s\n" "$port" "$allowed_ip" >> "$tmp_iptables"
          done < "$WORKDATA"
           ((ip_count++))
    done
  cp "$tmp_iptables" "$WORKDIR/boot_iptables.sh" || { echo "Lỗi: Copy iptables config failed."; exit 1; }
  chmod +x "$WORKDIR/boot_iptables.sh" || { echo "Lỗi: Cấp quyền chạy cho boot_iptables.sh thất bại"; exit 1; }

  printf "firewall-cmd --reload\n" >> "$tmp_iptables"
  chmod +x "$tmp_iptables"
  bash "$tmp_iptables" || { echo "Lỗi: Chạy iptables thất bại"; exit 1; }
}

gen_ifconfig() {
   local tmp_ifconfig=$(mktemp)
  while IFS='/' read user pass ip4 port ip6; do
   printf "ip -6 addr add %s/64 dev eth0\n" "$ip6" >> "$tmp_ifconfig"
  done < "$WORKDATA"
  cp "$tmp_ifconfig" "$WORKDIR/boot_ifconfig.sh" || { echo "Lỗi: Copy ifconfig config failed."; exit 1; }
  chmod +x "$WORKDIR/boot_ifconfig.sh" || { echo "Lỗi: Cấp quyền chạy cho boot_ifconfig.sh thất bại"; exit 1; }
   bash "$tmp_ifconfig" || { echo "Lỗi: Chạy ifconfig thất bại"; exit 1; }
}

printf "Đang cài đặt các ứng dụng...\n"
yum -y install gcc net-tools bsdtar zip wget >/dev/null || { echo "Lỗi: Cài đặt ứng dụng thất bại"; exit 1; }

install_3proxy

printf "Thư mục làm việc = %s\n" "/home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p "$WORKDIR" && cd "$_" || { echo "Lỗi: Không thể tạo thư mục làm việc"; exit 1; }

IP4=$(curl -4 -s icanhazip.com) || { echo "Lỗi: Không thể lấy địa chỉ IPv4"; exit 1; }
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':') || { echo "Lỗi: Không thể lấy địa chỉ IPv6"; exit 1; }

printf "Địa chỉ IP nội bộ = %s. Địa chỉ IPv6 = %s\n" "$IP4" "$IP6"

read -p "Bạn muốn tạo bao nhiêu proxy? Ví dụ: 500: " COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT - 1))

ALLOWED_IPS=()
printf "Nhập tối đa 5 dải địa chỉ IP được phép truy cập proxy (ví dụ: 192.168.1.0/24). Nhấn Enter để kết thúc:\n"
while true; do
  read -p "Dải IP ($(( ${#ALLOWED_IPS[@]} + 1 ))/5): " ALLOWED_IP
  if [[ -z "$ALLOWED_IP" ]]; then
      break
  elif [[ ${#ALLOWED_IPS[@]} -ge 5 ]]; then
     printf "Bạn đã nhập tối đa 5 dải IP. Kết thúc.\n"
      break
  else
    ALLOWED_IPS+=("$ALLOWED_IP")
  fi
done

if [ ${#ALLOWED_IPS[@]} -eq 0 ]; then
  printf "Không có dải địa chỉ IP nào được nhập. Proxy sẽ không hạn chế địa chỉ truy cập. Điều này có thể khiến proxy bị đánh dấu là open proxy. Bạn nên hạn chế IP truy cập\n"
fi

gen_data >"$WORKDIR/data.txt"
gen_iptables
gen_ifconfig

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash "$WORKDIR/boot_iptables.sh"
bash "$WORKDIR/boot_ifconfig.sh"
ulimit -n 10048
systemctl start 3proxy
EOF
chmod +x /etc/rc.local || { echo "Lỗi: Không thể cấp quyền chạy cho /etc/rc.local"; exit 1; }
bash /etc/rc.local || { echo "Lỗi: Chạy rc.local thất bại"; exit 1; }

gen_proxy_file_for_user

install_jq && upload_proxy
