#!/usr/bin/env sh

# Fill a directory with the finished editions of the course.
#
# The editions are published as a git repository that is also the backup site,
# so a host comes to hold them by cloning it: shallow the first time, a fetch
# and a hard reset every time after, so that a restart transfers deltas and a
# redeploy transfers nothing. The repository is public and no credential is
# involved.
#
# This runs once and exits, before nothing: the static server in front of it
# serves the edition it was built with whether this has run or not, and the
# editions appear when it lands. That is why it exits 0 even when it could not
# fetch — see the last lines.

set -e
set -u

: "${ARCHIDEP_ARCHIVES_DIRECTORY:?The directory to fill must be given}"
: "${ARCHIDEP_ARCHIVES_REPOSITORY:?The repository holding the editions must be given}"
: "${ARCHIDEP_ARCHIVES_REF:=main}"

dir="$ARCHIDEP_ARCHIVES_DIRECTORY"
repo="$ARCHIDEP_ARCHIVES_REPOSITORY"
ref="$ARCHIDEP_ARCHIVES_REF"

# Every step is chained explicitly rather than left to `set -e`, which a shell
# suspends inside a function it calls from a condition: a failing fetch would
# otherwise carry on to the reset and the clean and report their status as this
# function's own.
fetch() {
  # The clone is owned by whoever first wrote it, which is not necessarily this
  # container's user, and git refuses to work in a directory it thinks belongs
  # to someone else.
  git config --global --add safe.directory "$dir" || return 1

  if [ -d "$dir/.git" ]; then
    echo "Updating the editions in $dir from $repo ($ref)..."
    # The URL is set again rather than trusted, so that moving the repository is
    # a change of configuration rather than a directory that has to be thrown
    # away. The clean is what removes an edition that was published and then
    # unpublished, which no reset does and which would go on being served.
    git -C "$dir" remote set-url origin "$repo" &&
      git -C "$dir" fetch --depth 1 origin "$ref" &&
      git -C "$dir" reset --hard FETCH_HEAD &&
      git -C "$dir" clean -f -f -d
  else
    echo "Cloning the editions into $dir from $repo ($ref)..."
    mkdir -p "$dir" &&
      git clone --depth 1 --branch "$ref" "$repo" "$dir"
  fi
}

if fetch; then
  echo "The editions in $dir are those of $repo ($ref)"
else
  # Deliberately not a failure. What answers whether a deployment is complete is
  # the application's own check, which reports the editions that are not where
  # they should be.
  echo "The editions could not be fetched from $repo ($ref); $dir is left as it was" >&2
fi
