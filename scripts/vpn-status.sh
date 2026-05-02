#!/bin/bash
set -eEo pipefail

# Output JSON status for Waybar
output_status() {
  local status=$1
  local tooltip=$2
  jq -nc \
    --arg s "${status}" \
    --arg t "${tooltip}" \
    '{text: "", alt: $s, class: $s, tooltip: $t}'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/vpn.pid"

read_pid() {
  [[ -f "${PID_FILE}" ]] || return 1
  local pid
  pid=$(<"${PID_FILE}")
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  echo "${pid}"
}

if [[ ! -f "${SCRIPT_DIR}/vpn.conf" ]]; then
  output_status "none" "VPN config missing: vpn.conf not found"
  exit 0
fi

if ! source "${SCRIPT_DIR}/vpn.conf" 2>/dev/null; then
  output_status "none" "VPN config invalid: vpn.conf parse error"
  exit 0
fi

if [[ -z "${VPN_NAME:-}" ]]; then
  output_status "none" "VPN not configured: VPN_NAME not set"
  exit 0
fi

if pid=$(read_pid) && ps -p "${pid}" > /dev/null 2>&1; then
  output_status "connected" "VPN Connected: ${VPN_NAME}"
else
  output_status "disconnected" "VPN Disconnected: ${VPN_NAME}"
fi
