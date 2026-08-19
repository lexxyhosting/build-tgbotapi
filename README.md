# Telegram Bot API + Cloudflare Tunnel (VPS)

## Requirements
- Fresh Ubuntu 20.04/22.04/24.04 VPS
- Root access
- Domain `api.lexbuilder.biz.id` configured in Cloudflare

## Setup (One Command)

```bash
# Download and run setup
curl -fsSL https://raw.githubusercontent.com/lexxyhosting/build-tgbotapi/main/setup-vps.sh -o setup.sh && sudo bash setup.sh
```

Or manually:
```bash
# Upload setup-vps.sh to VPS
scp setup-vps.sh root@YOUR_VPS_IP:/root/

# SSH into VPS and run
ssh root@YOUR_VPS_IP
chmod +x setup.sh
sudo bash setup.sh
```

## After Setup

```bash
# Check status
systemctl status tgbotapi

# View logs
journalctl -u tgbotapi -f

# Restart
systemctl restart tgbotapi

# Stop
systemctl stop tgbotapi
```

## Test

```bash
# Check tunnel connection
tail -f /opt/tgbotapi/logs/cloudflared.log

# Check Bot API server
curl http://localhost:8081
```

## Files

```
/opt/tgbotapi/
├── .env                    # Config
├── start.sh                # Start script
├── tgbotapi/
│   └── telegram-bot-api    # Binary
├── data/
│   └── tgfiles/            # Telegram file cache
└── logs/
    ├── tba.log             # Bot API logs
    └── cloudflared.log     # Tunnel logs
```

## Troubleshooting

**Tunnel not connecting:**
```bash
tail -f /opt/tgbotapi/logs/cloudflared.log
```

**Bot API not starting:**
```bash
tail -f /opt/tgbotapi/logs/tba.log
```

**Permission denied:**
```bash
chmod +x /opt/tgbotapi/start.sh
chmod +x /opt/tgbotapi/tgbotapi/telegram-bot-api
```
