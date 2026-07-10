# secAnoD — MMT service images

**AI-driven Network Anomaly and Attack Detection** — a [SECASSURED](https://secureflow.assist.ro/secassured)
security service.

This repository packages Montimage's **MMT** toolchain as ready-to-run Docker
services. Give a service a network capture; it runs deep packet inspection and
rule-based detection and writes the results to a file or a streaming channel.

> Looking for the component/architecture description (C4 model, subcomponents,
> interfaces)? See **[docs/overview.md](docs/overview.md)**.

---

## Available images

Each service lives under [`images/`](images/) and is built and published
independently by CI.

| Image | What it does | Details |
|-------|--------------|---------|
| `mmt-image` | Offline **PCAP** analysis: runs `mmt-probe` (embedding `mmt-dpi` + `mmt-security`) over a capture and emits reports. | [images/mmt-image/README.md](images/mmt-image/README.md) |

More services will be added over time; see [images/README.md](images/README.md)
for the layout.

---

## Getting an image

You can either **pull** a pre-built image from a registry or **build** it
yourself.

### Pull (recommended)

Images are published on every push to `main` and on every `v*` tag.

**GitHub Container Registry (GHCR):**

```bash
docker pull ghcr.io/montimage-projects/mmt-image:latest
```

**GitLab Container Registry** (the SECASSURED instance):

```bash
# <registry-host> is the Container Registry of this GitLab project
docker pull <registry-host>/secassured/secassured-technical-components/secanod/mmt-image:latest
```

Available tags: `latest` (default branch), the branch name, a short commit SHA
(`sha-abc1234`), and — on releases — the version (`1.2.3`).

### Build locally

```bash
git clone https://github.com/montimage-projects/secanod.git
cd secanod
docker build -t mmt-image images/mmt-image
```

The build compiles the MMT modules from source on `ubuntu:24.04` in the
mandatory order **mmt-dpi → mmt-security → mmt-probe**. See the
[image README](images/mmt-image/README.md#build) for build arguments (pinning
module versions, enabling extra output channels).

---

## Quick start — analyze a PCAP with `mmt-image`

The image exposes a single command. Mount an input directory (your captures)
and an output directory (for the reports), then point it at a `.pcap`:

```bash
mkdir -p in out
cp /path/to/capture.pcap in/

docker run --rm \
    -v "$PWD/in:/data/input:ro" \
    -v "$PWD/out:/data/output" \
    ghcr.io/montimage-projects/mmt-image:latest \
    -p /data/input/capture.pcap \
    -o /data/output \
    -l /data/output/run.log
```

- `-p` — the PCAP to analyze (offline mode).
- `-o` — directory where `mmt-probe` writes its report files (CSV).
- `-l` — (optional) also capture `mmt-probe`'s runtime log to a file.

After it runs, `out/` contains the CSV report(s) and, if requested, `run.log`.

```
out/
├── 1783665335.625120_0_data.csv   # mmt-probe report
├── 1783665335.625120_0_data.csv.sem
└── run.log
```

### Other output channels

By default reports are written to files. `mmt-probe` also supports Redis, Kafka,
MongoDB and socket outputs — select them with `-X <section>.<attr>=<value>`
overrides (the image must be built with the matching module):

```bash
docker run --rm -v "$PWD/in:/data/input:ro" \
    ghcr.io/montimage-projects/mmt-image:latest \
    -p /data/input/capture.pcap --no-file-output \
    -X redis-output.enable=true -X redis-output.hostname=redis
```

See [images/mmt-image/README.md](images/mmt-image/README.md) for the full option
reference, the list of channels/modules, and `--raw` (direct `mmt-probe`
control).

### Inspect the bundled tools

```bash
# print mmt-probe / mmt-dpi / mmt-security versions
docker run --rm --entrypoint mmt-probe ghcr.io/montimage-projects/mmt-image:latest -v

# show the wrapper help
docker run --rm ghcr.io/montimage-projects/mmt-image:latest --help
```

---

## How images are built and published (CI)

Both pipelines build every image under `images/*`, run its smoke test on each
change, and publish to their respective registries on `main` and `v*` tags:

| Pipeline | Config | Registry |
|----------|--------|----------|
| GitHub Actions | [`.github/workflows/images.yml`](.github/workflows/images.yml) | GHCR |
| GitLab CI | [`.gitlab-ci.yml`](.gitlab-ci.yml) | GitLab Container Registry |

Pull requests / merge requests build and smoke-test the image but do **not**
publish it.

---

## Repository layout

```
.
├── README.md                 # this guide
├── docs/
│   └── overview.md           # secAnoD component & architecture description
├── images/                   # one directory per service image
│   ├── README.md
│   └── mmt-image/
│       ├── Dockerfile
│       ├── entrypoint.sh
│       ├── README.md
│       └── tests/
├── .github/workflows/images.yml
└── .gitlab-ci.yml
```

---

## About

- **Project:** [SECASSURED](https://secureflow.assist.ro/secassured) (Horizon Europe, GA No. 101225858)
- **Developed by:** MONTIMAGE (MTI), NTNU, TECNALIA (TEC)
- **Built on:** [mmt-dpi](https://github.com/montimage/mmt-dpi) ·
  [mmt-security](https://github.com/montimage/mmt-security) ·
  [mmt-probe](https://github.com/montimage/mmt-probe)
