#!/bin/bash
# Sestaví UpdraftPlus-kompatibilní zásilku z běžícího WP webu.
# Výstup: zasilka-<NAME>-<DATE>.zip s 5 komponentami v UpdraftPlus formátu.
#
# Použití: package-updraft.sh <WP_CONTENT_DIR> <DB_NAME> <SITE_NAME> <TARGET_URL> <OUT_DIR>
#   WP_CONTENT_DIR  cesta k wp-content (obsahuje plugins/ themes/ uploads/)
#   DB_NAME         MySQL databáze webu
#   SITE_NAME       label do názvu (např. Catley_Ranch)
#   TARGET_URL      URL pro DB (např. https://www.dogarna.cz) — search-replace lokálních URL
#   OUT_DIR         kam uložit zásilku
set -euo pipefail

WPC="$1"; DB="$2"; NAME="$3"; URL="$4"; OUT="$5"
TS=$(date +%Y-%m-%d-%H%M)
NONCE=$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c12)
B="backup_${TS}_${NAME}_${NONCE}"
TMP=$(mktemp -d)

echo "[1/6] db.gz (mysqldump + UpdraftPlus hlavička, URL → $URL)"
# POZOR: LC_ALL=C — macOS sed jinak padá na UTF-8 (illegal byte sequence)
mysqldump -u root --single-transaction --no-tablespaces --default-character-set=utf8mb4 "$DB" \
  | LC_ALL=C sed -E "s#https?://localhost:[0-9]+#${URL}#g" > "$TMP/_body.sql"
{
  echo "# WordPress MySQL database backup"
  echo "# Created by UpdraftPlus version 1.26.4 (https://updraftplus.com)"
  echo "# Backup of: $URL"
  echo "# Home URL: $URL"
  echo "# Content URL: $URL/wp-content"
  echo "# Table prefix: wp_"
  echo "# Site info: multisite=0"
  echo "# Site info: end"
  echo ""
  cat "$TMP/_body.sql"
} | gzip > "$TMP/${B}-db.gz"

echo "[2/6] plugins.zip"; ( cd "$WPC" && zip -r -q -X "$TMP/${B}-plugins.zip" plugins/ )
echo "[3/6] themes.zip";  ( cd "$WPC" && zip -r -q -X "$TMP/${B}-themes.zip" themes/ )
echo "[4/6] uploads.zip"; ( cd "$WPC" && zip -r -q -X "$TMP/${B}-uploads.zip" uploads/ -x "uploads/elementor/*" )
echo "[5/6] others.zip (nestandardní wp-content složky)"
OTHERS=$(cd "$WPC" && ls -d */ 2>/dev/null | sed 's#/##' | grep -vE '^(plugins|themes|uploads|upgrade|updraft)$' || true)
[ -n "$OTHERS" ] && ( cd "$WPC" && zip -r -q -X "$TMP/${B}-others.zip" $OTHERS )

echo "[6/6] zásilka (store — komponenty už komprimované)"
OUTZIP="$OUT/zasilka-${NAME}-${TS}.zip"
( cd "$TMP" && zip -0 -q -X "$OUTZIP" backup_* )
rm -rf "$TMP"
echo "Hotovo: $OUTZIP"
echo "Ověření: unzip -t \"$OUTZIP\"; gzcat db.gz | grep -c 'CREATE TABLE'"
