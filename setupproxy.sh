#!/bin/bash


USERNAME="uhynSHnaocy"  #để user theo ý bạn
PASSWORD="Nsug*a5AGdyyvtxrgao"  #để pass theo ý bạn
PORTS=(40003 40004 40005 40006)  # Danh sách port, thay đổi theo nhu cầu

apt update && apt install -y git build-essential wget iptables-persistent

cd /opt
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy

make -f Makefile.Linux

mkdir -p /etc/3proxy /var/log/3proxy
cp ./src/3proxy /usr/bin/

cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
maxconn 200
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
users $USERNAME:CL:$PASSWORD
EOF

for PORT in "${PORTS[@]}"
do
    echo "auth strong" >> /etc/3proxy/3proxy.cfg
    echo "allow $USERNAME" >> /etc/3proxy/3proxy.cfg
    echo "proxy -n -a -p$PORT -i0.0.0.0 -e0.0.0.0" >> /etc/3proxy/3proxy.cfg
done

cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3Proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

for PORT in "${PORTS[@]}"
do
    ufw allow $PORT/tcp
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
done

netfilter-persistent save

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

echo "✅ Đã cài đặt xong proxy với user/pass và các port: ${PORTS[*]}"
