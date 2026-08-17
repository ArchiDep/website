FROM alpine:3.22

RUN apk add --no-cache bash git && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir -p /home/archidep /archidep && \
    chown -R archidep:archidep /home/archidep /archidep

WORKDIR /archidep
USER archidep:archidep

# The same script production runs, so that how a host comes to hold the finished
# editions has one home.
COPY ./docker/archives.sh /usr/local/bin/archives.sh
COPY ./docker/dev/archives/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
