# Course Assets
# =============
FROM node:24.4.0-alpine AS assets

RUN addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build/course/ && \
    chown build:build /build && \
    chmod 700 /build

WORKDIR /build
USER build:build

COPY --chown=build:build ./package.json ./package-lock.json /build/
COPY --chown=build:build ./course/package.json /build/course/

RUN npm ci

COPY --chown=build:build ./course/tsconfig.json ./course/tsconfig.assets.json ./course/webpack.config.cjs /build/course/
COPY --chown=build:build ./course/src/ /build/course/src/

ENV NODE_ENV=production

RUN npm run --workspace course build

# App & Course Theme
# ==================
FROM node:24.4.0-alpine AS theme

RUN addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build/theme/ && \
    chown -R build:build /build && \
    chmod 700 /build

WORKDIR /build
USER build:build

COPY --chown=build:build ./package.json ./package-lock.json /build/
COPY --chown=build:build ./theme/package.json /build/theme/

RUN npm ci

COPY --chown=build:build ./theme/ /build/theme/
COPY --chown=build:build ./app/ /build/app/
COPY --chown=build:build ./course/ /build/course/

ENV NODE_ENV=production

RUN npm run --workspace theme build

# Digest Assets
# =============
FROM elixir:1.18.4-otp-28-alpine AS digest

RUN addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build/digest/ && \
    chown -R build:build /build && \
    chmod 700 /build

WORKDIR /build/digest
USER build:build

COPY --chown=build:build ./digest/mix.exs ./digest/mix.lock /build/digest/

RUN mix local.hex --force && \
    mix deps.get && \
    mix compile

COPY --chown=build:build --from=assets /build/app/priv/static/assets/search/ /build/digest/priv/static/assets/search/
COPY --chown=build:build --from=theme /build/app/priv/static/assets/ /build/digest/priv/static/assets/

RUN mix phx.digest priv/static -o priv/static && \
    ls -laR /build/digest/priv/static/ && \
    cat /build/digest/priv/static/cache_manifest.json

# Course
# ======
FROM ruby:3.4.4-alpine AS course

RUN apk add --no-cache g++ make && \
    addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build/course/ && \
    chown -R build:build /build && \
    chmod 700 /build

WORKDIR /build/course
USER build:build

COPY --chown=build:build ./course/Gemfile ./course/Gemfile.lock /build/course/

RUN bundle install

COPY --chown=build:build ./course/ /build/course/
COPY --chown=build:build --from=assets /build/app/priv/static/assets/course/ /build/app/priv/static/assets/course/
COPY --chown=build:build --from=digest /build/digest/priv/static/ /build/app/priv/static/

ENV JEKYLL_ENV=production

RUN bundle exec jekyll build

# Application
# ===========
FROM elixir:1.18.4-otp-28-alpine

ARG ARCHIDEP_GIT_REVISION

RUN apk add --no-cache git && \
    addgroup -S app && \
    adduser -D -G app -H -h /usr/src/app -S app && \
    mkdir -p /usr/src/app/config && \
    chown -R app:app /usr/src/app && \
    chmod 700 /usr/src/app

WORKDIR /usr/src/app
USER app:app

COPY --chown=app:app ./app/mix.exs ./app/mix.lock /usr/src/app/

ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix deps.get && \
    mix deps.compile

COPY --chown=app:app ./app/ /usr/src/app/
COPY --chown=app:app --from=course /build/app/priv/static/ /usr/src/app/priv/static/
COPY --chown=app:app --from=assets /build/app/priv/static/assets/course/ /usr/src/app/priv/static/assets/course/
COPY --chown=app:app --from=digest /build/digest/priv/static/ /usr/src/app/priv/static/

RUN mix do ua_inspector.download --force, assets.setup, assets.deploy
