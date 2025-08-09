#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
set -e
sleep 1
IP6_PREFIX=$(ip -6 route get 2001:4860:4860::8888 | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") ip=$(i+1)} END{split(ip,a,":"); for(i=1;i<=8;i++) {if(a[i]=="") a[i]="0000"; while(length(a[i])<4) a[i]="0"a[i]} print a[1]":"a[2]":"a[3]":"a[4]}')
ETH=$(ip -6 route get 2001:4860:4860::8888 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
mkdir -p /etc/3proxy
> /root/ipv6_phu.list
START_PORT=14000
PROXY_COUNT=5
USER_LIST=('uuuuuuuuu')
PROXY_TYPE="socks5"
mkdir -p /etc/3proxy /var/log/3proxy
CONFIG="/etc/3proxy/3proxy.cfg"
> $CONFIG
cat <<EOF >> $CONFIG
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
log /var/log/3proxy/3proxy.log D
auth strong
users uuuuuuuuu:CL:gggggggggggg
EOF


echo "allow uuuuuuuuu" >> $CONFIG
 echo "" >> $CONFIG

gen_ipv6() {
  printf "%x:%x:%x:%x" $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536))
}
i=0
while [ $i -lt $PROXY_COUNT ]; do
  IPV6_FULL="$IP6_PREFIX:$(gen_ipv6)"
  PORT=$((START_PORT + i))
  ip -6 addr add "$IPV6_FULL/64" dev "$ETH" > /dev/null 2>&1 || true
  echo "$IPV6_FULL/64" >> /root/ipv6_phu.list
  ufw allow $PORT/tcp > /dev/null 2>&1 || true
  
  if [ "$PROXY_TYPE" = "socks5" ]; then
    echo "socks -6 -n -a -p$PORT -i0.0.0.0 -e$IPV6_FULL" >> $CONFIG
  else
    echo "proxy -6 -n -a -p$PORT -i0.0.0.0 -e$IPV6_FULL" >> $CONFIG
  fi
  i=$((i+1))
done
sleep 2
echo "✅ Đã xong, đợi restart 3proxy..."
systemctl restart 3proxy > /dev/null 2>&1 || true
