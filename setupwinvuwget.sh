#!/bin/bash

set -e

echo "Kiểm tra các phân vùng..."
lsblk

parted --script /dev/vda mklabel gpt

# Tạo một phân vùng duy nhất chiếm toàn bộ dung lượng
parted --script /dev/vda mkpart primary ext4 0% 100%

# Đợi hệ thống cập nhật thiết bị mới
sleep 2

# Format phân vùng vừa tạo (thường là /dev/vda1)
mkfs.ext4 -F /dev/vda1

# Mount phân vùng vào /mnt
mount /dev/vda1 /mnt

echo "Update hệ thống..."
pacman -Sy

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
#wget -q "$LINK_LIST_URL" -O linklist.txt
# Tải danh sách link với vòng lặp kiểm tra nếu tải không thành công
MAX_RETRIES=5  # Số lần thử lại tối đa
RETRY_COUNT=0  # Biến đếm số lần thử lại

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    
    # Sử dụng wget với kiểm tra trạng thái
    wget -q --tries=1 "$LINK_LIST_URL" -O linklist.txt
    
    # Kiểm tra mã trạng thái exit của wget
    if [[ $? -eq 0 ]]; then
        echo "Tải file thành công!"
        break
    else
        echo "Tải file thất bại, thử lại lần $((RETRY_COUNT+1))/$MAX_RETRIES..."
        ((RETRY_COUNT++))
        sleep 5  # Nghỉ 5 giây trước khi thử lại
    fi
done

# Kiểm tra nếu tải không thành công sau MAX_RETRIES lần
if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    echo "Tải file thất bại sau $MAX_RETRIES lần thử. Dừng script."
    exit 1
fi

echo "Tìm link phù hợp với lựa chọn $choice..."

DOWNLOAD_URL=""
while IFS="|" read -r url ver; do
    if [[ "$ver" == "$choice" ]]; then
        echo -n "Kiểm tra link: $url ... "
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
umount /dev/vda1

echo "Hoàn tất! Bạn có thể khởi động lại máy."
