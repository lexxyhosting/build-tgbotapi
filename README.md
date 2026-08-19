# Telegram Bot API + Cloudflare Tunnel (VPS)

## VPS Kadaluarsa / Baru? Jalankan 1 Ini

```bash
curl -fsSL https://raw.githubusercontent.com/lexxyhosting/build-tgbotapi/main/setup-vps.sh | sudo bash
```

Selesai. Tunnel + Bot API langsung aktif.

## Status

```bash
systemctl status tgbotapi
```

## Restart

```bash
systemctl restart tgbotapi
```

## Stop

```bash
systemctl stop tgbotapi
```

## Logs

```bash
journalctl -u tgbotapi -f
```

## Public URL

```
https://api.lexbuilder.biz.id
```
