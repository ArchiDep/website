#!/usr/bin/env bash
set -e

cat <<EOF
===============================================
=== Phase 4/6 — Step 1/3 (parallel) — Theme ===
===============================================
EOF

exec npm start --workspace theme
