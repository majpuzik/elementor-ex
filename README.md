# elementor-ex

**A toolkit to remove Elementor from a WordPress site and replace it with native
WordPress content** (Gutenberg `wp:html` / `wp:shortcode` blocks) — visually 1:1,
fully deterministic, no AI.

It extracts the content out of Elementor's `_elementor_data`, writes it back into the
native `post_content`, deletes the `_elementor_*` meta, and removes the plugin. The
theme then renders the page exactly as before — just without Elementor.

---

## ⚠️ Read this first — the limitation

**This tool only works well for one specific (but very common) case: sites that use
Elementor as a thin wrapper around hand-written HTML, shortcodes, or rich text.**

It does **not** convert Elementor's *visual widgets* (Heading, Image Box, Accordion,
Tabs, Icon List, Testimonials, Posts grid, Forms, etc.) into equivalent Gutenberg
blocks. Those widgets have no source HTML — Elementor generates their markup at render
time from widget settings. Re-creating that as native blocks is a per-widget mapping
problem and is exactly why **no reliable automatic Elementor→Gutenberg converter
exists** (every migration guide says the same: *"there is no automated converter — it's
actually rebuilding the site"*).

### Decide in 30 seconds — run the analyzer

```bash
wp eval-file tools/analyze-elementor.php
```

It prints every Elementor page and a histogram of the widget *types* used site-wide.

| Widget types you see | Verdict |
|---|---|
| Mostly `html`, `shortcode`, `text-editor` | ✅ **Great fit.** Content is already real code — extraction is mechanical and exact. |
| A few visual widgets mixed in | ⚠️ Partial. Those widgets will come over as empty/placeholder; convert them by hand. |
| Mostly visual widgets (`heading`, `image-box`, `accordion`, …) | ❌ **Not a fit.** This is a manual rebuild — no tool (this one included) does it reliably. |

Real example this was built on: 17 Elementor pages, **only 3 widget types** —
`html` ×12, `shortcode` ×4, `text-editor` ×1. No Elementor Pro, no Elementor
header/footer (the theme did those), CSS independent of Elementor. → mechanical 1:1
conversion, 97–99% text parity against the live site, **zero** Elementor left.

### Other things it does NOT do

- It does not migrate Elementor **theme-builder** headers/footers/templates (Pro). If
  your header/footer is built in Elementor, you must rebuild those in the theme first.
- It does not compare **visual/CSS** layout — parity check is text-only (`difflib`).
  Pure-CSS differences won't be caught. (A vision-model screenshot diff would; not
  included.)
- It assumes the page's CSS comes from the theme / a `custom-css-js`-style plugin /
  the custom plugins — i.e. **not** from Elementor's own widget CSS. Verify this, or
  the styling will break when Elementor's stylesheet stops loading.

---

## Why deterministic (no AI) is the right call here

For the thin-wrapper case the content is already hand-written HTML and shortcodes, so
extraction is a tree walk — **exact, repeatable, no hallucination risk.** An LLM would
only help for the *visual-widget* case (mapping widget+settings → block markup) or for
true pixel parity (a vision model diffing before/after screenshots). For this class of
site, AI adds nothing.

---

## Method (the proven workflow)

1. **Duplicate the site** (new DB + dir + port). Keep the original running as the
   visual reference.
2. **Analyze** — `tools/analyze-elementor.php` → decide fit (see table above).
3. **Convert** — `tools/convert-all.php` (via `wp eval-file`):
   - walks `_elementor_data` in order: `html`→`wp:html` block, `shortcode`→`wp:shortcode`,
     `text-editor`→`wp:html`
   - builds native `post_content`, saves with `wp_update_post`
   - deletes all `_elementor_*` postmeta → `the_content()` now renders natively
4. **Remove Elementor** — deactivate + delete the plugin, delete leftover `_elementor_*`
   meta (revisions + kit), `elementor_*` options, and the `uploads/elementor/` CSS cache.
5. **Verify parity** — `tools/compare-content.py <url-original> <url-converted>`
   (target ≥97% visible-text similarity; the rest is dynamic content / locale).

### Gotchas learned the hard way

- **Native `post_content` ≠ Elementor content.** Elementor hijacks `the_content` and
  renders from `_elementor_data`; the stored `post_content` is usually stale. Always
  extract from `_elementor_data` — and **do not** trust Elementor's "Back to WordPress
  Editor", which reverts to that stale/empty `post_content`.
- **Full-width.** Elementor stretches sections edge-to-edge. Check that your theme still
  renders full-width after removal (Astra applies `ast-page-builder-template` either
  way, so it needed no fix here — verify per theme).
- **On-disk CSS cache.** Background images (`background:url(...)`) often live in
  `uploads/custom-css-js/*.css` on disk, outside the DB — `wp search-replace` won't
  touch them; `sed` the files directly when changing domains.
- **macOS `sed` + UTF-8.** Use `LC_ALL=C sed` for URL rewrites in SQL dumps, or it dies
  with *"illegal byte sequence"* on diacritics (silently truncating the dump).

---

## Packaging back into an UpdraftPlus backup

`tools/package-updraft.sh` rebuilds an UpdraftPlus-format archive
(`backup_<DATE>_<Name>_<nonce>-{db.gz,plugins.zip,themes.zip,uploads.zip,others.zip}`,
wrapped in one zip). Component zips keep `plugins/ themes/ uploads/` at their root; the
`db.gz` is a `mysqldump` + an UpdraftPlus header.

> Note: UpdraftPlus **Free has no headless restore** (`perform_restore()` returns `true`
> but runs no stage). Restore via the UpdraftPlus UI ("Existing Backups" → rescan), or
> manually (extract components into `wp-content/`, import `db.gz`).

Verify any backup with: `unzip -t zasilka.zip` and `gzcat *-db.gz | grep -c 'CREATE TABLE'`.

## Optional: public hosting behind a Cloudflare tunnel

`hosting/` contains a sanitized stack template (MariaDB + `wordpress:php8.3-apache`,
`./html:/var/www/html`, an Apache reverse-proxy override), a `wp-config` HTTPS-behind-proxy
snippet, and the cloudflared ingress + DNS recipe. All passwords are placeholders.

---

## Files

```
tools/analyze-elementor.php   inventory of Elementor pages + widget-type histogram
tools/extract-page.php        extract one page (dry-run / --apply)
tools/convert-all.php         bulk-convert every page + clean up meta
tools/compare-content.py      visible-content parity of two URLs
tools/package-updraft.sh      build an UpdraftPlus-format archive
hosting/docker-compose.yml    WP stack template (sanitized)
hosting/apache-override.conf  Apache reverse-proxy + AllowOverride
hosting/wp-config-snippet.php HTTPS-behind-proxy + WP_HOME
hosting/cloudflared.md        ingress + DNS recipe
```

## Requirements

WP-CLI, PHP 7.4+, MySQL/MariaDB, `zip`/`gzip`. Python 3 for the parity check.

## License

MIT. Use at your own risk — **always work on a copy and keep the original**, and run
the parity check before trusting the result.
