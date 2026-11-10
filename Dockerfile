# ---- Build stage: compile from the fork (WARP MTU option) ----
FROM golang:1.24-alpine AS build
ARG REPO=https://github.com/johndoe237/opencode2api.git
ARG REF=feat/warp-mtu
RUN apk add --no-cache git
WORKDIR /src
RUN git clone --depth 1 --branch "$REF" "$REPO" . \
    && git rev-parse HEAD \
    && CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o /out/opencode2api ./cmd/opencode2api

# ---- Runtime stage ----
FROM alpine:3.22

RUN apk add --no-cache \
        ca-certificates curl jq su-exec tzdata \
        iproute2 iputils iptables ip6tables bind-tools busybox-extras \
    && addgroup -S zenmood \
    && adduser -S -G zenmood -h /data zenmood \
    && mkdir -p /app /data \
    && chown -R zenmood:zenmood /app /data

WORKDIR /app

COPY --from=build /out/opencode2api /usr/local/bin/opencode2api

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
