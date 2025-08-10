#!/usr/bin/env bash
set -e

rsync -aP /etc/archidep/ /archidep/
test -d /archidep/node_modules || npm ci --no-audit --no-fund --prefer-offline
