#!/bin/bash

set -e
sleep 5
echo "Kiểm tra các phân vùng..."
lsblk

parted --script /dev/vda mklabel gpt

#Tạo một phân vùng duy nhất chiếm toàn bộ dung lượng
parted --script /dev/vda mkpart primary ext4 0% 100%

# Đợi hệ thống cập nhật thiết bị mới
sleep 2

# Format phân vùng vừa tạo (thường là /dev/vda1)
mkfs.ext4 -F /dev/vda1
sleep 2
# Mount phân vùng vào /mnt
mount /dev/vda1 /mnt
sleep 2
echo "Update hệ thống..."
pacman -Sy
sleep 2
cd /mnt
ls

echo "Vui lòng chọn phiên bản Windows Server để tải:"
echo "1. Windows Server 2012 R2"
echo "2. Windows Server 2016"
echo "3. Windows Server 2019"
echo "4. Windows 10 Lite"
read -p " Nhập lựa chọn (1-4): " choice

# Đường dẫn file TXT chứa danh sách link (thay thế bằng link GitHub thật của bạn)
LINK_LIST_URL="https://raw.githubusercontent.com/songokumax/winvu/refs/heads/main/linkwin.txt"

echo "Tải danh sách link..."
sleep 3
wget -q "$LINK_LIST_URL" -O linklist.txt

echo "Tìm link phù hợp với lựa chọn $choice..."

DOWNLOAD_URL=""
while IFS="|" read -r url ver; do
    if [[ "$ver" == "$choice" ]]; then
        echo -n "Kiểm tra link: $url ... "
        sleep 3
        if wget --spider -q "$url"; then
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
sleep 3
wget -O /mnt/windows.img.gz "$DOWNLOAD_URL"

echo "Giải nén file..."
gunzip windows.img.gz

EXTRACTED_IMG=$(ls *.img *.iso 2>/dev/null | head -n 1)
sleep 2
parted "$EXTRACTED_IMG" print

echo " Ghi image vào /dev/vda..."
dd if="$EXTRACTED_IMG" of=/dev/vda bs=4M status=progress

echo "Dọn dẹp..."
rm -f "$EXTRACTED_IMG" linklist.txt

cd

echo " Tháo gắn kết /mnt..."
umount /dev/vda1

echo "Hoàn tất! Bạn có thể khởi động lại máy."
