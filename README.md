# elementor-ex

**A toolkit to remove Elementor from a WordPress site and replace it with native
WordPress content** (Gutenberg `wp:html` / `wp:shortcode` blocks) — **text-exact and
fully deterministic, no AI**. The *content* comes over 1:1; **visual** parity is not
automatic and must be verified — Elementor's container layout (section/column
`max-width` + padding) is CSS the converter can't see, and losing it shifts boxed
content to full-width. Run `tools/visual-diff.js` and read **“Container layout is
lost”** below. (Earlier this README said “visually 1:1” — that was optimistic: a real
conversion regressed the homepage hero to full-width until one CSS rule restored the
lost `max-width:1140px`.)

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
- `compare-content.py` checks **text only** (`difflib`) — it won't catch pure CSS/layout
  differences. For those, use **`tools/visual-diff.js`** (now included): a Playwright
  screenshot pixel-diff + computed-token table that surfaces exactly the container/colour
  regressions text parity misses.
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
5. **Verify text parity** — `tools/compare-content.py <url-original> <url-converted>`
   (target ≥97% visible-text similarity; the rest is dynamic content / locale).
6. **Verify visual parity** — `node tools/visual-diff.js <url-original> <url-converted> <paths…>`.
   Read the per-band diff and the “section widths” line; fix any lost container widths
   (see *Container layout is lost*). Text parity passing does **not** imply visual parity.

### Gotchas learned the hard way

- **Native `post_content` ≠ Elementor content.** Elementor hijacks `the_content` and
  renders from `_elementor_data`; the stored `post_content` is usually stale. Always
  extract from `_elementor_data` — and **do not** trust Elementor's "Back to WordPress
  Editor", which reverts to that stale/empty `post_content`.
- **Container layout is lost (the one that bites even thin-wrapper sites).** Elementor
  doesn't just stretch sections edge-to-edge — its containers also *constrain* width and
  add padding. A hand-written HTML block sitting inside an Elementor container inherits
  that container's `.e-con-inner{max-width:min(100%,1140px)}` (and section padding).
  Strip Elementor and that wrapper is gone: the block, whose own CSS never set a width,
  expands to full viewport width. The content is byte-identical — it's just no longer
  boxed. Real case here: the homepage hero went **1140px → 1440px**, scaling its
  background photo differently; pixel-diff 11.5% → 5% once fixed.
  - **Detect:** `tools/visual-diff.js` — compare “section widths orig vs conv”; a width
    that grew = a lost container constraint.
  - **Fix:** re-add the constraint in the theme / `custom-css-js` CSS, e.g.
    `body.home .my-hero{max-width:1140px;margin-inline:auto}`. **Often needs
    `!important`** — Astra/resets set `max-width:none` on `section` with equal-or-higher
    specificity, so a plain rule is silently overridden (verify with
    `getComputedStyle().maxWidth`, not just “the rule is in the stylesheet”).
  - Conversely, sections that were meant to be full-bleed must stay full-width — Astra's
    `ast-page-builder-template` usually keeps that; verify per theme. Don't fix this with
    a blanket `max-width` on the content wrapper: full-bleed dark bands then shrink and
    the diff gets *worse* (measured).

### Reproducing the layout — two paths (tested on a real 17-page site)

What we found by spinning the source up with Elementor + wp-cli and inspecting:
the containers had **no custom layout settings** (`settings` was `{}`) and there was
**no active kit**, so Elementor emitted **zero per-post CSS** — the boxing came purely
from its `frontend.css` default `.e-con-inner{max-width:1140px}`. So there's nothing
page-specific to "keep"; the gap is just that one default rule.

- **`tools/convert-layout.php` — reproduce the boxing (clean, ~95–98%).** Same clean
  extraction as `convert-all.php`, but wraps each top-level Elementor container in
  `<div class="exl-con exl-boxed|exl-full">` and writes `mu-plugins/exl-layout.css`
  (+ enqueue) reproducing only the boxed/full width (from the kit's `container_width`,
  else the 1140 default). Deterministic, no AI, stays clean. **Caveat:** if the content
  already self-boxes (its own `.section/.container` CSS), this wrapper is redundant and
  can fight full-bleed bands — `convert-all.php` + a targeted fix for the one element
  that broke is then better. **Always confirm with `visual-diff.js`.**
- **`tools/freeze-all.php` — keep Elementor's own render + CSS (measured 96.7%).** A
  clean reimplementation can't be byte-for-byte; only keeping Elementor's *own* output
  is. This captures each page's rendered HTML (`get_builder_content_for_display`, with
  dynamic shortcodes re-tokenized so litter grids stay live), preserves Elementor's CSS
  (`frontend.min.css` + the per-post `uploads/elementor/css/post-*.css` + kit CSS) into
  an mu-plugin that enqueues it, then you remove the plugin.
  - **Tested per-page on the real source** (13 pages, frozen vs the live Elementor
    render, AA-insensitive pixel diff): **98.4% average, range 94.4–100%** (`vrhy` hit
    100.0%; the lowest, the long photo-heavy `o-nás`, 94.4%). The residual is photo
    edges + sub-pixel font AA — visually identical, and the photo-heavy pages score a
    touch lower for that reason, not because of layout. With *only* `frontend.min.css`
    (skipping the per-post CSS) the homepage was **87%** — the per-page `post-*.css` is
    what carries the per-element layout, don't skip it.
  - **Order gotcha (measured):** deleting `_elementor_data` makes Elementor delete its
    own `post-*.css`. So `freeze-all.php` regenerates + copies the CSS **first**, then
    captures HTML, then deletes the meta. Doing it the other way silently loses the CSS.
  - Trade-off: markup keeps `elementor-*` classes and the CSS is Elementor's (verbose).
    This is the path to use when literal parity is what's required.

Bottom line on “100%”: colour/typography/content come over exactly; **literal pixel
parity is a freeze, not a conversion** — two render engines differ at the sub-pixel
(font AA, image scaling) regardless. Aim for *visually indistinguishable*, verify with
`visual-diff.js`, and don't claim 1:1 you didn't measure.
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
tools/convert-all.php         bulk-convert every page + clean up meta (content only)
tools/convert-layout.php      bulk-convert + reproduce container boxing (exl-layout.css)
tools/freeze-all.php          keep Elementor's render + CSS = literal pixel parity (~97%)
tools/compare-content.py      visible-content (text) parity of two URLs
tools/visual-diff.js          pixel + computed-CSS-token parity (catches layout/colour)
tools/package-updraft.sh      build an UpdraftPlus-format archive
hosting/docker-compose.yml    WP stack template (sanitized)
hosting/apache-override.conf  Apache reverse-proxy + AllowOverride
hosting/wp-config-snippet.php HTTPS-behind-proxy + WP_HOME
hosting/cloudflared.md        ingress + DNS recipe
```

See **PLAYBOOK.md** for the tabular how-to (decide fit → pick clean/freeze → workflow → measured gotchas).

## Requirements

WP-CLI, PHP 7.4+, MySQL/MariaDB, `zip`/`gzip`. Python 3 for the text parity check.
Node 18+ with `playwright pixelmatch pngjs` (`npx playwright install chromium`) for
the visual parity check.

## License

MIT. Use at your own risk — **always work on a copy and keep the original**, and run
the parity check before trusting the result.
