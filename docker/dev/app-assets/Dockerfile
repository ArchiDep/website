FROM node:24.4.0-alpine

RUN apk add --no-cache bash && \
    addgroup -S archidep && \
    adduser -D -G archidep -H -h /home/archidep -S archidep && \
    mkdir -p /archidep/app/assets /home/archidep && \
    chown -R archidep:archidep /archidep /home/archidep

WORKDIR /archidep
USER archidep:archidep

COPY ./docker/dev/app-assets/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=6 --interval=5s --timeout=10s --start-period=60s --start-interval=5s CMD ["test", "-f", "/archidep/app/priv/static/assets/app/app.js"]
