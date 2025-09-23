#!/bin/bash

show_status() {
    echo
    echo "=== Trạng thái swap hiện tại ==="
    swapon --show || echo "Không có swap nào đang bật."
    free -h
    echo
}

create_swap() {
    if swapon --show | grep -q "/swapfile"; then
        echo "[!] Đã có swapfile đang tồn tại. Bạn có muốn ghi đè không? (y/n)"
        read ans
        if [[ "$ans" != "y" ]]; then
            echo "Huỷ tạo swap mới."
            return
        fi
        sudo swapoff /swapfile
        sudo rm -f /swapfile
        sudo sed -i '/\/swapfile/d' /etc/fstab
    fi

    read -p "Nhập dung lượng swap mới (ví dụ 4, 8G, 4096M): " SWAP_SIZE
    if [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
        SWAP_SIZE="${SWAP_SIZE}G"
    fi

    echo "[*] Tạo swap mới với dung lượng $SWAP_SIZE ..."
    sudo fallocate -l $SWAP_SIZE /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    fi

    show_status
}

delete_swap() {
    if swapon --show | grep -q "/swapfile"; then
        echo "[*] Tắt và xóa swapfile..."
        sudo swapoff /swapfile
        sudo rm -f /swapfile
        sudo sed -i '/\/swapfile/d' /etc/fstab
        echo "Swapfile đã bị xóa."
    else
        echo "Không tìm thấy swapfile để xóa."
    fi
    show_status
}

resize_swap() {
    if ! [ -f /swapfile ]; then
        echo "Chưa có swapfile để resize. Hãy chọn tạo mới trước."
        return
    fi

    read -p "Nhập dung lượng swap mới (ví dụ 4, 8G, 4096M): " NEW_SIZE
    if [[ "$NEW_SIZE" =~ ^[0-9]+$ ]]; then
        NEW_SIZE="${NEW_SIZE}G"
    fi

    echo "[*] Resize swapfile thành $NEW_SIZE ..."
    sudo swapoff /swapfile
    sudo rm -f /swapfile
    sudo fallocate -l $NEW_SIZE /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    fi

    show_status
}

while true; do
    echo "===== Swap Manager ====="
    echo "1) Tạo swap mới"
    echo "2) Xóa swapfile hiện tại"
    echo "3) Resize swapfile"
    echo "4) Xem trạng thái swap"
    echo "5) Thoát"
    read -p "Chọn: " choice

    case $choice in
        1) create_swap ;;
        2) delete_swap ;;
        3) resize_swap ;;
        4) show_status ;;
        5) exit 0 ;;
        *) echo "Lựa chọn không hợp lệ." ;;
    esac
done
