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
## Every stage that needs the dependencies takes them from here rather than from
## `app-deps`: when the build-arg names a registry image, the two stages above
## drop out of the graph entirely and nothing resolves dependencies a second
## time. It carries the sources as well as the compiled artifacts, so the asset
## stages below get from it what they would have got from `app-deps`.
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
COPY --chown=build:build --from=app-deps-image /build/deps/ /build/app/deps/

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

COPY --chown=build:build --from=app-deps-image /build/deps/ /build/app/deps/
COPY --chown=build:build ./app/lib/ /build/app/lib/
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

# The user agent database, fetched here rather than after the application source
# below so that the layer holding it is keyed on the dependencies alone: a build
# that changes only the application reuses it instead of going back out to a
# remote source that regularly times out. Only the task doing the downloading is
# copied in — it is written to need neither the rest of the application nor its
# configuration — and the cache mount is what it falls back on when the download
# fails.
COPY --chown=app:app ./app/lib/mix/tasks/archidep/ua_inspector/ /usr/src/app/lib/mix/tasks/archidep/ua_inspector/
RUN --mount=type=cache,target=/cache,mode=0777 \
    ARCHIDEP_UA_INSPECTOR_CACHE_DIR=/cache mix archidep.ua_inspector.download

COPY --chown=app:app ./app/ /usr/src/app/

# The course material the application compiles its model of the course from.
# `ArchiDep.CourseSite.Material` resolves it relative to its own source file, so
# the repository layout has to be reproduced here: the working directory is
# /usr/src/app, which makes /usr/src the repository root.
COPY --chown=app:app ./course/chapters/ /usr/src/course/chapters/
COPY --chown=app:app ./course/cheatsheets/ /usr/src/course/cheatsheets/
COPY --chown=app:app ./course/course.yml /usr/src/course/course.yml
# The editions that came before, whose pages this one has to be able to account
# for: `ArchiDep.CourseSite.Archives` compiles the mapping and refuses one it
# cannot resolve, and `archives.yml` is where it is told about the pages that
# have moved since.
COPY --chown=app:app ./course/archives/ /usr/src/course/archives/
COPY --chown=app:app ./course/archives.yml /usr/src/course/archives.yml
# The partials too: a page names its headings by being rendered, and it is the
# tags of the course that include them rather than its documents.
COPY --chown=app:app ./course/icons/ /usr/src/course/icons/

# What the application reports itself as, and what the source code links of the
# course material site it renders point at. A build that already knows is
# believed; one that does not reads the checkout, which `.dockerignore` reduces
# to `HEAD` and `refs/`. `git` is installed in this stage but cannot answer
# this: no object database comes along for it to resolve a commit against.
ARG ARCHIDEP_GIT_BRANCH=""
ARG ARCHIDEP_GIT_REVISION=""

COPY ./.git/ /tmp/.git/

# A detached `HEAD` — what `actions/checkout` leaves behind when it is given a
# commit rather than a branch — names no branch and holds the commit itself.
# `ArchiDep.Helpers.GitHelpers` reads the empty branch that leaves as `HEAD`,
# which is why the branch is worth passing in and the revision never is.
RUN set -eu; \
    head="$(cat /tmp/.git/HEAD)"; \
    branch="${ARCHIDEP_GIT_BRANCH:-}"; \
    revision="${ARCHIDEP_GIT_REVISION:-}"; \
    case "${head}" in \
      "ref: "*) \
        ref="${head#ref: }"; \
        [ -n "${branch}" ] || branch="${ref#refs/heads/}"; \
        [ -n "${revision}" ] || revision="$(cat "/tmp/.git/${ref}" 2>/dev/null || true)" ;; \
      *) \
        [ -n "${revision}" ] || revision="${head}" ;; \
    esac; \
    [ -n "${revision}" ] || { \
      echo "Could not determine the Git revision: /tmp/.git/HEAD is '${head}' and the ref it names is not in the build context, which a packed one would not be. Pass --build-arg ARCHIDEP_GIT_REVISION." >&2; \
      exit 1; \
    }; \
    printf '%s\n' "${branch}" > /usr/src/app/.git-branch; \
    printf '%s\n' "${revision}" > /usr/src/app/.git-revision; \
    touch /usr/src/app/.git-dirty

# The digested assets. They are both what this application serves statically and
# what a build of the course material site carries a copy of, that build being
# run by the application itself once it is running.
COPY --chown=app:app --from=digest /build/digest/priv/static/ /usr/src/app/priv/static/

RUN mix sentry.package_source_code && \
    mix release

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
      git \
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
    mkdir -p /etc/archidep/ssh /home/archidep /var/lib/archidep/uploads /var/lib/archidep/site && \
    chown -R archidep:archidep /archidep /home/archidep /etc/archidep /var/lib/archidep && \
    chmod 700 /archidep /etc/archidep /home/archidep /var/lib/archidep && \
    # The one directory here a different user reads: the static server in front
    # of the course material site is handed what the application renders into
    # it.
    chmod 755 /var/lib/archidep/site

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
COPY ./docker/archives.sh /usr/local/bin/archives.sh

# The course material a build reads.
COPY ./course/chapters/ /usr/share/archidep/course/chapters/
COPY ./course/cheatsheets/ /usr/share/archidep/course/cheatsheets/
COPY ./course/images/ /usr/share/archidep/course/images/
COPY ./course/icons/ /usr/share/archidep/course/icons/
COPY ./course/favicons/ /usr/share/archidep/course/favicons/
COPY ./course/course.yml ./course/index.md ./course/favicon.ico /usr/share/archidep/course/

# A build copies the files sitting next to a page out as it read them, modes
# included, into a directory a different user serves. Normalised here so that
# the umask of whoever produced the build context cannot decide whether the site
# is readable.
RUN chmod -R a+rX /usr/share/archidep/course /archidep/lib

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/archidep/bin/server"]

EXPOSE 42000
EXPOSE 42003
