# mmt-image

A self-contained Docker service that bundles the Montimage **MMT** toolchain —
[`mmt-dpi`](https://github.com/montimage/mmt-dpi),
[`mmt-security`](https://github.com/montimage/mmt-security) and
[`mmt-probe`](https://github.com/montimage/mmt-probe) — behind a single command.

Give it a PCAP file; it runs `mmt-probe` (deep packet inspection + LTL rule-based
detection) over the trace and writes the resulting reports to a file (or any
other channel `mmt-probe` supports).

## Build

```bash
docker build -t mmt-image images/mmt-image
```

The image is built on `ubuntu:24.04` in two stages. The builder compiles the MMT
modules from source in the mandatory order **mmt-dpi → mmt-security → mmt-probe**
into `/opt/mmt`; the runtime stage carries only `/opt/mmt` plus the shared
libraries `mmt-probe` links.

### Build arguments

| ARG | Default | Purpose |
|-----|---------|---------|
| `MMT_DPI_REF` | `main` | git ref (branch/tag/commit) of mmt-dpi |
| `MMT_SECURITY_REF` | `main` | git ref of mmt-security |
| `MMT_PROBE_REF` | `main` | git ref of mmt-probe |
| `MMT_PROBE_MODULES` | `SECURITY_MODULE PCAP_DUMP_MODULE SOCKET_MODULE QOS_MODULE` | mmt-probe modules to compile in |

The default module set needs **no** third-party source libraries, so the image
builds quickly and reliably. To enable the Redis / Kafka / MongoDB / MQTT output
channels, add the matching modules **and** their build dependencies — see
["Enabling more output channels"](#enabling-more-output-channels).

## Usage

The image's entrypoint is the `mmt-image` wrapper. Mount an input directory and
an output directory, then point it at a PCAP:

```bash
docker run --rm \
    -v "$PWD/in:/data/input:ro" \
    -v "$PWD/out:/data/output" \
    mmt-image -p /data/input/capture.pcap -o /data/output
```

`mmt-probe` writes its report files (CSV) into `/data/output`.

### Options

```
mmt-image -p <pcap> [options] [-- <extra mmt-probe args>]

  -p, --pcap FILE       Input PCAP/trace file for offline analysis (required).
  -o, --output-dir DIR  Directory for report files (enables file-output).
                        Default: /data/output
  -c, --config FILE     mmt-probe config file.
                        Default: /opt/mmt/probe/mmt-probe.conf
  -l, --log FILE        Also write mmt-probe's runtime log to FILE.
  -X attr=value         Pass a config override to mmt-probe (repeatable).
  --no-file-output      Don't auto-enable file-output (when using another channel).
  --raw ...             Pass everything after verbatim to mmt-probe.
  -h, --help / -V, --version
```

### Examples

```bash
# Offline PCAP -> CSV reports, capturing the run log too
docker run --rm -v "$PWD/in:/data/input:ro" -v "$PWD/out:/data/output" \
    mmt-image -p /data/input/capture.pcap -o /data/output -l /data/output/run.log

# Send reports to a Redis channel instead of files
#   (requires an image built with REDIS_MODULE)
docker run --rm --network mmtnet -v "$PWD/in:/data/input:ro" \
    mmt-image -p /data/input/capture.pcap --no-file-output \
              -X redis-output.enable=true -X redis-output.hostname=redis

# Full manual control — the wrapper just execs mmt-probe
docker run --rm -v "$PWD/in:/data/input:ro" -v "$PWD/out:/data/output" \
    mmt-image --raw -c /opt/mmt/probe/mmt-probe.conf -t /data/input/capture.pcap

# Inspect the bundled mmt-probe directly
docker run --rm --entrypoint mmt-probe mmt-image -v
```

## How it works

- The wrapper runs `mmt-probe -c <config> -t <pcap>`. The `-t` flag forces
  `mmt-probe` into offline analysis mode.
- By default it appends `-X file-output.enable=true -X file-output.output-dir=<out>/`
  so reports land in the mounted output directory using the installed default
  config (`/opt/mmt/probe/mmt-probe.conf`) as a base.
- Every mmt-probe config attribute can be overridden on the command line with
  `-X <section>.<attr>=<value>`, so no config editing is required for common cases.

## Enabling more output channels

The channels below are configured in the mmt-probe config (or via `-X`) but are
only available if the image was built with the corresponding module. To add
them, extend the `Dockerfile` builder stage with the third-party libraries from
the upstream [`install-from-source.sh`](https://github.com/montimage/mmt-probe/blob/main/script/install-from-source.sh)
and rebuild with an extended `MMT_PROBE_MODULES`:

| Channel | Module | Extra build deps |
|---------|--------|------------------|
| file    | `PCAP_DUMP_MODULE` | *(built in)* |
| socket  | `SOCKET_MODULE`    | *(built in)* |
| redis   | `REDIS_MODULE`     | hiredis (from source) |
| kafka   | `KAFKA_MODULE`     | librdkafka + `libsasl2-dev libssl-dev` |
| mongodb | `MONGODB_MODULE`   | mongo-c-driver + `libssl-dev libsasl2-dev` |
| mqtt    | `MQTT_MODULE`      | `libpaho-mqtt-dev` |

```bash
docker build -t mmt-image \
    --build-arg MMT_PROBE_MODULES="SECURITY_MODULE PCAP_DUMP_MODULE SOCKET_MODULE QOS_MODULE REDIS_MODULE KAFKA_MODULE" \
    images/mmt-image
```

## Testing

```bash
# builds nothing — runs against an existing local tag
IMAGE=mmt-image tests/smoke-test.sh
```

The smoke test runs `mmt-probe -v`, checks the wrapper responds, and processes
`tests/sample.pcap` end-to-end, asserting that report files are produced. It uses
`docker create`/`docker cp` (not bind mounts) so it works identically under plain
Docker and docker-in-docker (GitLab CI).

`tests/sample.pcap` is a tiny deterministic capture (DNS + a TCP/HTTP flow)
generated by `tests/make-sample-pcap.py` (pure stdlib, no dependencies):

```bash
python3 tests/make-sample-pcap.py tests/sample.pcap
```

## CI

Built, smoke-tested and published by both pipelines:

- **GitHub Actions** — [`.github/workflows/images.yml`](../../.github/workflows/images.yml) → GHCR
- **GitLab CI** — [`.gitlab-ci.yml`](../../.gitlab-ci.yml) → GitLab Container Registry
