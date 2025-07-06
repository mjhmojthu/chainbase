#!/bin/bash

# Màu sắc (tuỳ chọn)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_step() {
  echo -e "\n${BOLD}==> Step $1: $2${NC}\n"
}

check_success() {
  if [ $? -ne 0 ]; then
    echo -e "${RED}✗ An error occurred. Exiting...${NC}"
    exit 1
  fi
}

print_step 1 "Detecting system architecture"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [ "$ARCH" = "x86_64" ]; then
    NGROK_ARCH="amd64"
    echo -e "${GREEN}Detected x86_64 architecture.${NC}"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    NGROK_ARCH="arm64"
    echo -e "${GREEN}Detected ARM64 architecture.${NC}"
elif [[ "$ARCH" == arm* ]]; then
    NGROK_ARCH="arm"
    echo -e "${GREEN}Detected ARM architecture.${NC}"
else
    echo -e "${RED}Unsupported architecture: $ARCH. Please use a supported system.${NC}"
    exit 1
fi

print_step 2 "Downloading and installing ngrok"
echo -e "${YELLOW}Downloading ngrok for $OS-$NGROK_ARCH...${NC}"
wget -q --show-progress "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
check_success

echo -e "${YELLOW}Extracting ngrok...${NC}"
tar -xzf "ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
check_success

echo -e "${YELLOW}Moving ngrok to /usr/local/bin/ (requires sudo)...${NC}"
sudo mv ngrok /usr/local/bin/
check_success

echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm "ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
check_success

print_step 3 "Authenticating ngrok"
while true; do
    echo -e "\n${YELLOW}To get your authtoken:${NC}"
    echo "1. Đăng nhập hoặc tạo tài khoản tại: https://dashboard.ngrok.com"
    echo "2. Lấy token ở mục: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "3. Copy token và dán vào dưới đây"
    echo -e "\n${BOLD}Nhập ngrok authtoken:${NC}"
    read -p "> " NGROK_TOKEN

    if [ -z "$NGROK_TOKEN" ]; then
        echo -e "${RED}Không có token. Vui lòng nhập lại.${NC}"
        continue
    fi

    pkill -f ngrok || true
    sleep 2

    ngrok authtoken "$NGROK_TOKEN"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Đã xác thực ngrok thành công!${NC}"
        break
    else
        echo -e "${RED}✗ Sai token. Vui lòng thử lại.${NC}"
    fi
done

echo -e "\n${GREEN}🎉 Ngrok đã được cài đặt và cấu hình thành công!${NC}"

