# Multi-stage build for the libreFS Console binary.
#
# The release workflow pre-builds the React frontend (web-app/build/) as a
# separate CI job and downloads it as an artifact before invoking this
# Dockerfile, so we skip Node here and only compile Go.
#
# Usage (CI — frontend already in web-app/build/):
#   docker build -t ghcr.io/librefs/console:latest .
#
# Usage (local full build):
#   cd web-app && yarn install && yarn build && cd ..
#   docker build -t librefs-console .

# ── Stage 1: compile Go binary ────────────────────────────────────────────
FROM golang:1.26-bookworm AS builder

WORKDIR /app

# Cache module downloads before copying source
COPY go.mod go.sum ./
RUN go mod download

# Copy source + pre-built frontend assets (web-app/build/ must exist)
COPY . .

# Declared without defaults so docker buildx injects the correct target values.
# A default value (e.g. ARG TARGETARCH=amd64) would override the injection and
# always produce an amd64 binary regardless of the requested platform.
ARG TARGETOS
ARG TARGETARCH

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath --tags=kqueue --ldflags "-s -w" \
    -o /console ./cmd/console

# ── Stage 2: minimal runtime image ───────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /console /console

EXPOSE 9090

ENTRYPOINT ["/console"]
