# =========================================================================
# Stage 1: The Builder
# Use the official Go image to build the 'usque' binary from source.
# This stage will be discarded after the build is complete.
# =========================================================================
FROM golang:1.22-alpine AS builder

# Install git, which is required to clone the source code
RUN apk add --no-cache git

# Set the working directory
WORKDIR /src

# =========================================================================
#  FIX: The original repository was deleted. Cloning from a community fork.
# =========================================================================
RUN git clone https://github.com/eza-community/usque.git .

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
