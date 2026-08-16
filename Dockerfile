ARG APP_DEPS_IMAGE=app-deps-compiled

################################
### Application dependencies ###
################################
FROM elixir:1.19.5-otp-28-alpine AS app-deps

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

# Compile dependencies in a dedicated stage so compiled artifacts can be
# reused by the release stage. This avoids recompiling deps every time the
# release image is built.
FROM app-deps AS app-deps-compiled
WORKDIR /build
USER build:build
ENV MIX_ENV=prod

# Compile only dependencies (not the application) and keep compiled artifacts
# under /build/_build and /build/deps to be copied into the release stage.
RUN mix deps.compile --only prod

## Named stage that references the registry-pulled compiled-deps image.
## This stage is created from the `APP_DEPS_IMAGE` build-arg so we can reliably
## use `COPY --from=app-deps-image` below (avoids variable expansion in --from).
FROM ${APP_DEPS_IMAGE} AS app-deps-image

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
FROM elixir:1.19.5-otp-28-alpine AS digest

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
COPY --chown=build:build --from=course-assets /build/app/priv/static/assets/course/ /build/digest/priv/static/assets/course/
COPY --chown=build:build --from=course-assets /build/app/priv/static/assets/search/ /build/digest/priv/static/assets/search/
COPY --chown=build:build --from=theme /build/app/priv/static/assets/emoji/ /build/digest/priv/static/assets/emoji/
COPY --chown=build:build --from=theme /build/app/priv/static/assets/fonts/ /build/digest/priv/static/assets/fonts/
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
# How far the course has got, which both halves of the site read from the one
# copy the application ships: the Liquid sidebar colours its entries by it and
# the home page's cards list what the last session covered.
COPY --chown=build:build ./app/priv/course/ /build/app/priv/course/
COPY --chown=build:build --from=digest /build/digest/priv/static/ /build/app/priv/static/

COPY ./.git/ /tmp/.git/
RUN cat /tmp/.git/HEAD | grep '^ref: refs\/heads\/' | sed 's/^ref: refs\/heads\///' > /build/course/.git-branch && \
    touch /build/course/.git-dirty && \
    cat /tmp/.git/HEAD | awk '{print "/tmp/.git/"$2}' | xargs cat > /build/course/.git-revision

ENV JEKYLL_ENV=production

RUN bundle exec jekyll build

###########################
### Application Release ###
###########################
FROM elixir:1.19.5-otp-28-alpine AS release

ARG APP_DEPS_IMAGE

RUN apk add --no-cache git nodejs npm && \
    addgroup -S app && \
    adduser -D -G app -H -h /home/app -S app && \
    mkdir -p /home/app /usr/src/app/.git /usr/src/app/config && \
    chown -R app:app /home/app /usr/src/app && \
    chmod 700 /usr/src/app

WORKDIR /usr/src/app
USER app:app

COPY --chown=app:app ./app/mix.exs ./app/mix.lock /usr/src/app/

# Copy compiled dependencies (deps and _build) from the compiled-deps stage so
# the release stage does not need to recompile dependencies. The
# `app-deps-compiled` stage runs `mix deps.compile` and preserves the compiled
# artifacts under `/build/_build`.
COPY --chown=app:app --from=app-deps-image /build/deps/ /usr/src/app/deps/
COPY --chown=app:app --from=app-deps-image /build/_build/ /usr/src/app/_build/

ENV MIX_ENV=prod

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing && \
    mix deps.compile

COPY --chown=app:app ./app/ /usr/src/app/

# The course material the application compiles its model of the course from.
# `ArchiDep.CourseSite.Material` resolves it relative to its own source file, so
# the repository layout has to be reproduced here: the working directory is
# /usr/src/app, which makes /usr/src the repository root.
COPY --chown=app:app ./course/collections/ /usr/src/course/collections/
COPY --chown=app:app ./course/_data/ /usr/src/course/_data/
# The editions that came before, whose pages this one has to be able to account
# for: `ArchiDep.CourseSite.Archives` compiles the mapping and refuses one it
# cannot resolve.
COPY --chown=app:app ./course/archives/ /usr/src/course/archives/
# The partials too: a page names its headings by being rendered, and it is the
# tags of the course that include them rather than its documents.
COPY --chown=app:app ./course/_includes/ /usr/src/course/_includes/

COPY ./.git/ /tmp/.git/
RUN cat /tmp/.git/HEAD | grep '^ref: refs\/heads\/' | sed 's/^ref: refs\/heads\///' > /usr/src/app/.git-branch && \
    touch /usr/src/app/.git-dirty && \
    cat /tmp/.git/HEAD | awk '{print "/tmp/.git/"$2}' | xargs cat > /usr/src/app/.git-revision

RUN mix ua_inspector.download --force

# The digested assets, which are the whole of what this application serves
# statically: the course material site is a build of its own, published by the
# stage below and put in front of users by a separate static server.
COPY --chown=app:app --from=digest /build/digest/priv/static/ /usr/src/app/priv/static/

RUN mix sentry.package_source_code && \
    mix release

############################
### Course material site ###
############################
FROM release AS site

WORKDIR /usr/src/app
USER app:app

# The release stage brings the three inputs the compiled model of the course
# reads; a build reads the course whole, and these are the rest of it: the page
# introducing it, and the marks it publishes at its mount point.
COPY --chown=app:app ./course/index.md /usr/src/course/index.md
COPY --chown=app:app ./course/favicon.ico /usr/src/course/favicon.ico
COPY --chown=app:app ./course/favicons/ /usr/src/course/favicons/

# What this build is is stated entirely by the `course_site` configuration: the
# edition this deployment holds, what it calls that edition, which build of it
# the dashboard's own search dialog is going to ask for, and where the generated
# PDFs of it are published. Nothing about a production build is decided here.
RUN mix archidep.course_site.build --output tmp/course_site --clean

###################
### Application ###
###################
FROM elixir:1.19.5-otp-28-alpine AS app

WORKDIR /archidep

ENV ARCHIDEP_UID=42000 \
    ARCHIDEP_GID=42000 \
    ARCHIDEP_WEB_ENDPOINT_UPLOADS_DIRECTORY=/var/lib/archidep/uploads \
    GOSU_VERSION=1.17 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod

RUN apk add --no-cache \
      ca-certificates \
      libstdc++ \
      musl-locales \
      ncurses \
      openssh-client \
      openssl \
      python3 \
      shadow \
      tzdata \
    && \
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

# Install the pinned Ansible from the single source of truth also consumed by
# the external-tool compatibility test, rather than Alpine's rolling `ansible`
# package, so the JSON/JSONL callback format the app parses cannot drift
# silently on a rebuild. `ansible-core` installs from musllinux wheels (no build
# toolchain), and `ansible.posix` (which owns the callbacks) goes to the
# system-wide collections path so it resolves for the runtime `archidep` user.
COPY ./requirements.txt ./requirements.yml ./
RUN apk add --no-cache --virtual .ansible-build-deps py3-pip && \
    pip install --no-cache-dir --break-system-packages -r requirements.txt && \
    ansible-galaxy collection install -r requirements.yml -p /usr/share/ansible/collections && \
    apk del --no-network .ansible-build-deps && \
    rm -f requirements.txt requirements.yml

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
# A build's output directory is its mount point, so what it wrote is what this
# serves, as it stands.
COPY --from=site /usr/src/app/tmp/course_site/ /var/www/html
