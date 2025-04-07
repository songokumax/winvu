#!/bin/bash

set -e  # Dừng script nếu có lỗi

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
read -p " Nhập lựa chọn (1-3): " choice

case "$choice" in
  1)
    echo "Đang tải Windows Server 2012 R2..."
    wget -O /mnt/windows.gz "http://178.128.56.228/filewin/WindowsServer2012eximg.gz"
    ;;
  2)
    echo "Đang tải Windows Server 2016..."
    wget -O /mnt/windows.gz "http://157.245.59.126:8080/filewin/WindowsServer2016img.gz"
    ;;
  3)
    echo "Đang tải Windows Server 2019..."
    wget -O /mnt/windows.gz "http://178.128.56.228/filewin/WindowsServer2019img.gz"
    ;;
  4)
    echo "Đang tải Windows 10 lite..."
    wget -O /mnt/windows.gz "http://157.245.59.126:8080/filewin/Windows10lite.gz"
    ;;
  *)
    echo "Lựa chọn không hợp lệ. Vui lòng chạy lại script và chọn 1, 2, 3 hoặc 4."
    exit 1
    ;;
esac

echo "Cài đặt p7zip..."
yes | pacman -Sy p7zip

echo "Giải nén file..."
7z x windows.gz

# Lấy tên file ISO/IMG sau khi giải nén (giả sử chỉ có 1 file)
EXTRACTED_IMG=$(ls *.img *.iso 2>/dev/null | head -n 1)

parted "$EXTRACTED_IMG" print

#echo "Kiểm tra và sửa GPT trong image nếu cần..."
#echo -e "v\nw\ny\n" | gdisk "$EXTRACTED_IMG" || true

#parted "$EXTRACTED_IMG" print

echo " Ghi image vào /dev/vda..."
dd if="$EXTRACTED_IMG" of=/dev/vda bs=4M status=progress

echo "Dọn dẹp..."
rm -f windows.gz

cd

echo " Tháo gắn kết /mnt..."
umount /dev/vda2

echo "Hoàn tất! Bạn có thể khởi động lại máy."
