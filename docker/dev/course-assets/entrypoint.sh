#!/usr/bin/env bash
set -e

cat <<EOF
=======================================================
=== Phase 3/5 — Step 1/3 (parallel) — Course assets ===
=======================================================
EOF

exec npm start --workspace course
