# secAnoD

**AI-driven Network Anomaly and Attack Detection** — a [SECASSURED](https://secureflow.assist.ro/secassured)
security service.

secAnoD combines deep packet inspection, rule-based detection, and LLM/SLM-based
detection to identify cybersecurity incidents in monitored networks and to
produce explainable alerts for downstream response and orchestration tools.

This repository delivers secAnoD as a set of **containerized services** — each
subcomponent is packaged as a Docker image with a single, well-defined command.
You run the services you need and compose them into a detection pipeline.

> **New here?** For the full component description — C4 architecture,
> subcomponents, interfaces and data flows — see **[docs/overview.md](docs/overview.md)**.

---

## Services

Each service lives under [`images/`](images/) and is built and published
independently by CI. secAnoD is being delivered incrementally; the table below
tracks what is available today and what is planned.

| Service (image) | Subcomponent | Role | Status |
|-----------------|--------------|------|--------|
| **`mmt-image`** | mmt-probe + mmt-dpi + mmt-security | Capture & detection: DPI attribute extraction and LTL rule-based detection over PCAP/live traffic | ✅ Available |
| `mmt-operator` | mmt-operator | Visualization: dashboards, stats/alert persistence, probe management | 🚧 Planned |
| `llm-detection-engine` | LLM Detection Engine | Anomaly classification, APT detection, incident prediction, LTL rule generation | 🚧 Planned |
| `api-gateway` | API Gateway | FastAPI REST endpoints for alerts/stats/config; STIX egress to secAISOAR | 🚧 Planned |
| `xai-module` | XAI Module | Root-cause analysis and human-readable explanations | 🚧 Planned |
| `event-store` | Event Store | Time-series storage for baselines, alerts and training data | 🚧 Planned |

Service and image names for planned components are indicative and may change as
they land. See [images/README.md](images/README.md) for the directory layout and
how a new service is added.

---

## Using the services

Every secAnoD service follows the same conventions, so once you know one you
know them all:

- It ships as a Docker image under `images/<service>/`.
- It has a **single entrypoint command** with `--help`.
- It reads inputs from and writes outputs to mounted `/data` volumes and/or
  Kafka/REST channels (per the [interfaces](docs/overview.md#6-interfaces--apis)).
- It is built, smoke-tested and published by CI (see [CI](#how-services-are-built-and-published-ci)).

### Getting an image

Images are published on every push to `main` and on every `v*` tag. Pull a
pre-built image, or build it locally.

**Pull from GitHub Container Registry (GHCR):**

```bash
docker pull ghcr.io/montimage-projects/mmt-image:latest
```

**Pull from the GitLab Container Registry** (SECASSURED instance):

```bash
# <registry-host> is the Container Registry of this GitLab project
docker pull <registry-host>/secassured/secassured-technical-components/secanod/mmt-image:latest
```

Available tags: `latest` (default branch), the branch name, a short commit SHA
(`sha-abc1234`), and — on releases — the version (`1.2.3`).

**Build locally:**

```bash
git clone https://github.com/montimage-projects/secanod.git
cd secanod
docker build -t mmt-image images/mmt-image     # swap in any service under images/
```

---

## Quick start — `mmt-image` (offline PCAP analysis)

`mmt-image` is the first available service. It runs `mmt-probe` (embedding
`mmt-dpi` and `mmt-security`) over a capture and writes detection reports.

Mount an input directory (your captures) and an output directory (for the
reports), then point it at a `.pcap`:

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

Afterwards `out/` contains the CSV report(s) and, if requested, `run.log`:

```
out/
├── 1783665335.625120_0_data.csv       # mmt-probe report
├── 1783665335.625120_0_data.csv.sem
└── run.log
```

Reports can also be streamed to Redis / Kafka / MongoDB / socket channels via
`-X <section>.<attr>=<value>` overrides. See the full option reference, output
channels and build options in **[images/mmt-image/README.md](images/mmt-image/README.md)**.

---

## How services are built and published (CI)

Both pipelines build every image under `images/*`, run its smoke test on each
change, and publish to their respective registries on `main` and `v*` tags:

| Pipeline | Config | Registry |
|----------|--------|----------|
| GitHub Actions | [`.github/workflows/images.yml`](.github/workflows/images.yml) | GHCR |
| GitLab CI | [`.gitlab-ci.yml`](.gitlab-ci.yml) | GitLab Container Registry |

Both pipelines are matrix-based, so adding a new service is a one-line change.
Pull requests / merge requests build and smoke-test images but do **not**
publish them.

---

## Repository layout

```
.
├── README.md                 # this guide
├── docs/
│   └── overview.md           # secAnoD component & architecture description
├── images/                   # one directory per service image
│   ├── README.md             # the service pattern + how to add a new one
│   └── mmt-image/            # capture & detection service (available)
│       ├── Dockerfile
│       ├── entrypoint.sh
│       ├── README.md
│       └── tests/
├── .github/workflows/images.yml
└── .gitlab-ci.yml
```

New services are added as `images/<service>/` and registered in the two CI
matrices; the rest of the tooling picks them up automatically.

---

## About

- **Project:** [SECASSURED](https://secureflow.assist.ro/secassured) (Horizon Europe, GA No. 101225858)
- **Work package:** WP3 (SecDevTwin & SecDev services); contributes detection to WP4 (SecOpsTwin)
- **Developed by:** MONTIMAGE (MTI), NTNU, TECNALIA (TEC)
- **Built on:** [mmt-dpi](https://github.com/montimage/mmt-dpi) ·
  [mmt-security](https://github.com/montimage/mmt-security) ·
  [mmt-probe](https://github.com/montimage/mmt-probe)

The SECASSURED project has received funding from the European Union's Horizon
Europe research and innovation programme under grant agreement No. **101225858**.

## License

See the project consortium agreement. License to be confirmed with the
coordinator (SINTEF).
