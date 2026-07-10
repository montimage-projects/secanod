# syntax=docker/dockerfile:1
#
# mmt-image — a self-contained MMT capture & detection service.
#
# Builds the Montimage MMT toolchain from source (mmt-dpi -> mmt-security ->
# mmt-probe) on Ubuntu 24.04 and packages it behind a single-command wrapper
# that runs mmt-probe over an offline PCAP and emits reports to a file (or any
# other channel mmt-probe supports).
#
# Multi-stage: a "builder" compiles everything into /opt/mmt; the runtime
# image carries only /opt/mmt plus the shared libraries mmt-probe links.

# ---------------------------------------------------------------------------
# Stage 1: builder
# ---------------------------------------------------------------------------
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive

# Git refs are pinned to "main" by default but overridable so a build can be
# reproduced against a specific commit/tag of each module.
ARG MMT_DPI_REF=main
ARG MMT_SECURITY_REF=main
ARG MMT_PROBE_REF=main

# mmt-probe output/feature modules to compile in. The default set needs NO
# third-party source libraries (hiredis / librdkafka / mongo-c / paho), so the
# build is fast and reliable. To enable REDIS_MODULE / KAFKA_MODULE /
# MONGODB_MODULE / MQTT_MODULE you must also add their build deps below (see the
# canonical mmt-probe/script/install-from-source.sh) and list them here.
ARG MMT_PROBE_MODULES="SECURITY_MODULE PCAP_DUMP_MODULE SOCKET_MODULE QOS_MODULE"

# Build dependencies for mmt-dpi + mmt-security + mmt-probe core.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates \
        build-essential gcc g++ cpp make \
        libpcap-dev libxml2-dev libconfuse-dev libnghttp2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# --- mmt-dpi (must be built first: provides libmmt_core + generated headers) ---
RUN git clone --depth 1 --branch "${MMT_DPI_REF}" https://github.com/montimage/mmt-dpi.git mmt-dpi \
    && make -C mmt-dpi/sdk -j "$(nproc)" \
    && make -C mmt-dpi/sdk install \
    && ldconfig

# --- mmt-security (needs mmt-dpi headers; must build single-threaded) ---
RUN git clone --depth 1 --branch "${MMT_SECURITY_REF}" https://github.com/montimage/mmt-security.git mmt-security \
    && make -C mmt-security clean-all \
    && make -C mmt-security -j1 \
    && make -C mmt-security install \
    && ldconfig

# --- mmt-probe (built last; links mmt-dpi + mmt-security) ---
RUN git clone --depth 1 --branch "${MMT_PROBE_REF}" https://github.com/montimage/mmt-probe.git mmt-probe \
    && make -C mmt-probe -j "$(nproc)" ${MMT_PROBE_MODULES} compile \
    && make -C mmt-probe ${MMT_PROBE_MODULES} install \
    && ldconfig

# ---------------------------------------------------------------------------
# Stage 2: runtime
# ---------------------------------------------------------------------------
FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="mmt-image" \
      org.opencontainers.image.description="Montimage MMT (mmt-dpi + mmt-security + mmt-probe) offline PCAP analysis service" \
      org.opencontainers.image.source="https://github.com/montimage-projects/secanod" \
      org.opencontainers.image.vendor="Montimage"

# Runtime shared libraries that mmt-probe links against (the *-dev packages
# from the builder are not needed here — only the runtime .so packages).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpcap0.8t64 libxml2 libconfuse2 \
        ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

# Bring across the compiled MMT toolchain and its ldconfig registration.
# The mmt-probe binary lives at /opt/mmt/probe/bin/probe; `make install`
# normally symlinks it to /usr/bin/mmt-probe, but that symlink sits outside
# /opt/mmt so we recreate it here.
COPY --from=builder /opt/mmt /opt/mmt
COPY --from=builder /etc/ld.so.conf.d/mmt-dpi.conf /etc/ld.so.conf.d/mmt-dpi.conf
RUN ln -sf /opt/mmt/probe/bin/probe /usr/bin/mmt-probe \
    && ldconfig

# Belt-and-suspenders so libraries resolve even if ld.so cache is bypassed.
ENV LD_LIBRARY_PATH=/opt/mmt/dpi/lib:/opt/mmt/security/lib

# Default I/O mount points for `docker run -v ...`.
RUN mkdir -p /data/input /data/output
VOLUME ["/data/input", "/data/output"]

COPY entrypoint.sh /usr/local/bin/mmt-image
RUN chmod +x /usr/local/bin/mmt-image

# tini reaps zombies and forwards signals cleanly; the wrapper is the service.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/mmt-image"]
CMD ["--help"]
