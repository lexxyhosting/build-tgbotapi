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
FILE_SERVER_DIR="/opt/fileserver"
TBA_DIR="$WORK_DIR/tgbotapi"
TBA_BIN="$TBA_DIR/telegram-bot-api"
CF_BIN="/usr/local/bin/cloudflared"

# ===== Install dependencies =====
echo "[1/8] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq build-essential cmake g++ git libssl-dev zlib1g-dev curl gperf

# ===== Install cloudflared =====
echo ""
echo "[2/8] Installing cloudflared..."
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
echo "[3/8] Installing Telegram Bot API Server..."
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

# ===== Install Node.js for File Server =====
echo ""
echo "[4/8] Installing Node.js..."
if command -v node &> /dev/null; then
    echo "  -> Already installed"
else
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs
    echo "  -> OK"
fi

# ===== Create File Server =====
echo ""
echo "[5/8] Creating file server..."
mkdir -p "$FILE_SERVER_DIR"

cat > "$FILE_SERVER_DIR/server.js" << 'FILEEOF'
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const PORT = 8082;
const FILES_DIR = '/opt/tgbotapi/data/tgfiles';
const AUTH_TOKEN = 'bot-file-server-secret-2024';

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ ok: true }));
  }

  const auth = req.headers.authorization;
  if (auth !== `Bearer ${AUTH_TOKEN}`) {
    res.writeHead(401);
    return res.end('Unauthorized');
  }

  const filePath = path.join(FILES_DIR, url.pathname);

  if (!filePath.startsWith(FILES_DIR)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }

  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404);
      return res.end('Not found');
    }

    res.writeHead(200, {
      'Content-Type': 'application/octet-stream',
      'Content-Length': stat.size,
    });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`File server running on port ${PORT}`);
  console.log(`Serving: ${FILES_DIR}`);
});
FILEEOF

chmod +x "$FILE_SERVER_DIR/server.js"
echo "  -> OK"

# ===== Create .env =====
echo ""
echo "[6/8] Creating config..."
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
    --local \
    --dir=/opt/tgbotapi/data/tgfiles \
    --verbosity=1 \
    >> /opt/tgbotapi/logs/tba.log 2>&1 &
TBA_PID=$!
echo "  -> PID: $TBA_PID"

sleep 2

echo "Starting File Server on port 8082..."
/usr/bin/node /opt/fileserver/server.js >> /opt/tgbotapi/logs/fileserver.log 2>&1 &
FS_PID=$!
echo "  -> PID: $FS_PID"

sleep 1

echo "Starting Cloudflare Tunnel..."
cloudflared tunnel --no-autoupdate run --token $CLOUDFLARE_TUNNEL_TOKEN >> logs/cloudflared.log 2>&1 &
CF_PID=$!
echo "  -> PID: $CF_PID"

echo ""
echo "============================================="
echo "  All done!"
echo "============================================="
echo ""
echo "  Telegram Bot API: http://localhost:$BOT_API_PORT"
echo "  File Server:      http://localhost:8082"
echo ""
echo "  Public:"
echo "    https://api.lexbuilder.biz.id   (Bot API)"
echo "    https://file.lexbuilder.biz.id  (File Server)"
echo ""
echo "  Logs:"
echo "    tail -f /opt/tgbotapi/logs/tba.log"
echo "    tail -f /opt/tgbotapi/logs/fileserver.log"
echo "    tail -f /opt/tgbotapi/logs/cloudflared.log"
echo ""
echo "  Stop: kill $TBA_PID $FS_PID $CF_PID"
echo ""

wait
STARTEOF
chmod +x "$WORK_DIR/start.sh"

# ===== Create systemd service =====
echo ""
echo "[7/8] Creating systemd service..."
cat > /etc/systemd/system/tgbotapi.service << EOF
[Unit]
Description=Telegram Bot API + File Server + Cloudflare Tunnel
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
echo "[8/8] Done!"
echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
echo "  Service: systemctl status tgbotapi"
echo "  Logs:    journalctl -u tgbotapi -f"
echo "  Stop:    systemctl stop tgbotapi"
echo ""
echo "  Public URLs:"
echo "    https://api.lexbuilder.biz.id   (Bot API)"
echo "    https://file.lexbuilder.biz.id  (File Server)"
echo ""
echo "  IMPORTANT: Add this DNS record in Cloudflare:"
echo "    Type: CNAME"
echo "    Name: file"
echo "    Target: 692a464b-3371-4dbc-b3b4-498dbd6d254f.cfargotunnel.com"
echo "    Proxy: Enabled"
echo ""
