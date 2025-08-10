# Architecture & Deployment Course Website

[![status](https://status.archidep.ch/badge/_/status?labelColor=&color=&style=flat&label=status)](https://status.archidep.ch)
[![build](https://github.com/ArchiDep/website/actions/workflows/build.yml/badge.svg)](https://github.com/ArchiDep/website/actions/workflows/build.yml)
[![MIT License](https://img.shields.io/static/v1?label=license&message=MIT&color=informational)](https://opensource.org/licenses/MIT)

This repository contains the source code for the Media Engineering Architecture
& Deployment course website, composed of:

- A [Jekyll][jekyll] static site containing most course material
- A [Phoenix][phoenix] application to help students manage a virtual machine in
  the context of the course
- A [Tailwind][tailwind] theme for both parts
- Various related utilities written mostly in [TypeScript][typescript]

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Requirements](#requirements)
- [Initial setup](#initial-setup)
  - [Initial Docker setup](#initial-docker-setup)
  - [Initial machine setup](#initial-machine-setup)
- [Run the website in development mode](#run-the-website-in-development-mode)
  - [Run in development mode with Docker](#run-in-development-mode-with-docker)
  - [Run in development mode on your machine](#run-in-development-mode-on-your-machine)
  - [Run the course only in development mode](#run-the-course-only-in-development-mode)
- [Configuration](#configuration)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Requirements

To run with Docker (slower, but simpler):

- [Docker][docker] :tada:

To run on your machine:

- [Elixir][elixir] 1.18.x
- [Erlang/OTP][erlang] 28.x
- [Node.js][node] 24.x
- [Ruby][ruby] 3.4.x
- [PostgreSQL][postgresql] 17.x
- `ssh-keygen` to generate a key pair

> Use [asdf] or [mise] to install Elixir, Erlang/OTP, Node.js & Ruby based on
> [`.tool-versions`](./.tool-versions).

Other optional tools (useful in both modes):

- [direnv][direnv] to quickly run scripts

## Initial setup

Setup instructions to perform before running the website for the first time.

### Initial Docker setup

No setup is required if you have Docker installed. Simply clone the repository.

```bash
# Clone this repository
git clone git@github.com:ArchiDep/website.git
cd website
```

> [!TIP] Optionally, install [direnv][direnv] to automatically have all the
> project's utility scripts in your PATH when you navigate to the repository.
>
> ```bash
> direnv allow  # see .envrc
> ```

### Initial machine setup

Once you have all the requirements installed, follow these instructions to set
up the website to run in development mode on your machine.

You will need a **PostgreSQL database**. You can either let the website create
it if you provide credentials that have sufficient privileges, or create it
yourself beforehand.

```bash
# Clone this repository
git clone git@github.com:ArchiDep/website.git
cd website

# Install tooling
npm ci  # grab a coffee

# Build the app assets, course assets & theme at least once
npm run --workspace app build
npm run --workspace course build
npm run --workspace theme build

# Install the Jekyll site's dependencies & build at least once
cd course
bundle install
bundle exec jekyll build

# Install and compile the Phoenix application's dependencies
cd ../app
mix deps.get
mix compile  # grab another coffee (extra large mug)
mix ua_inspector.download --force  # user agent database

# Copy (and adapt) the application's local config file. Don't forget to set up
# the PostgreSQL connection information.
cp config/local.sample.exs config/local.exs

# Create required directories
mkdir -p priv/ssh priv/uploads

# Generate an SSH key (with no password) for testing
cd priv/ssh
ssh-keygen -t ed25519 -f id_ed25519 -C archidep
cd ../../

# Perform initial setup (create the database, run migrations, etc)
mix setup
```

## Run the website in development mode

How to run the website in development mode with live reload on code changes.

### Run in development mode with Docker

```bash
./scripts/dev  # or simply "dev" if you have direnv
```

> [!TIP] It will take a while (quite a long while the first time). The various
> Docker containers only start when their dependencies have finished their
> initial run, as defined by their health checks. The startup order is as
> follows:
>
> - Start the database (`db` container), compile the application assets
>   (`app-assets` container), course assets (`course-assets` container, takes a
>   while to perform the first build) & theme (`theme` container)
> - Serve the course material (`course` container)
> - Start the application (`app` container)

Visit http://localhost:42000 once the application has started.

### Run in development mode on your machine

Run all of these in parallel:

```bash
# Build and watch app assets with esbuild
cd app
npm start

# Build and watch course assets with Webpack
cd course
npm start

# Build and watch the CSS theme with Tailwind
cd theme
npm start

# Serve course material with Jekyll
cd course
bundle exec jekyll server --config _config.yml,_config.proxied.yml --drafts --livereload

# Run the Phoenix web application (also proxies to Jekyll)
cd app
mix phx.server
```

Visit http://localhost:42000 once all tasks have finished starting.

### Run the course only in development mode

If you only need to work on course material, and not on the application
dashboard or admin console, run only these commands in parallel:

```bash
# Build and watch course assets with Webpack
cd course
npm start

# Build and watch the CSS theme with Tailwind
cd theme
npm start

# Serve course material with Jekyll
cd course
bundle exec jekyll server --config _config.yml --drafts --livereload
```

Visit http://localhost:42001.

## Configuration

These ports are used:

- 42000 (app, main entrypoint)
- 42001 (Jekyll, _not exposed directly with Docker_)
- 42002 (Jekyll live reload)
- 42003 (Prometheus metrics at `/metrics`)

Concerning the monitoring metrics available at `http://42003/metrics`, note that
in development, the metrics are only updated after 10 minutes and then every 10
minutes by default to avoid polluting the logs with database queries. Update
`metrics_polling_interval` in your `config/local.exs` file to change this
interval (only supported when running on your machine for now).

[asdf]: https://asdf-vm.com
[direnv]: https://direnv.net
[docker]: https://www.docker.com
[elixir]: https://elixir-lang.org
[erlang]: https://www.erlang.org
[jekyll]: https://jekyllrb.com
[mise]: https://mise.jdx.dev
[node]: https://nodejs.org
[phoenix]: https://www.phoenixframework.org
[postgresql]: https://www.postgresql.org
[ruby]: https://www.ruby-lang.org
[tailwind]: https://tailwindcss.com
[typescript]: https://www.typescriptlang.org
