#!/usr/bin/env bash
# Builds the prepared repository of the "Two merges" exercise of Hello Git:
# `main`, a `fix-typo` branch directly ahead of it (a fast-forward), and a
# `contact-page` branch that has diverged from it (a three-way merge).
#
# Authors and dates are fixed, so that the repository gets the same commit
# hashes every time it is built.
set -euo pipefail

dir="${1:-hello-git-merges}"
rm -rf "$dir"
mkdir "$dir"
cd "$dir"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="John Doe" GIT_AUTHOR_EMAIL="john.doe@example.com"
export GIT_COMMITTER_NAME="John Doe" GIT_COMMITTER_EMAIL="john.doe@example.com"

commit() {
  export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"
  git add .
  git commit -q -m "$2"
}

git init -q -b main

cat > README.md <<'EOF'
# Hello Git merges

A prepared repository for the "Two merges" exercise of Hello Git, in the
ArchiDep course.
EOF
cat > index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <title>Hello Git</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <h1>Hello Git</h1>
    <p>Welcome to our website.</p>
    <a href="about.html">About us</a>
  </body>
</html>
EOF
cat > style.css <<'EOF'
body {
  font-family: sans-serif;
}
EOF
commit "2026-09-01T10:00:00+02:00" "Create the home page"

cat > about.html <<'EOF'
<!doctype html>
<html>
  <head>
    <title>About us</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <h1>About us</h1>
    <p>We are a smal team who loves Git.</p>
  </body>
</html>
EOF
commit "2026-09-02T10:00:00+02:00" "Add an about page"

git branch contact-page

cat > style.css <<'EOF'
body {
  font-family: sans-serif;
  max-width: 40em;
  margin: 0 auto;
}
EOF
commit "2026-09-03T10:00:00+02:00" "Improve the style"

git switch -q -c fix-typo
sed 's/a smal team/a small team/' about.html > about.html.tmp
mv about.html.tmp about.html
commit "2026-09-04T10:00:00+02:00" "Fix a typo on the about page"

git switch -q contact-page
cat > contact.html <<'EOF'
<!doctype html>
<html>
  <head>
    <title>Contact us</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <h1>Contact us</h1>
    <p>Write to us at hello@example.com.</p>
  </body>
</html>
EOF
commit "2026-09-05T10:00:00+02:00" "Add a contact page"

sed 's#<a href="about.html">About us</a>#<a href="about.html">About us</a>\n    <a href="contact.html">Contact us</a>#' index.html > index.html.tmp
mv index.html.tmp index.html
commit "2026-09-06T10:00:00+02:00" "Link to the contact page"

git switch -q main
git log --oneline --graph --all
