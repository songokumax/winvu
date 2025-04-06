#!/bin/bash

set -e  # Dừng script nếu có lỗi

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
read -p " Nhập lựa chọn (1-3): " choice

case "$choice" in
  1)
    echo "Đang tải Windows Server 2012 R2..."
    wget -O /mnt/windows.gz "http://178.128.56.228/filewin/WindowsServer2012eximg.gz"
    ;;
  2)
    echo "Đang tải Windows Server 2016..."
    wget -O /mnt/windows.gz "https://dl.dropboxusercontent.com/scl/fi/ph9qm3ksedpx1bpxiqpi2/WindowsServer2016img.gz?rlkey=0pqm4qv0ryct4ukaspt4khwhq&st=lssf67qb"
    ;;
  3)
    echo "Đang tải Windows Server 2019..."
    wget -O /mnt/windows.gz "http://178.128.56.228/filewin/WindowsServer2019img.gz"
    ;;
  *)
    echo "Lựa chọn không hợp lệ. Vui lòng chạy lại script và chọn 1, 2 hoặc 3."
    exit 1
    ;;
esac

echo "Cài đặt p7zip..."
yes | pacman -Sy p7zip

echo "Giải nén file..."
7z x windows.gz

# Lấy tên file ISO/IMG sau khi giải nén (giả sử chỉ có 1 file)
EXTRACTED_IMG=$(ls *.img *.iso 2>/dev/null | head -n 1)

echo "Kiểm tra và sửa GPT trong image nếu cần..."
echo -e "v\nw\n" | gdisk "$EXTRACTED_IMG" || true

echo " Ghi image vào /dev/vda..."
dd if="$EXTRACTED_IMG" of=/dev/vda bs=4M status=progress

echo "Dọn dẹp..."
rm -f windows.gz

cd

echo " Tháo gắn kết /mnt..."
umount /dev/vda2

echo "Hoàn tất! Bạn có thể khởi động lại máy."
