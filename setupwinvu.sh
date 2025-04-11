#!/bin/bash

set -e

echo "Update hệ thống..."
pacman -Sy

echo "Kiểm tra các phân vùng..."
lsblk

echo "Gắn phân vùng /dev/vda2 vào /mnt..."
mount /dev/vda2 /mnt

cd /mnt
ls

echo "Vui lòng chọn phiên bản Windows Server để tải:"
echo "1. Windows Server 2012 R2"
echo "2. Windows Server 2016"
echo "3. Windows Server 2019"
echo "4. Windows 10 Lite"
read -p " Nhập lựa chọn (1-4): " choice

# Đường dẫn file TXT chứa danh sách link (thay thế bằng link GitHub thật của bạn)
LINK_LIST_URL="https://raw.githubusercontent.com/songokumax/winvu/main/winlist.txt"

echo "Tải danh sách link..."
curl -sSL "$LINK_LIST_URL" -o linklist.txt

echo "Tìm link phù hợp với lựa chọn $choice..."

DOWNLOAD_URL=""
while IFS="|" read -r url ver; do
    if [[ "$ver" == "$choice" ]]; then
        echo -n "Kiểm tra link: $url ... "
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

echo "Đang tải file từ: $DOWNLOAD_URL"
wget -O /mnt/windows.img.gz "$DOWNLOAD_URL"

echo "Giải nén file..."
gunzip windows.img.gz

EXTRACTED_IMG=$(ls *.img *.iso 2>/dev/null | head -n 1)

parted "$EXTRACTED_IMG" print

echo " Ghi image vào /dev/vda..."
dd if="$EXTRACTED_IMG" of=/dev/vda bs=4M status=progress

echo "Dọn dẹp..."
rm -f "$EXTRACTED_IMG" linklist.txt

cd

echo " Tháo gắn kết /mnt..."
umount /dev/vda2

echo "Hoàn tất! Bạn có thể khởi động lại máy."
