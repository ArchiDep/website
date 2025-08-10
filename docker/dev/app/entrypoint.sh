#!/usr/bin/env bash
# set -e

cd app

cat <<EOF
===============================
=== Installing dependencies ===
===============================
EOF

mix local.hex --force
mix deps.get

echo
cat <<EOF
===================================
=== Downloading user agent data ===
===================================
EOF

git config --global --add safe.directory /var/lib/archidep/git

if ! test -f /var/lib/archidep/deps/ua_inspector/priv/bot.bots.yml; then
  mix ua_inspector.download --force
else
  echo "Using already downloaded user agent data"
fi

unix_timestamp=$(date +%s)
cat <<EOF > /archidep/app/config/local.exs
import Config

config :archidep, force_recompilation: "${unix_timestamp}"
EOF

echo
cat <<EOF
===============================
=== Running the application ===
===============================
EOF

exec mix docker.dev
