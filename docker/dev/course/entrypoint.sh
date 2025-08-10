#!/usr/bin/env bash
set -e

bundle config set deployment true
bundle config set --local path /var/lib/archidep/bundle
bundle install
exec bundle exec jekyll serve --config _config.yml,_config.proxied.yml --disable-disk-cache --drafts --livereload
