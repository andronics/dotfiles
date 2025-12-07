FROM archlinux:latest

# Update system and install required packages
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    rclone \
    systemd \
    fuse3 \
    mediainfo \
    zsh \
    jq \
    util-linux \
    file \
    bc \
    coreutils \
    && pacman -Scc --noconfirm

# Create test user
RUN useradd -m -s /bin/zsh testuser && \
    usermod -aG wheel testuser

# Setup FUSE permissions
RUN chmod u+s /usr/bin/fusermount3

# Create directory structure
RUN mkdir -p /test/{config,cache,runtime,pool/local,pool/remote} && \
    chown -R testuser:testuser /test

# Create helper scripts (minimal stubs for testing)
RUN echo '#!/bin/zsh\ncat "$1" 2>/dev/null || echo "$2"' > /usr/local/bin/_cat && \
    chmod +x /usr/local/bin/_cat

RUN echo '#!/bin/zsh\ntouch "$1" 2>/dev/null; cat "$1" 2>/dev/null || echo "$2"' > /usr/local/bin/cat-touch && \
    chmod +x /usr/local/bin/cat-touch

RUN echo '#!/bin/zsh\necho "$1" | jq -r "$2"' > /usr/local/bin/_jq && \
    chmod +x /usr/local/bin/_jq

RUN echo '#!/bin/zsh\necho "$1" | jq -r "$2"' > /usr/local/bin/jq-query && \
    chmod +x /usr/local/bin/jq-query

RUN echo '#!/bin/zsh\nshift; echo "[$(echo $1 | tr "[:lower:]" "[:upper:]")]" "$@"' > /usr/local/bin/_log && \
    chmod +x /usr/local/bin/_log

RUN echo '#!/bin/zsh\necho "[ERROR]" "$@" >&2' > /usr/local/bin/log-error && \
    chmod +x /usr/local/bin/log-error

RUN echo '#!/bin/zsh\necho "[INFO]" "$@"' > /usr/local/bin/log-info && \
    chmod +x /usr/local/bin/log-info

RUN echo '#!/bin/zsh\necho "[DEBUG]" "$@"' > /usr/local/bin/log-debug && \
    chmod +x /usr/local/bin/log-debug

RUN echo '#!/bin/zsh\necho "[WARNING]" "$@"' > /usr/local/bin/log-warning && \
    chmod +x /usr/local/bin/log-warning

RUN echo '#!/bin/zsh\n# Stub for _math helpers\nreturn 0' > /usr/local/bin/_math && \
    chmod +x /usr/local/bin/_math

RUN echo '#!/bin/zsh\nreturn $(echo "$1 >= $2 * 0.9 && $1 <= $2 * 1.1" | bc -l)' > /usr/local/bin/math-within-percent && \
    chmod +x /usr/local/bin/math-within-percent

RUN echo '#!/bin/zsh\n# Stub for _args\ntrue' > /usr/local/bin/_args && \
    chmod +x /usr/local/bin/_args

# Switch to test user
USER testuser
WORKDIR /test

# Set environment variables
ENV XDG_CONFIG_HOME=/test/config
ENV XDG_CACHE_HOME=/test/cache
ENV XDG_RUNTIME_DIR=/test/runtime
ENV XDG_DATA_HOME=/test/data
ENV PATH=/test/bin:/usr/local/bin:$PATH

CMD ["/bin/zsh"]
