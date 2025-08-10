#!/usr/bin/env bash
set -e

ssh_key_file="/home/archidep/.ssh/id_ed25519"

if test -f "${ssh_key_file}"; then
  echo "SSH key already exists, skipping generation."
else
  echo "Generating SSH key..."
  ssh-keygen -t ed25519 -f "${ssh_key_file}" -N "" -C "archidep-dev"
  chmod 444 "${ssh_key_file}"
  chmod 444 "${ssh_key_file}.pub"
fi
