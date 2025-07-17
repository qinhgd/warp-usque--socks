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

# Download the source code as a tarball to avoid git clone issues in CI.
RUN curl -fL -o usque.tar.gz https://github.com/Diniboy1123/usque/archive/refs/heads/main.tar.gz && \
    tar -xzf usque.tar.gz --strip-components=1 && \
    rm usque.tar.gz

# Build the usque binary.
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /usque .


# =========================================================================
# Stage 2: The Final Image
# Use a minimal Alpine image for the final product.
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

# Download and install the 'warp' optimization tool
RUN curl -L -o /usr/local/bin/warp "https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-${TARGETARCH}" && \
    chmod +x /usr/local/bin/warp

# =========================================================================
#  FIX: Install wgcf directly into the image during build
# =========================================================================
ARG WGCF_VERSION=v2.2.19
RUN curl -fL -o /usr/local/bin/wgcf "https://github.com/ViRb3/wgcf/releases/download/${WGCF_VERSION}/wgcf_${WGCF_VERSION#v}_linux_${TARGETARCH}" && \
    chmod +x /usr/local/bin/wgcf
# =========================================================================

# Copy our core run script into the final image
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

# Create the working directory for wgcf and usque configs
WORKDIR /wgcf

# Set the container's entrypoint to our run script
ENTRYPOINT ["/usr/local/bin/run.sh"]
