# secAnoD service images

This directory holds the containerized **services** that make up secAnoD. Each
service lives in its own subdirectory and is built and published independently
by CI.

```
images/
└── mmt-image/          # MMT capture & detection service (mmt-probe + mmt-dpi + mmt-security)
    ├── Dockerfile
    ├── entrypoint.sh   # single-command wrapper
    ├── README.md
    └── tests/
        ├── sample.pcap
        ├── make-sample-pcap.py
        └── smoke-test.sh
```

## Adding a new service

1. Create `images/<your-service>/` with a `Dockerfile`.
2. (Recommended) add `tests/smoke-test.sh` that takes an image tag as `$1` /
   `$IMAGE` and exits non-zero on failure.
3. Register the service in both pipelines by adding its name to the matrix:
   - `.github/workflows/images.yml` → `strategy.matrix.image`
   - `.gitlab-ci.yml` → `parallel.matrix.IMAGE` (in both `build_and_test` and `publish`)

Both CIs build every listed image, run its smoke test on every merge/PR, and
publish to their respective container registries (GHCR / GitLab Registry) on the
default branch and on `v*` tags.

## Current services

| Service | Purpose | Docs |
|---------|---------|------|
| `mmt-image` | Offline PCAP analysis via the MMT toolchain | [images/mmt-image/README.md](mmt-image/README.md) |
