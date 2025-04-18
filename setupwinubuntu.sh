#!/bin/bash
#set -e

# --- Chọn phiên bản Windows trước khi vào RAM ---
if [[ -n "$1" && "$1" =~ ^[1-4]$ ]]; then
  choice="$1"
else
  echo "Vui lòng chọn phiên bản Windows Server để tải:"
  echo "1. Windows Server 2012 R2"
  echo "2. Windows Server 2016"
  echo "3. Windows Server 2019"
  echo "4. Windows 10 Lite"
  read -p " Nhập lựa chọn (1-4): " choice
fi

LINK_LIST_URL="https://raw.githubusercontent.com/songokumax/winvu/refs/heads/main/linkwin1.txt"
echo "Tải danh sách win..."
sleep 2
curl -sSL "$LINK_LIST_URL" -o linklist.txt

echo "Tìm link phù hợp với lựa chọn $choice..."
DOWNLOAD_URL=""
while IFS="|" read -r url ver; do
  if [[ "$ver" == "$choice" ]]; then
    echo -n "Kiểm tra link: $url ... "
    sleep 1
    if curl --head --silent --fail "$url" > /dev/null; then
      echo "OK"
      DOWNLOAD_URL="$url"
      break
    else
      echo "die"
    fi
  fi
done < linklist.txt

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Không tìm được link hoạt động cho phiên bản bạn chọn!"
  exit 1
fi

# Tạo RAM root
mkdir -p /mnt/ramroot
mount -t tmpfs -o size=512M tmpfs /mnt/ramroot
mkdir -p /mnt/ramroot/{bin,sbin,lib,lib64,proc,sys,dev,run,tmp,old_root}

# Copy busybox và tạo symlink
cp /bin/busybox /mnt/ramroot/bin/
cd /mnt/ramroot/bin
for i in $(./busybox --list); do ln -s busybox $i 2>/dev/null || true; done

# Mount các hệ thống cần thiết
mount --bind /dev /mnt/ramroot/dev
mount --bind /proc /mnt/ramroot/proc
mount --bind /sys /mnt/ramroot/sys

# Chuyển root sang RAM và chroot
cd /mnt/ramroot
pivot_root . old_root || echo "pivot_root failed, continuing with chroot"
chroot . /bin/sh -c "
  set +e
  mkdir -p /etc
  echo 'nameserver 8.8.8.8' > /etc/resolv.conf
  echo '>>> Bắt đầu ghi file vào disk...'
  wget -O- \"$DOWNLOAD_URL\" | gunzip | dd of=/dev/vda bs=4M || echo '❌ GHI LỖI'
  wait
  echo '>>> Ghi xong, đang sync...'
  sync
  echo '>>> Sẽ reboot sau 5s'
  sleep 5
 
"
