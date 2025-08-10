FROM elixir:1.18.4-otp-28-alpine

RUN apk add --no-cache bash openssh && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir /home/archidep && \
    chown archidep:archidep /home/archidep

WORKDIR /home/archidep
USER archidep:archidep

COPY ./docker/dev/ssh/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
