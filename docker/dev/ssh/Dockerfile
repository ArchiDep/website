FROM elixir:1.18.4-otp-28-alpine

ARG ARCHIDEP_UID

RUN apk add --no-cache bash openssh && \
    addgroup -g "${ARCHIDEP_UID}" -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S -u "${ARCHIDEP_UID}" archidep && \
    mkdir /home/archidep && \
    chown archidep:archidep /home/archidep

WORKDIR /home/archidep
USER archidep:archidep

COPY ./docker/dev/ssh/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
