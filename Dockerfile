################################
### Application dependencies ###
################################
FROM elixir:1.18.4-otp-28-alpine AS app-deps

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

##########################
### Application Assets ###
##########################
FROM node:24.4.0-alpine AS app-assets

RUN addgroup -S build && \
    adduser -D -G build -H -h /build -S build && \
    mkdir -p /build/course/ && \
    chown build:build /build && \
    chmod 700 /build

WORKDIR /build
USER build:build

COPY --chown=build:build ./package.json ./package-lock.json /build/
COPY --chown=build:build ./app/package.json /build/app/

RUN npm ci

COPY --chown=build:build ./app/assets/ /build/app/assets/
COPY --chown=build:build --from=app-deps /build/deps/ /build/app/deps/

ENV NODE_ENV=production \
    NODE_PATH=/build/app/deps

RUN npm run --workspace app build:production

#####################
### Course Assets ###
#####################
FROM node:24.4.0-alpine AS course-assets

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

#############
### Theme ###
#############
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

COPY --chown=build:build --from=app-deps /build/deps/ /build/app/deps/
COPY --chown=build:build ./app/lib/archidep_web/ /build/app/lib/archidep_web/
COPY --chown=build:build ./course/ /build/course/
COPY --chown=build:build ./theme/ /build/theme/

ENV NODE_ENV=production

RUN npm run --workspace theme build

#####################
### Digest Assets ###
#####################
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

COPY --chown=build:build --from=app-assets /build/app/priv/static/assets/app/ /build/digest/priv/static/assets/app/
COPY --chown=build:build --from=course-assets /build/app/priv/static/assets/search/ /build/digest/priv/static/assets/search/
COPY --chown=build:build --from=theme /build/app/priv/static/assets/theme/ /build/digest/priv/static/assets/theme/

RUN mix phx.digest priv/static -o priv/static && \
    ls -laR /build/digest/priv/static/ && \
    cat /build/digest/priv/static/cache_manifest.json

##############
### Course ###
##############
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
COPY --chown=build:build --from=course-assets /build/app/priv/static/assets/course/ /build/app/priv/static/assets/course/
COPY --chown=build:build --from=digest /build/digest/priv/static/ /build/app/priv/static/

ENV JEKYLL_ENV=production

RUN bundle exec jekyll build

###########################
### Application Release ###
###########################
FROM elixir:1.18.4-otp-28-alpine AS release

RUN apk add --no-cache git nodejs npm && \
    addgroup -S app && \
    adduser -D -G app -H -h /home/app -S app && \
    mkdir -p /home/app /usr/src/app/.git /usr/src/app/config && \
    chown -R app:app /home/app /usr/src/app && \
    chmod 700 /usr/src/app

WORKDIR /usr/src/app
USER app:app

COPY --chown=app:app ./app/mix.exs ./app/mix.lock /usr/src/app/
COPY --chown=app:app --from=app-deps /build/deps/ /usr/src/app/deps/

ENV MIX_ENV=prod

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing && \
    mix deps.compile

COPY --chown=app:app ./app/ /usr/src/app/
COPY --chown=app:app --from=course /build/app/priv/static/archidep.json /usr/src/app/priv/static/

COPY ./.git/ /tmp/.git/
RUN cat /tmp/.git/HEAD | grep '^ref: refs\/heads\/' | sed 's/^ref: refs\/heads\///' > /usr/src/app/.git-branch && \
    touch /usr/src/app/.git-dirty && \
    cat /tmp/.git/HEAD | awk '{print "/tmp/.git/"$2}' | xargs cat > /usr/src/app/.git-revision

RUN mix do ua_inspector.download --force

COPY --chown=app:app --from=course /build/app/priv/static/ /usr/src/app/priv/static/

RUN mix sentry.package_source_code && \
    mix release

###################
### Application ###
###################
FROM elixir:1.18.4-otp-28-alpine AS app

WORKDIR /archidep

ENV ARCHIDEP_UID=42000 \
    ARCHIDEP_GID=42000 \
    GOSU_VERSION=1.17 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod

RUN apk add --no-cache ca-certificates libstdc++ musl-locales ncurses openssl shadow tzdata && \
    # Install gosu
    set -eux && \
    apk add --no-cache --virtual .gosu-deps \
      dpkg \
      gnupg \
    && \
    \
    # Download gosu
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    \
    # Verify gosu signature
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    \
    # Clean up fetch dependencies
    apk del --no-network .gosu-deps; \
    \
    chmod +x /usr/local/bin/gosu; \
    # Berify that the gosu binary works
    gosu --version; \
    gosu nobody true && \
    # Create application user and group
    addgroup -g 42000 -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S -u 42000 archidep && \
    mkdir -p /etc/archidep/ssh /home/archidep /var/lib/archidep/uploads && \
    chown -R archidep:archidep /archidep /home/archidep /etc/archidep /var/lib/archidep && \
    chmod 700 /archidep /etc/archidep /home/archidep /var/lib/archidep

COPY --chown=archidep:archidep --from=release /usr/src/app/_build/prod/rel/archidep ./
COPY ./docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/archidep/bin/server"]

EXPOSE 42000
EXPOSE 42003

#####################
### Assets server ###
#####################
FROM nginx:1.29-alpine AS assets-server

RUN rm -fr /usr/share/nginx/html/* && \
    mkdir -p /var/www/html && \
    chown nginx:nginx /var/www/html && \
    chmod 700 /var/www/html

COPY ./docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=app /archidep/lib/archidep-*/priv/static/ /var/www/html
