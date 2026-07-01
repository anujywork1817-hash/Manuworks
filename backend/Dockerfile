# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Builder
# Full Go toolchain + build dependencies
# ─────────────────────────────────────────────────────────────────────────────
FROM golang:1.22-bullseye AS builder

# Install CGO dependencies needed at compile time (gosseract needs Tesseract headers)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libtesseract-dev \
    libleptonica-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Allow Go to auto-download the toolchain version required by go.mod
ENV GOTOOLCHAIN=auto

# Copy dependency files first for better layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy all source code
COPY . .

# Build the binary
# CGO_ENABLED=1 required for gosseract (Tesseract Go bindings use CGO)
# Dynamic linking is required — Tesseract/Leptonica cannot be fully statically linked
RUN CGO_ENABLED=1 GOOS=linux go build \
    -ldflags="-s -w" \
    -trimpath \
    -o /app/docassist \
    ./cmd/server

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime
# Lean Debian image with only what's needed to run
# ─────────────────────────────────────────────────────────────────────────────
FROM debian:bullseye-slim AS runtime

# Install runtime dependencies:
# tesseract-ocr pulls in libtesseract4 + liblept5 automatically
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-mar \
    tesseract-ocr-hin \
    poppler-utils \
    ca-certificates \
    tzdata \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r docassist && useradd -r -g docassist -u 1001 docassist

# Create required directories with correct ownership
RUN mkdir -p /app/storage /app/logs && \
    chown -R docassist:docassist /app

WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/docassist .

# Switch to non-root user
USER docassist

# Expose API port (Render injects PORT env var at runtime)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:${PORT:-8080}/health || exit 1

# Start the server
ENTRYPOINT ["./docassist"]
