#!/bin/bash

cd /root/rl-swarm

echo "[$(date)] Starting process..."

# Copy file login TRƯỚC
sleep 5
echo "[$(date)] Copying login files..."
cp -r /root/rl-swarm-bk/user/modal-login/* /root/rl-swarm/user/modal-login/

# Tạo named pipe
mkfifo /tmp/gensyn_pipe 2>/dev/null || true

# Background process - CHỈ gửi input
(
    sleep 10
    echo "N"
    sleep 3
    echo ""
    sleep 3
    echo "n"
) > /tmp/gensyn_pipe &

# Chạy docker compose
echo "[$(date)] Starting docker compose..."
docker compose run --rm --build swarm-cpu < /tmp/gensyn_pipe

# Cleanup
wait
rm -f /tmp/gensyn_pipe
echo "[$(date)] Container stopped"
