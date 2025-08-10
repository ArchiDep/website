#!/usr/bin/env bash
set -e

cat <<EOF
================================================
=== Phase 4/5 — Step 1/2 — Ruby dependencies ===
================================================
EOF

echo "Installing/updating Ruby dependencies..."
bundle config set deployment true
bundle config set --local path /var/lib/archidep/bundle
bundle install

echo
cat <<EOF
=====================================
=== Phase 4/5 — Step 2/2 — Course ===
=====================================
EOF

exec bundle exec jekyll serve --config _config.yml,_config.proxied.yml,_config.docker.yml --disable-disk-cache --drafts --livereload
