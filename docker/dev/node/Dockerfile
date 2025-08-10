FROM node:24.4.0-alpine

RUN apk add --no-cache bash rsync && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir /archidep /etc/archidep /home/archidep && \
    chown archidep:archidep /archidep /etc/archidep /home/archidep

WORKDIR /archidep
USER archidep:archidep

COPY ./docker/dev/node/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
