FROM node:24.4.0-alpine

RUN apk add --no-cache bash && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir -p /archidep/course/assets /home/archidep && \
    chown -R archidep:archidep /archidep /home/archidep

WORKDIR /archidep
USER archidep:archidep

COPY ./docker/dev/course-assets/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=12 --interval=5s --timeout=10s --start-period=240s --start-interval=5s CMD ["test", "-f", "/archidep/app/priv/static/assets/course/manifest.json"]
