# Telegram Bot API + Cloudflare Tunnel + File Server (VPS)

## VPS Kadaluarsa / Baru? Jalankan 1 Ini

```bash
curl -fsSL https://raw.githubusercontent.com/lexxyhosting/build-tgbotapi/main/setup-vps.sh | sudo bash
```

Selesai. Tunnel + Bot API + File Server langsung aktif.

## DNS Record (Cloudflare)

Tambah record ini di Cloudflare Dashboard:

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `api` | `692a464b-3371-4dbc-b3b4-498dbd6d254f.cfargotunnel.com` | Proxied ✅ |
| CNAME | `file` | `692a464b-3371-4dbc-b3b4-498dbd6d254f.cfargotunnel.com` | Proxied ✅ |

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

## Public URLs

```
https://api.lexbuilder.biz.id   (Bot API)
https://file.lexbuilder.biz.id  (File Server)
```
