# Architecture & Deployment Course Website

This repository contains the source code for the Media Engineering Architecture
& Deployment course website, composed of:

- A [Jekyll][jekyll] static site containing most of the course's materials
- A [Phoenix][phoenix] application for students to submit exercises and manage a
  virtual machine in the context of the course

## Requirements

* [Elixir][elixir] 1.18.x
* [Erlang/OTP][erlang] 27.x
* [Node.js][node] 22.x
* [Ruby][ruby] 3.4

> If you are using [asdf], you can install all of these by running `asdf intall`
> in this repository.

## Setup

```bash
git clone git@github.com:ArchiDep/website.git
cd ArchiDep

# Install the Phoenix application's dependencies
cd app
mix deps.get

# Install the Jekyll site's dependencies
cd ../course
bundle install

# Install other tooling
cd ..
npm ci

# Copy (and adapt) the application's local config file
cd app
cp config/local.sample.exs config/local.exs
```

## Configuration

Ports 42000, 42001 & 42002 are used by default.

[asdf]: https://asdf-vm.com
[elixir]: https://elixir-lang.org
[erlang]: https://www.erlang.org
[jekyll]: https://jekyllrb.com
[node]: https://nodejs.org
[phoenix]: https://www.phoenixframework.org
[ruby]: https://www.ruby-lang.org
