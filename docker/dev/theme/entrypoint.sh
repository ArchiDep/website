#!/usr/bin/env bash
set -e

cat <<EOF
===============================================
=== Phase 3/5 — Step 1/3 (parallel) — Theme ===
===============================================
EOF

exec npm start --workspace theme
