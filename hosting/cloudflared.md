# cloudflared ingress + DNS pro nový subweb

1. **Ingress** do `~/.cloudflared/<tunnel>-config.yml` — vlož PŘED `service: http_status:404`:
   ```yaml
     - hostname: SUBDOMAIN.example.eu
       service: http://localhost:PORT
   ```
2. **DNS** (CNAME → tunnel) přes tunnel credentials:
   ```bash
   cloudflared tunnel route dns <TUNNEL_ID> SUBDOMAIN.example.eu
   ```
3. **Restart**: `sudo systemctl restart cloudflared-<name>`

## Pasti
- **Ověřuj přes veřejnou DNS** (`dig @8.8.8.8`), ne tailnet (MagicDNS → falešné OK).
- urllib/Python dostane od Cloudflare **403** (bot UA) — testuj curlem s prohlížečovým UA.
- Pretty permalinky → WP `.htaccess` musí existovat (dev `wp server` ho nemá).
- Cloudflare **Email Obfuscation** (zone) přepíše `mail@x` na `[email protected]` — zónové nastavení.
