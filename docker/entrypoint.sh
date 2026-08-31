#!/usr/bin/env sh
set -e
set -u

: "${ARCHIDEP_UID:=42000}"
: "${ARCHIDEP_GID:=${ARCHIDEP_UID}}"

# Where the application renders the course material site, shared with the static
# server that serves it. Unlike every other directory below, this one is a
# volume, so whichever container mounted it first decided who owns it — and the
# static server's image has no such directory to take the ownership from. It
# also outlives a change of the runtime user, which would otherwise leave a tree
# the application can no longer replace.
site_dir=/var/lib/archidep/site
mkdir -p "$site_dir"
# 0755 rather than the 0700 the rest of /var/lib/archidep has: what reads this
# one is a different user.
chmod 0755 "$site_dir"
if [ "$(stat -c %u "$site_dir")" != "$ARCHIDEP_UID" ]; then
  echo "Taking ownership of ${site_dir}..."
  chown -R "$ARCHIDEP_UID:$ARCHIDEP_GID" "$site_dir"
fi

if [ "$ARCHIDEP_UID" != 42000 ]; then
  echo "Changing archidep user and group to UID:GID ${ARCHIDEP_UID}:${ARCHIDEP_GID}..."
  usermod -u "$ARCHIDEP_UID" archidep 2>/dev/null
  groupmod -g "$ARCHIDEP_GID" archidep 2>/dev/null

  set +e
  for dir in /archidep /home/archidep /etc/archidep /etc/archidep/ssh /var/lib/archidep /var/lib/archidep/uploads; do
    chown "$ARCHIDEP_UID:$ARCHIDEP_GID" "$dir"
  done
  set -e

  set -- gosu "${ARCHIDEP_UID}:${ARCHIDEP_GID}" "${@}"
  echo "Done changing UID:GID"
fi

exec "$@"
