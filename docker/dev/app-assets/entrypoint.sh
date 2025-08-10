#!/usr/bin/env bash
set -e

cat <<EOF
============================================================
=== Phase 3/5 — Step 1/3 (parallel) — Application assets ===
============================================================
EOF

exec npm run start:docker --workspace app
