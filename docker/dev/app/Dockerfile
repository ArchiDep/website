FROM elixir:1.18.4-otp-28-alpine

RUN apk add --no-cache bash git inotify-tools nodejs npm && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir /home/archidep /archidep /var/lib/archidep && \
    chown archidep:archidep /home/archidep /archidep /var/lib/archidep

WORKDIR /archidep
USER archidep:archidep

# ENV ECTO_IPV6 true
# ENV ERL_AFLAGS "-proto_dist inet6_tcp"

COPY ./docker/dev/app/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# COPY --chown=app:app --from=course /build/app/priv/static/archidep.json /usr/src/app/priv/static/
