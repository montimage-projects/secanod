#!/usr/bin/env bash
#
# Smoke test for a built mmt-image. Verifies that:
#   1. the mmt-probe binary runs and reports a version,
#   2. the wrapper entrypoint responds,
#   3. the wrapper processes a real PCAP end-to-end and writes report files.
#
# Data is moved with `docker create`/`docker cp` rather than host bind mounts so
# the test behaves identically under plain Docker (GitHub runners) and
# docker-in-docker (GitLab CI), where the job container and the Docker daemon do
# not share a filesystem.
#
# Usage: smoke-test.sh <image-tag>
#        IMAGE=mmt-image:ci tests/smoke-test.sh
#
set -euo pipefail

IMAGE="${1:-${IMAGE:-mmt-image:ci}}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PCAP="${HERE}/sample.pcap"
WORK="$(mktemp -d)"
CID=""
cleanup() { [[ -n "${CID}" ]] && docker rm -f "${CID}" >/dev/null 2>&1 || true; rm -rf "${WORK}"; }
trap cleanup EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

[[ -f "${PCAP}" ]] || fail "sample pcap missing at ${PCAP}"

echo "==> [1/3] mmt-probe version"
docker run --rm --entrypoint mmt-probe "${IMAGE}" -v \
    || fail "mmt-probe -v did not run"
pass "mmt-probe binary runs"

echo "==> [2/3] wrapper --help"
docker run --rm "${IMAGE}" --help | grep -q "run mmt-probe over a PCAP" \
    || fail "wrapper --help output unexpected"
pass "wrapper entrypoint responds"

echo "==> [3/3] offline PCAP analysis -> file output"
# Create (but do not start) the container, seed the input, run it, harvest output.
CID="$(docker create "${IMAGE}" \
        -p /data/input/sample.pcap -o /data/output -l /data/output/run.log)"
docker cp "${PCAP}" "${CID}:/data/input/sample.pcap"
docker start -a "${CID}" || fail "container exited non-zero"
docker cp "${CID}:/data/output/." "${WORK}/out"

echo "    output directory contents:"
ls -la "${WORK}/out" | sed 's/^/      /'

# mmt-probe writes report files into the output dir. Require at least one
# non-empty file beyond the run log we asked for.
produced="$(find "${WORK}/out" -type f ! -name run.log | wc -l)"
[[ "${produced}" -ge 1 ]] || fail "no report files were produced in the output directory"
pass "mmt-probe produced ${produced} report file(s)"

echo "==> smoke test PASSED for ${IMAGE}"
