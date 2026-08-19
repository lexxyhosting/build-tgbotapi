#!/bin/bash
# =============================================
#  Setup Telegram Bot API + Cloudflare Tunnel
#  Run on fresh Ubuntu/Debian VPS
# =============================================

set -e

echo "============================================="
echo "  Telegram Bot API + Cloudflare Tunnel Setup"
echo "============================================="
echo ""

# ===== Config =====
TBA_API_ID="37872006"
TBA_API_HASH="779634536e27c92f94c97e0c3c6130ae"
TBA_PORT="8081"
CLOUDFLARE_TOKEN="eyJhIjoiNDQ4NTNkNTEzZDQ5MjhlZmE4YWZiM2VlMmRhZTljMmQiLCJ0IjoiNjkyYTQ2NGItMzM3MS00ZGJjLWIzYjQtNDk4ZGJkNmQyNTRmIiwicyI6IlptRTBOVGhoTWpVdFlUUmlOeTAwT0dRNUxXSm1aakl0TTJabU9UZzFabVpoTURKbSJ9"

WORK_DIR="/opt/tgbotapi"
TBA_DIR="$WORK_DIR/tgbotapi"
TBA_BIN="$TBA_DIR/telegram-bot-api"
CF_BIN="/usr/local/bin/cloudflared"

# ===== Install dependencies =====
echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq build-essential cmake g++ git libssl-dev zlib1g-dev curl gperf

# ===== Install cloudflared =====
echo ""
echo "[2/5] Installing cloudflared..."
if command -v cloudflared &> /dev/null; then
    echo "  -> Already installed"
    CF_BIN="cloudflared"
else
    ARCH=$(uname -m)
    CF_ARCH="amd64"
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        CF_ARCH="arm64"
    fi
    
    echo "  -> Downloading..."
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH" -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo "  -> OK"
fi

# ===== Build Telegram Bot API Server =====
echo ""
echo "[3/5] Installing Telegram Bot API Server..."
if [ -f "$TBA_BIN" ]; then
    echo "  -> Already installed"
else
    echo "  -> Cloning repo..."
    cd /tmp
    rm -rf telegram-bot-api
    git clone --depth 1 --recursive https://github.com/tdlib/telegram-bot-api.git
    
    cd telegram-bot-api
    mkdir -p build
    cd build
    
    echo "  -> Configuring..."
    cmake -DCMAKE_BUILD_TYPE=Release .. -DCMAKE_INSTALL_PREFIX=/usr/local
    
    echo "  -> Compiling (may take 10-15 min)..."
    make -j$(nproc)
    
    mkdir -p "$TBA_DIR"
    cp telegram-bot-api "$TBA_BIN"
    chmod +x "$TBA_BIN"
    
    # Cleanup
    cd /
    rm -rf /tmp/telegram-bot-api
    
    echo "  -> OK"
fi

# ===== Create .env =====
echo ""
echo "[4/5] Creating config..."
mkdir -p "$WORK_DIR/data/tgfiles"
mkdir -p "$WORK_DIR/logs"

cat > "$WORK_DIR/.env" << EOF
# Telegram Bot API Server
TBA_API_ID=$TBA_API_ID
TBA_API_HASH=$TBA_API_HASH
BOT_API_PORT=$TBA_PORT

# Cloudflare Tunnel
CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TOKEN
EOF

# ===== Create start script =====
cat > "$WORK_DIR/start.sh" << 'STARTEOF'
#!/bin/bash
cd /opt/tgbotapi

source .env

echo "Starting Telegram Bot API Server on port $BOT_API_PORT..."
./tgbotapi/telegram-bot-api \
    --api-id=$TBA_API_ID \
    --api-hash=$TBA_API_HASH \
    --http-port=$BOT_API_PORT \
    --dir=/opt/tgbotapi/data/tgfiles \
    --verbosity=1 \
    >> /opt/tgbotapi/logs/tba.log 2>&1 &
TBA_PID=$!
echo "  -> PID: $TBA_PID"

sleep 2

echo "Starting Cloudflare Tunnel..."
cloudflared tunnel --no-autoupdate run --token $CLOUDFLARE_TUNNEL_TOKEN >> logs/cloudflared.log 2>&1 &
CF_PID=$!
echo "  -> PID: $CF_PID"

echo ""
echo "============================================="
echo "  All done!"
echo "============================================="
echo ""
echo "  Local:  http://localhost:$BOT_API_PORT"
echo "  Public: https://api.lexbuilder.biz.id"
echo ""
echo "  Logs:"
echo "    tail -f /opt/tgbotapi/logs/tba.log"
echo "    tail -f /opt/tgbotapi/logs/cloudflared.log"
echo ""
echo "  Stop: kill $TBA_PID $CF_PID"
echo ""

wait
STARTEOF
chmod +x "$WORK_DIR/start.sh"

# ===== Create systemd service =====
echo ""
echo "[5/5] Creating systemd service..."
cat > /etc/systemd/system/tgbotapi.service << EOF
[Unit]
Description=Telegram Bot API + Cloudflare Tunnel
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/start.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tgbotapi
systemctl start tgbotapi

echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
echo "  Service: systemctl status tgbotapi"
echo "  Logs:    journalctl -u tgbotapi -f"
echo "  Stop:    systemctl stop tgbotapi"
echo ""
echo "  Public URL: https://api.lexbuilder.biz.id"
echo ""
