#!/usr/bin/env bash
set -e

cat <<EOF
===================================================
=== Phase 2/5 — Step 1/1 — Node.js dependencies ===
===================================================
EOF

rsync -aP /etc/archidep/ /archidep/

if test -d /archidep/node_modules/.bin; then
  echo "Updating existing Node.js dependencies..."
  npm install --no-audit --no-fund --no-save
else
  echo "Installing Node.js dependencies for the first time..."
  echo "Note: this will take a while because Pupeteer needs to download Chromium."
  npm ci --no-audit --no-fund --prefer-offline
fi
