FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set workdir
WORKDIR /app

# Copy source
COPY . .

# Build
RUN cmake -S . -B build && cmake --build build

# Create data directory for persistence
RUN mkdir -p data

# Declare volume for WAL and snapshot persistence
VOLUME ["/app/data"]

# Expose HTTP port
EXPOSE 8080

# Default command: run HTTP server with WAL enabled
CMD ["./build/http_server", "--port", "8080", "--wal", "/app/data/wal.log"]
