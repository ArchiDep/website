#!/usr/bin/env bash
set -e

cd app

cat <<EOF
=====================================================
=== Phase 1/5 — Step 1/2 — Elixir package manager ===
=====================================================
EOF

echo "Installing Hex package manager (if needed)..."
mix local.hex --force --if-missing

echo
cat <<EOF
==================================================
=== Phase 1/5 — Step 2/2 — Elixir dependencies ===
==================================================
EOF

mix deps.get
