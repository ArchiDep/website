#!/usr/bin/env bash
set -e

cd app

cat <<EOF
======================================================
=== Phase 5/5 — Step 1/3 — Application compilation ===
======================================================
EOF

git config --global --add safe.directory /var/lib/archidep/git
echo "Compiling Elixir application..."
mix compile

echo
cat <<EOF
==================================================
=== Phase 5/5 — Step 2/3 — User agent database ===
==================================================
EOF

mix archidep.ua_inspector.download --if-missing

unix_timestamp=$(date +%s)
cat <<EOF > /archidep/app/config/local.exs
import Config

config :archidep, force_recompilation: "${unix_timestamp}"
EOF

echo
cat <<EOF
==========================================
=== Phase 5/5 — Step 3/3 — Application ===
==========================================
       🚀🚀🚀 Almost done! 🚀🚀🚀

EOF

exec mix docker.dev
