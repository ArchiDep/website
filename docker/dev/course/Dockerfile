FROM ruby:3.4.4-alpine

RUN apk add --no-cache bash g++ make nodejs npm && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir /archidep /home/archidep /var/lib/archidep && \
    chown archidep:archidep /archidep /home/archidep /var/lib/archidep

WORKDIR /archidep/course
USER archidep:archidep

COPY ./docker/dev/course/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=12 --interval=5s --timeout=10s --start-period=240s --start-interval=5s CMD ["test", "-f", "/archidep/app/priv/static/archidep.json"]
