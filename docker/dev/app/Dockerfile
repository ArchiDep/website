FROM elixir:1.18.4-otp-28-alpine

RUN apk add --no-cache bash git inotify-tools nodejs npm && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir -p /home/archidep /archidep/app/config /archidep/app/priv /var/lib/archidep && \
    chown -R archidep:archidep /home/archidep /archidep /var/lib/archidep

WORKDIR /archidep
USER archidep:archidep

COPY ./docker/dev/app/deps.sh /usr/local/bin/deps.sh
COPY ./docker/dev/app/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
