#!/usr/bin/env bash
#
# mmt-image — single-command wrapper around mmt-probe for offline PCAP analysis.
#
# Runs mmt-probe over a PCAP trace and writes its reports to an output
# directory (file-output channel) by default. Any other channel mmt-probe
# supports (redis / kafka / mongodb / socket) can be driven through -X
# overrides or a custom config file, provided the image was built with the
# matching module.
#
# Typical use:
#   docker run --rm \
#       -v "$PWD/in:/data/input" -v "$PWD/out:/data/output" \
#       mmt-image -p /data/input/capture.pcap -o /data/output
#
set -euo pipefail

PROG="mmt-image"
MMT_PROBE_BIN="${MMT_PROBE_BIN:-mmt-probe}"
DEFAULT_CONFIG="/opt/mmt/probe/mmt-probe.conf"

usage() {
    cat <<EOF
${PROG} — run mmt-probe over a PCAP file and emit reports.

USAGE:
    ${PROG} -p <pcap> [options] [-- <extra mmt-probe args>]

OPTIONS:
    -p, --pcap FILE       Input PCAP/trace file for offline analysis (required
                          unless --raw is used).
    -o, --output-dir DIR  Directory for mmt-probe report files. Enables the
                          file-output channel. Default: /data/output
    -c, --config FILE     mmt-probe config file.
                          Default: ${DEFAULT_CONFIG}
    -l, --log FILE        Also write mmt-probe's runtime log to FILE (stdout/
                          stderr are still shown). Default: stdout only.
    -X attr=value         Pass a config override straight to mmt-probe. Repeatable.
                          e.g. -X file-output.output-file=report
    --no-file-output      Do NOT auto-enable the file-output channel (use when
                          your config/-X selects redis/kafka/mongodb/socket).
    --raw ...             Pass every remaining argument verbatim to mmt-probe and
                          skip all wrapper defaults. For full manual control.
    -h, --help            Show this help.
    -V, --version         Show mmt-probe version and exit.

EXAMPLES:
    # Offline PCAP -> CSV report files in ./out
    ${PROG} -p /data/input/capture.pcap -o /data/output

    # Capture the run log to a file as well
    ${PROG} -p /data/input/capture.pcap -o /data/output -l /data/output/run.log

    # Send security reports to a Redis channel instead of files
    ${PROG} -p /data/input/capture.pcap --no-file-output \\
            -X redis-output.enable=true -X redis-output.hostname=redis

    # Full manual control (wrapper does nothing but exec mmt-probe)
    ${PROG} --raw -c /my/mmt-probe.conf -t /data/input/capture.pcap
EOF
}

die() { echo "${PROG}: error: $*" >&2; exit 2; }

# --- argument parsing -------------------------------------------------------
PCAP=""
OUTPUT_DIR="/data/output"
CONFIG="${DEFAULT_CONFIG}"
LOG_FILE=""
FILE_OUTPUT=1
declare -a OVERRIDES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pcap)        PCAP="${2:-}"; shift 2 ;;
        -o|--output-dir)  OUTPUT_DIR="${2:-}"; shift 2 ;;
        -c|--config)      CONFIG="${2:-}"; shift 2 ;;
        -l|--log)         LOG_FILE="${2:-}"; shift 2 ;;
        -X)               OVERRIDES+=("-X" "${2:-}"); shift 2 ;;
        --no-file-output) FILE_OUTPUT=0; shift ;;
        -h|--help)        usage; exit 0 ;;
        -V|--version)     exec "${MMT_PROBE_BIN}" -v ;;
        --raw)            shift; exec "${MMT_PROBE_BIN}" "$@" ;;
        --)               shift; OVERRIDES+=("$@"); break ;;
        *)                die "unknown argument '$1' (use --help, or --raw for direct mmt-probe args)" ;;
    esac
done

# --- validation -------------------------------------------------------------
[[ -n "${PCAP}" ]]      || { usage >&2; die "missing required --pcap <file>"; }
[[ -f "${PCAP}" ]]      || die "pcap file not found: ${PCAP}"
[[ -f "${CONFIG}" ]]    || die "config file not found: ${CONFIG}"

# --- assemble mmt-probe command ---------------------------------------------
declare -a CMD=("${MMT_PROBE_BIN}" -c "${CONFIG}" -t "${PCAP}")

if [[ "${FILE_OUTPUT}" -eq 1 ]]; then
    mkdir -p "${OUTPUT_DIR}"
    CMD+=("-X" "file-output.enable=true" "-X" "file-output.output-dir=${OUTPUT_DIR}/")
fi

if [[ ${#OVERRIDES[@]} -gt 0 ]]; then
    CMD+=("${OVERRIDES[@]}")
fi

echo "${PROG}: running: ${CMD[*]}" >&2

# --- run --------------------------------------------------------------------
if [[ -n "${LOG_FILE}" ]]; then
    mkdir -p "$(dirname "${LOG_FILE}")"
    # tee so the log is captured AND visible on the container's stdout
    "${CMD[@]}" 2>&1 | tee -a "${LOG_FILE}"
    exit "${PIPESTATUS[0]}"
else
    exec "${CMD[@]}"
fi
