#!/bin/bash

set -e

# Màu đỏ đậm
RED_BOLD=$'\033[1;31;1m'
NC=$'\033[0m'

# Nội dung
text="=== Script By Thanh Quang Nguyen ==="

# Tính chiều dài terminal và khung
term_width=$(tput cols)
box_width=$(( ${#text} + 10 ))

# Nếu terminal nhỏ, thu nhỏ box lại
if (( box_width > term_width )); then
  box_width=$(( ${#text} + 4 ))
fi

# Căn giữa cả khung trong terminal
left_pad=$(( (term_width - box_width) / 2 ))

# Tính padding nội dung trong khung
text_pad=$(( (box_width - 2 - ${#text}) / 2 ))

# Tạo viền trên/dưới
border=$(printf '+%*s+' $((box_width - 2)) '' | tr ' ' '-')

# In kết quả
printf "%*s%s%s\n" "$left_pad" "" "${RED_BOLD}" "$border"
printf "%*s|%*s%s%*s|\n" "$left_pad" "" "$text_pad" "" "$text" "$text_pad" ""
printf "%*s%s%s\n" "$left_pad" "" "$border" "$NC"

#echo "Script By Thanh Quang Nguyen"
echo "Update hệ thống..."
pacman -Sy

#echo "Kiểm tra các phân vùng..."
#lsblk

#1echo "Gắn phân vùng vào /mnt..."
#mount /dev/vda2 /mnt
# Kiểm tra nếu /dev/vda2 đã được mount thì unmount trước
if mount | grep -q "/dev/vda2"; then
    #1echo "ổ đĩa đang được mount, thực hiện umount..."
    umount /dev/vda2
    sleep 2
fi

# Kiểm tra nếu /mnt đang có phân vùng nào mount thì cũng unmount luôn
if mount | grep -q "on /mnt "; then
    #1echo "/mnt đang có phân vùng được gắn, thực hiện umount /mnt..."
    umount /mnt
    sleep 1
fi

# Mount lại /dev/vda2 vào /mnt
sleep 1
mount /dev/vda2 /mnt

sleep 2
cd /mnt
#ls

echo "Vui lòng chọn phiên bản Windows Server để tải:"
echo "1. Windows Server 2012 R2"
echo "2. Windows Server 2016"
echo "3. Windows Server 2019"
echo "4. Windows 10 Lite"
read -p " Nhập lựa chọn (1-4): " choice

# Đường dẫn file TXT chứa danh sách link
LINK_LIST_URL="https://raw.githubusercontent.com/songokumax/winvu/refs/heads/main/linkwin.txt"
echo "Tải danh sách win..."
sleep 3
curl -sSL "$LINK_LIST_URL" -o linklist.txt

echo "Tìm link phù hợp với lựa chọn $choice..."

DOWNLOAD_URL=""
while IFS="|" read -r url ver; do
    if [[ "$ver" == "$choice" ]]; then
        echo -n "Kiểm tra link: $url ... "
        sleep 3
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
sleep 3
wget -O /mnt/windows.img.gz "$DOWNLOAD_URL"

echo "Giải nén file (2-3p)..."
gunzip windows.img.gz

EXTRACTED_IMG=$(ls *.img *.iso 2>/dev/null | head -n 1)
sleep 2
#parted "$EXTRACTED_IMG" print

echo " Ghi image vào ổ đĩa..."
sleep 2
dd if="$EXTRACTED_IMG" of=/dev/vda bs=4M status=progress
sleep 2
echo "Dọn dẹp..."
rm -f "$EXTRACTED_IMG" linklist.txt

cd

#1echo " Tháo gắn kết /mnt..."
umount /dev/vda2

echo "Hoàn tất! Bạn có thể thoát và remove iso."
