# Architecture & Deployment Course Website

This repository contains the source code for the Media Engineering Architecture
& Deployment course website, composed of:

- A [Jekyll][jekyll] static site containing most of the course's materials
- A [Phoenix][phoenix] application for students to manage a virtual machine in
  the context of the course

## Requirements

* [Elixir][elixir] 1.18.x
* [Erlang/OTP][erlang] 28.x
* [Node.js][node] 24.x
* [Ruby][ruby] 3.4

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
```

# Run in development

Run all these commands in separate terminals:

```bash
# Build assets with Webpack
cd website/course
npm start

# Build the CSS theme with Tailwind
cd website/theme
npm start

# Build and serve the course with Jekyll
cd website/course
bundle exec jekyll server --config _config.yml --drafts --livereload

# Run the Phoenix web application (also proxies to Jekyll)
cd website/app
mix phx.server
```

## Configuration

These ports are used by default:

- 42000 (app, main entrypoint)
- 42001 (Jekyll)
- 42002 (Jekyll live reload)

[asdf]: https://asdf-vm.com
[elixir]: https://elixir-lang.org
[erlang]: https://www.erlang.org
[jekyll]: https://jekyllrb.com
[mise]: https://mise.jdx.dev
[node]: https://nodejs.org
[phoenix]: https://www.phoenixframework.org
[ruby]: https://www.ruby-lang.org
