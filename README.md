# Architecture & Deployment Course Website

[![build](https://github.com/ArchiDep/website/actions/workflows/build.yml/badge.svg)](https://github.com/ArchiDep/website/actions/workflows/build.yml)
[![MIT License](https://img.shields.io/static/v1?label=license&message=MIT&color=informational)](https://opensource.org/licenses/MIT)

This repository contains the source code for the Media Engineering Architecture
& Deployment course website, composed of:

- A [Jekyll][jekyll] static site containing most of the course's materials
- A [Phoenix][phoenix] application for students to manage a virtual machine in
  the context of the course

## Requirements

- [Elixir][elixir] 1.18.x
- [Erlang/OTP][erlang] 28.x
- [Node.js][node] 24.x
- [Ruby][ruby] 3.4

> Use [asdf] or [mise] to install everything based on
> [`.tool-versions`](./.tool-versions).

## Setup

```bash
# Clone this repository
git clone git@github.com:ArchiDep/website.git
cd website

# Install and compile the Phoenix application's dependencies
cd app
mix deps.get
mix compile  # grab a coffee
mix ua_inspector.download

# Install the Jekyll site's dependencies
cd ../course
bundle install

# Install other tooling
cd ..
npm ci

# Copy (and adapt) the application's local config file
cd app
cp config/local.sample.exs config/local.exs

# Perform initial setup (create the database, run migrations, etc)
mix setup

# Generate an SSH key (with no password) for testing
cd ..
mkdir -p priv/ssh
cd priv/ssh
ssh-keygen -t ed25519 -C archidep
```

## Run the course and application in development

Run all these commands in parallel:

```bash
# Build and watch course assets with Webpack
cd website/course
npm start

# Build and watch the CSS theme with Tailwind
cd website/theme
npm start

# Serve course material with Jekyll
cd website/course
bundle exec jekyll server --config _config.yml,_config.proxied.yml --drafts --livereload

# Run the Phoenix web application (also proxies to Jekyll)
cd website/app
mix phx.server
```

Visit http://localhost:42000

## Run the course in development

If you only need to work on course material, run these commands in parallel:

```bash
# Build and watch course assets with Webpack
cd website/course
npm start

# Build and watch the CSS theme with Tailwind
cd website/theme
npm start

# Serve course material with Jekyll
cd website/course
bundle exec jekyll server --config _config.yml --drafts --livereload
```

Visit http://localhost:42001

## Configuration

These ports are used by default:

- 42000 (app, main entrypoint)
- 42001 (Jekyll)
- 42002 (Jekyll live reload)

## Simulate a student VM with a Docker container

From the root of the repository:

```bash
# Add the test SSH key to your SSH agent
cat tmp/jde/id_ed25519 | ssh-add -

# Build an SSH server image
cd app/test/docker/ssh-server
docker build -t archidep/ssh-server --build-arg JDE_UID="$(id -u)" .

# Run a container with an SSH server and expose it on local port 2222
cd ../../../
docker run --rm -it --init -p 2222:22 -v "$PWD/tmp/jde/id_ed25519.pub:/home/jde/.ssh/authorized_keys:ro" archidep/ssh-server
```

[asdf]: https://asdf-vm.com
[elixir]: https://elixir-lang.org
[erlang]: https://www.erlang.org
[jekyll]: https://jekyllrb.com
[mise]: https://mise.jdx.dev
[node]: https://nodejs.org
[phoenix]: https://www.phoenixframework.org
[ruby]: https://www.ruby-lang.org
