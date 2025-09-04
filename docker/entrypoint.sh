#!/usr/bin/env sh
set -e
set -u

: "${ARCHIDEP_UID:=42000}"
: "${ARCHIDEP_GID:=${ARCHIDEP_UID}}"

if [ "$ARCHIDEP_UID" != 42000 ]; then
  echo "Changing archidep user and group to UID:GID ${ARCHIDEP_UID}:${ARCHIDEP_GID}..."
  usermod -u "$ARCHIDEP_UID" archidep 2>/dev/null
  groupmod -g "$ARCHIDEP_GID" archidep 2>/dev/null
  chown "$ARCHIDEP_UID:$ARCHIDEP_GID" /archidep /home/archidep /etc/archidep /etc/archidep/ssh /var/lib/archidep /var/lib/archidep/uploads
  set -- gosu "${ARCHIDEP_UID}:${ARCHIDEP_GID}" "${@}"
  echo "Done changing UID:GID"
fi

exec "$@"
