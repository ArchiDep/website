#!/usr/bin/env bash
set -e

cat <<EOF
================================================
=== Phase 5/6 — Step 1/2 — Ruby dependencies ===
================================================
EOF

echo "Installing/updating Ruby dependencies..."
bundle config set deployment true
bundle config set --local path /var/lib/archidep/bundle
bundle install

echo
cat <<EOF
=====================================
=== Phase 5/6 — Step 2/2 — Course ===
=====================================
EOF

exec bundle exec jekyll serve --config _config.yml,_config.proxied.yml --disable-disk-cache --drafts --livereload
