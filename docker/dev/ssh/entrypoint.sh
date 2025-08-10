#!/usr/bin/env bash
set -e

cat <<EOF
===========================================
=== Phase 3/6 — Step 1/1 — SSH key pair ===
===========================================
EOF

ssh_key_file="/home/archidep/.ssh/id_ed25519"

if test -f "${ssh_key_file}"; then
  echo "SSH key pair already exists."
else
  echo "Generating a new SSH key pair..."
  ssh-keygen -t ed25519 -f "${ssh_key_file}" -N "" -C "archidep-dev"
  chmod 444 "${ssh_key_file}"
  chmod 444 "${ssh_key_file}.pub"
fi
