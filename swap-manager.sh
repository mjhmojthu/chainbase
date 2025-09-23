#!/bin/bash

# Hàm tìm swap file hiện tại
detect_swapfile() {
    SWAPFILE=$(swapon --show=NAME | grep -E '^/' | head -n1)
}

show_status() {
    echo
    echo "=== Trạng thái swap hiện tại ==="
    swapon --show || echo "Không có swap nào đang bật."
    free -h
    echo
}

create_swap() {
    detect_swapfile
    if [ -n "$SWAPFILE" ]; then
        echo "[!] Đã có swapfile ($SWAPFILE) đang tồn tại. Bạn có muốn ghi đè không? (y/n)"
        read ans
        if [[ "$ans" != "y" ]]; then
            echo "Huỷ tạo swap mới."
            return
        fi
        sudo swapoff "$SWAPFILE"
        sudo rm -f "$SWAPFILE"
        sudo sed -i "\|$SWAPFILE|d" /etc/fstab
    fi

    read -p "Nhập dung lượng swap mới (ví dụ 4, 8G, 4096M): " SWAP_SIZE
    if [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
        SWAP_SIZE="${SWAP_SIZE}G"
    fi

    SWAPFILE="/swapfile"
    echo "[*] Tạo swap mới với dung lượng $SWAP_SIZE tại $SWAPFILE ..."
    sudo fallocate -l $SWAP_SIZE $SWAPFILE
    sudo chmod 600 $SWAPFILE
    sudo mkswap $SWAPFILE
    sudo swapon $SWAPFILE

    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
    fi

    show_status
}

delete_swap() {
    detect_swapfile
    if [ -n "$SWAPFILE" ]; then
        echo "[*] Tắt và xóa $SWAPFILE..."
        sudo swapoff "$SWAPFILE"
        sudo rm -f "$SWAPFILE"
        sudo sed -i "\|$SWAPFILE|d" /etc/fstab
        echo "Đã xoá swapfile: $SWAPFILE"
    else
        echo "Không tìm thấy swapfile để xóa."
    fi
    show_status
}

resize_swap() {
    detect_swapfile
    if [ -z "$SWAPFILE" ]; then
        echo "Chưa có swapfile để resize. Hãy chọn tạo mới trước."
        return
    fi

    OLD_SIZE=$(swapon --show=SIZE | tail -n1)
    read -p "Nhập dung lượng swap mới (ví dụ 4, 8G, 4096M): " NEW_SIZE
    if [[ "$NEW_SIZE" =~ ^[0-9]+$ ]]; then
        NEW_SIZE="${NEW_SIZE}G"
    fi

    echo "[*] Resize $SWAPFILE từ $OLD_SIZE thành $NEW_SIZE ..."
    sudo swapoff "$SWAPFILE"
    sudo rm -f "$SWAPFILE"
    sudo fallocate -l $NEW_SIZE "$SWAPFILE"
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
    sudo swapon "$SWAPFILE"

    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
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
