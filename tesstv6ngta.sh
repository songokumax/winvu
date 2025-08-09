#!/bin/bash
set -e
IFACE=$(ip -6 route get 2001:4860:4860::8888 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
if ! ip -6 addr show dev "$IFACE" > /dev/null 2>&1; then
    echo "❌ VPS không hỗ trợ IPv6 hoặc không tìm thấy interface!"
    exit 1
fi
IP6_PREFIX=$(ip -6 route get 2001:4860:4860::8888 | awk '/src/ {
    for(i=1;i<=NF;i++) if($i=="src") ip=$(i+1)
}
END{
    split(ip,a,":")
    for(i=1;i<=8;i++) {
        if(a[i]=="") a[i]="0000"
        while(length(a[i])<4) a[i]="0"a[i]
    }
    print a[1]":"a[2]":"a[3]":"a[4]
}')
RANDOM_IP6=$(printf "%x:%x:%x:%x" $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)))
IP6_FULL="$IP6_PREFIX:$RANDOM_IP6"
ip -6 addr add "$IP6_FULL/64" dev "$IFACE"
sleep 6
success=0
for i in {1..3}; do
    if ping6 -c 2 -W 5 -I "$IP6_FULL" 2606:4700:4700::1111 > /dev/null 2>&1; then
        echo "✅ IPv6 $IP6_FULL kết nối ra ngoài thành công (lần thử $i)."
        success=1
        break
    else
        echo "❌ Lần thử $i thất bại. Đợi 4s thử lại..."
        sleep 4
    fi
done
ip -6 addr del "$IP6_FULL/64" dev "$IFACE"
if [ $success -eq 0 ]; then
  echo "❌ Không thể kết nối IPv6 ra ngoài sau 3 lần thử."
  exit 1
fi
