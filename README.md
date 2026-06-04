# maj-elementor-ex

Toolkit pro **de-Elementorizaci WordPress webů** — odstranění Elementoru a nahrazení
nativním WP obsahem (Gutenberg `wp:html` / `wp:shortcode` bloky), **vizuálně 1:1**.

Vzniklo při převodu webu *Catley Ranch / dogarna.cz* (UpdraftPlus backup → čistý web bez
Elementoru → zpětný UpdraftPlus balík + veřejný hosting přes cloudflared).

## Kdy to funguje snadno

Většina „Elementor" webů používá Elementor jen jako **tenký obal** kolem pár widgetů.
U Catley Ranch: 17 stránek, jen **3 typy widgetů** — `html` (ručně psané HTML s vlastními
CSS třídami), `shortcode` (custom plugin shortcody), `text-editor`. Žádný Elementor Pro,
žádný Elementor header/footer (to dělá téma). CSS je nezávislé na Elementoru.

→ De-Elementorizace = vytáhnout obsah widgetů z `_elementor_data` do nativního
`post_content` a smazat `_elementor_*` meta. Téma (Astra) renderuje stejně.

**Nejdřív vždy analyzuj** (`tools/analyze-elementor.php`) — pokud web používá hodně
vizuálních Elementor widgetů (heading, image-box, accordion, tabs, …), je to mnohem
větší práce (per-widget → Gutenberg blok mapping) a tento přímý přístup nestačí.

## Postup (ověřený)

1. **Duplikuj web** (nový DB + dir + port) — originál nech jako referenční etalon.
2. **Analýza** — `wp eval-file tools/analyze-elementor.php` → inventář stránek + widgetů.
3. **Extrakce + konverze** — `wp eval-file tools/convert-all.php`:
   - projde `_elementor_data` v pořadí: `html`→`wp:html` blok, `shortcode`→`wp:shortcode`,
     `text-editor`→`wp:html`
   - složí nativní `post_content`, uloží přes `wp_update_post`
   - smaže všechna `_elementor_*` postmeta (→ `the_content()` renderuje nativně)
4. **Odstranění Elementoru** — deaktivuj+smaž plugin, smaž zbylá `_elementor_*` meta
   (revize+kit), `elementor_*` options, `uploads/elementor/` CSS cache.
5. **Ověření parity** — `python3 tools/compare-content.py` porovná viditelný text
   originál vs převedený (cíl ≥97 %; rozdíl = jen dynamický obsah / locale).

## Lekce / pasti

- **Nativní `post_content` ≠ Elementor obsah** — Elementor hijackuje `the_content`
  a renderuje z `_elementor_data`; uložené `post_content` bývá zastaralé. Vždy
  extrahuj z `_elementor_data`.
- **Astra full-width** — Elementor stretchuje sekce na celou šířku. Astra ale aplikuje
  `ast-page-builder-template` i bez Elementoru (stejný full-width) → u Catley Ranch
  nebylo třeba nic ladit. Ověř per web.
- **`custom-css-js` / on-disk CSS cache** — pozadí (`background:url(...)`) bývají
  v `uploads/custom-css-js/*.css` na disku, mimo DB → `wp search-replace` je nechytí,
  sed přímo soubory.
- **Locale** — když nasazuješ jinam, doinstaluj jazyk (`wp language core/theme/plugin
  install cs_CZ`) jako **vlastník souborů** (uid), ne www-data (permission fail).

## Balení zpět do UpdraftPlus (`tools/package-updraft.sh`)

Vyrobí `zasilka-*.zip` s 5 komponentami v UpdraftPlus formátu
(`backup_YYYY-MM-DD-HHMM_<Name>_<nonce>-{db.gz,plugins.zip,themes.zip,uploads.zip,others.zip}`).
- komponenty obsahují `plugins/` `themes/` `uploads/` na rootu
- `db.gz` = mysqldump + UpdraftPlus hlavička, gzip; **`LC_ALL=C sed`** na URL přepis
  (macOS sed jinak padá na UTF-8: „illegal byte sequence")
- restore: import přes UpdraftPlus „Existing Backups" rescan, NEBO manuálně
  (extrakce komponent do `wp-content/` + import db.gz). UpdraftPlus **free nemá
  headless restore** (`perform_restore` vrátí `true` ale stage neprovede) — UI nebo manuál.

## Veřejný hosting za cloudflared (`hosting/`)

WP stack na serveru (`docker-compose.yml`: mariadb + `wordpress:php8.3-apache`,
`./html:/var/www/html`, `apache-override.conf`) + cloudflared ingress
(`hostname → http://localhost:PORT` před 404 catch-all) + `cloudflared tunnel route dns`.
- `wp-config-snippet.php` = HTTPS-za-proxy (X-Forwarded-Proto) + `WP_HOME/WP_SITEURL`
- pretty permalinky vyžadují `.htaccess` (při dev `wp server` neexistuje → doplnit)

## Soubory

```
tools/analyze-elementor.php   inventář Elementor stránek + widget typů
tools/extract-page.php        extrakce 1 stránky (dry-run / --apply)
tools/convert-all.php         hromadná konverze všech stránek + úklid meta
tools/compare-content.py      parita viditelného obsahu (2 URL)
tools/package-updraft.sh      sestavení UpdraftPlus zásilky
hosting/docker-compose.yml    WP stack šablona (sanitizováno)
hosting/apache-override.conf  Apache proxy + AllowOverride
hosting/wp-config-snippet.php HTTPS-za-proxy + WP_HOME
hosting/cloudflared.md        ingress + DNS postup
```

Hesla/tokeny v šablonách jsou placeholdery — doplnit z secret store.
