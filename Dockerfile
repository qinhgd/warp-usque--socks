# =========================================================================
# Stage 1: The Builder
# Use a Debian-based Go image for a more stable build environment.
# This stage will be discarded after the build is complete.
# =========================================================================
FROM golang:1.23-bullseye AS builder

# Install curl and tar to download and extract the source code archive.
RUN apt-get update && apt-get install -y --no-install-recommends curl tar

# Set the working directory
WORKDIR /src

# FIX: Using a more robust, two-step process to download and then extract.
# The 'curl -fL' command will fail with a clear error if the download fails (e.g., 404 Not Found).
RUN curl -fL -o usque.tar.gz https://github.com/Diniboy1123/usque/archive/refs/heads/main.tar.gz && \
    tar -xzf usque.tar.gz --strip-components=1 && \
    rm usque.tar.gz

# Build the usque binary.
# CGO_ENABLED=0 creates a static binary that can run on any Linux, including Alpine.
# -ldflags="-s -w" strips debug information, making the final binary smaller.
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /usque .


# =========================================================================
# Stage 2: The Final Image
# Use a minimal Alpine image for the final product. This image will not
# contain any Go build tools, only the final compiled program.
# =========================================================================
FROM alpine:latest

# Set the platform argument, which is needed for downloading the 'warp' tool
ARG TARGETARCH

# Install only the necessary runtime dependencies for our script
RUN apk add --no-cache \
    curl \
    gawk \
    iproute2 \
    wireguard-tools

# Copy the compiled 'usque' binary from the builder stage
COPY --from=builder /usque /usr/local/bin/usque

# Download and install the 'warp' optimization tool from the GitLab source
RUN curl -L -o /usr/local/bin/warp "https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-${TARGETARCH}" && \
    chmod +x /usr/local/bin/warp

# Copy our core run script into the final image
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

# Create the working directory for wgcf and usque configs
WORKDIR /wgcf

# Set the container's entrypoint to our run script
ENTRYPOINT ["/usr/local/bin/run.sh"]
