FROM alpine:3.22

ARG VERSION=v1.4.7
ARG TARGETOS=linux
ARG TARGETARCH=amd64

RUN apk add --no-cache ca-certificates curl jq su-exec tzdata \
    && addgroup -S zenmood \
    && adduser -S -G zenmood -h /data zenmood \
    && mkdir -p /app /data \
    && chown -R zenmood:zenmood /app /data

WORKDIR /app

RUN set -eux; \
    case "$TARGETOS/$TARGETARCH" in \
      linux/amd64|linux/arm64) ;; \
      *) echo "Unsupported release target: $TARGETOS/$TARGETARCH" >&2; exit 1 ;; \
    esac; \
    archive="opencode2api_${VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz"; \
    base="https://github.com/jasonxu114514/opencode2api/releases/download/${VERSION}"; \
    mkdir -p /tmp/release; \
    curl -fsSL "$base/$archive" -o "/tmp/release/$archive"; \
    curl -fsSL "$base/$archive.sha256" -o "/tmp/release/$archive.sha256"; \
    (cd /tmp/release && sha256sum -c "$archive.sha256"); \
    tar -xzf "/tmp/release/$archive" -C /tmp/release; \
    install -m 0755 "/tmp/release/opencode2api_${VERSION}_${TARGETOS}_${TARGETARCH}/opencode2api" /usr/local/bin/opencode2api; \
    rm -rf /tmp/release

COPY config.json /app/config.template.json
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENV PORT=8080 \
    STATE_DIR=/data \
    CONFIG_PATH=/data/config.json

EXPOSE 8080
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --retries=3 \
    CMD wget -q -O /dev/null "http://127.0.0.1:${PORT:-8080}/healthz" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
