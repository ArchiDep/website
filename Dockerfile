# ============= #
# Course Assets #
# ============= #
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

# ================== #
# App & Dependencies #
# ================== #
FROM elixir:1.18.4-otp-28-alpine AS theme-sources

RUN apk add --no-cache git && \
    addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build && \
    chown -R build:build /build && \
    chmod 700 /build

WORKDIR /build
USER build:build

COPY --chown=build:build ./app/mix.exs ./app/mix.lock /build/

ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix deps.get --only prod

COPY --chown=build:build ./app/lib/archidep_web/ /build/lib/archidep_web/
COPY --chown=build:build ./course/ /build/course/

# ================== #
# App & Course Theme #
# ================== #
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

COPY --chown=build:build --from=theme-sources /build/ /build/
COPY --chown=build:build ./theme/ /build/theme/

ENV NODE_ENV=production

RUN npm run --workspace theme build

# ============= #
# Digest Assets #
# ============= #
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

# ====== #
# Course #
# ====== #
FROM ruby:3.4.4-alpine AS course

RUN apk add --no-cache g++ make nodejs npm && \
    addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build/course/ && \
    chown -R build:build /build && \
    chmod 700 /build

WORKDIR /build/course
USER build:build

COPY --chown=build:build ./course/Gemfile ./course/Gemfile.lock /build/course/

RUN bundle install

COPY --chown=build:build ./package.json ./package-lock.json /build/
COPY --chown=build:build ./course/package.json /build/course/

RUN npm ci

COPY --chown=build:build ./course/ /build/course/
COPY --chown=build:build ./app/mix.exs /build/app/mix.exs
COPY --chown=build:build --from=assets /build/app/priv/static/assets/course/ /build/app/priv/static/assets/course/
COPY --chown=build:build --from=digest /build/digest/priv/static/ /build/app/priv/static/

ENV JEKYLL_ENV=production

RUN bundle exec jekyll build

# =================== #
# Application Release #
# =================== #
FROM elixir:1.18.4-otp-28-alpine AS release

RUN apk add --no-cache git nodejs npm && \
    addgroup -S app && \
    adduser -D -G app -H -h /usr/src/app -S app && \
    mkdir -p /usr/src/app/.git /usr/src/app/config && \
    chown -R app:app /usr/src/app && \
    chmod 700 /usr/src/app

WORKDIR /usr/src/app
USER app:app

COPY --chown=app:app ./app/mix.exs ./app/mix.lock /usr/src/app/

ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix deps.get --only prod && \
    mix deps.compile

COPY --chown=app:app ./app/ /usr/src/app/
COPY --chown=app:app --from=course /build/app/priv/static/archidep.json /usr/src/app/priv/static/

COPY ./.git/ /tmp/.git/
RUN cat /tmp/.git/HEAD | grep '^ref: refs\/heads\/' | sed 's/^ref: refs\/heads\///' > /usr/src/app/.git-branch && \
    touch /usr/src/app/.git-dirty && \
    cat /tmp/.git/HEAD | awk '{print "/tmp/.git/"$2}' | xargs cat > /usr/src/app/.git-revision

RUN mix do ua_inspector.download --force, assets.setup, assets.deploy && \
    mv /usr/src/app/priv/static/cache_manifest.json /usr/src/app/priv/static/cache_manifest2.json

COPY --chown=app:app --from=course /build/app/priv/static/ /usr/src/app/priv/static/

RUN mix merge_manifests && \
    cat /usr/src/app/priv/static/cache_manifest.json && \
    mix release

# =========== #
# Application #
# =========== #
FROM elixir:1.18.4-otp-28-alpine AS app

WORKDIR /app

RUN apk add --no-cache ca-certificates libstdc++ musl-locales ncurses openssl tzdata

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod

RUN addgroup -S app && \
    adduser -D -G app -H -h /app -S app && \
    mkdir -p /etc/app/ssh /var/lib/app/uploads && \
    chown -R app:app /app /etc/app /var/lib/app && \
    chmod 700 /app /etc/app /var/lib/app

COPY --chown=app:app --from=release /usr/src/app/_build/prod/rel/archidep ./

USER app:app

CMD ["/app/bin/server"]

EXPOSE 42000

# ============= #
# Reverse Proxy #
# ============= #
FROM nginx:1.29-alpine AS assets-server

RUN rm -fr /usr/share/nginx/html/* && \
    mkdir -p /var/www/html && \
    chown nginx:nginx /var/www/html && \
    chmod 700 /var/www/html

COPY ./docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=app /app/lib/archidep-*/priv/static/ /var/www/html
