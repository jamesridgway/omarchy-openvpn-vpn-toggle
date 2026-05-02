#!/bin/bash
set -eEo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/vpn.conf"
PID_FILE="${SCRIPT_DIR}/vpn.pid"
LOG_FILE="${SCRIPT_DIR}/vpn.log"
CONNECT_TIMEOUT_SECONDS="${VPN_CONNECT_TIMEOUT_SECONDS:-30}"

read_pid() {
  [[ -f "${PID_FILE}" ]] || return 1
  local pid
  pid=$(<"${PID_FILE}")
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  echo "${pid}"
}

is_vpn_running() {
  local pid
  pid=$(read_pid) || return 1
  ps -p "${pid}" > /dev/null 2>&1
}

require_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: VPN config missing at ${CONFIG_FILE}."
    echo "Run vpn-select.sh (right-click in Waybar) to configure a profile."
    exit 1
  fi

  # shellcheck disable=SC1090
  if ! source "${CONFIG_FILE}" 2>/dev/null; then
    echo "Error: Invalid VPN config format in ${CONFIG_FILE}."
    echo "Run vpn-select.sh (right-click) to rewrite the config."
    exit 1
  fi

  if [[ -z "${VPN_NAME:-}" ]] || [[ -z "${VPN_CONFIG_PATH:-}" ]]; then
    echo "Error: VPN not configured in ${CONFIG_FILE}."
    echo "Run vpn-select.sh (right-click in Waybar) to pick a profile."
    exit 1
  fi
}

if is_vpn_running; then
  pid=$(read_pid)
  echo "Stopping VPN..."
  sudo kill "${pid}"
  rm -f "${PID_FILE}"
  rm -f "${SCRIPT_DIR}"/.vpn_auth_*
  echo "VPN disconnected"
else
  require_config

  config_file="${VPN_CONFIG_PATH}"

  if ! test -f "${config_file}"; then
    echo "Error: Config file not found: ${config_file}"
    exit 1
  fi

  AUTH_OPTS=()
  auth_file=""
  if [[ -n "${VPN_USER}" ]] && [[ -n "${VPN_PASSWORD}" ]]; then
    auth_file="${SCRIPT_DIR}/.vpn_auth_${VPN_NAME}"
    ( umask 077; printf '%s\n%s\n' "${VPN_USER}" "${VPN_PASSWORD}" > "${auth_file}" )
    AUTH_OPTS+=("--auth-user-pass" "${auth_file}")
  else
    echo "No credentials found in vpn.conf."
  fi

  echo "Starting VPN..."

  temp_config="${SCRIPT_DIR}/.vpn_config_sanitized_${VPN_NAME}.ovpn"

  if [[ ${#AUTH_OPTS[@]} -gt 0 ]]; then
    sed -E \
      '/^[[:space:]]*(up|down)[[:space:]]+\/etc\/openvpn\/update-resolv-conf/d; /^[[:space:]]*auth-user-pass([[:space:]]+.*)?$/d' \
      "${config_file}" > "${temp_config}"
  else
    sed -E \
      '/^[[:space:]]*(up|down)[[:space:]]+\/etc\/openvpn\/update-resolv-conf/d' \
      "${config_file}" > "${temp_config}"

    if grep -Eq '^[[:space:]]*auth-user-pass[[:space:]]*$' "${config_file}"; then
      echo "Error: This profile requires username/password input."
      echo "Run vpn-select.sh (right-click) and save credentials first."
      rm -f "${temp_config}"
      exit 1
    fi
  fi

  rm -f "${LOG_FILE}" 2>/dev/null || true
  if ! : > "${LOG_FILE}"; then
    echo "Error: Cannot write VPN log file at ${LOG_FILE}"
    rm -f "${temp_config}"
    exit 1
  fi
  chmod 600 "${LOG_FILE}"

  if ! sudo openvpn --config "${temp_config}" \
      "${AUTH_OPTS[@]}" \
      --auth-retry nointeract \
      --daemon \
      --writepid "${PID_FILE}" \
      --log "${LOG_FILE}"; then
    echo "Error: Failed to start OpenVPN process."
    echo "Check permissions or config validity."
    rm -f "${temp_config}"
    exit 1
  fi

  sleep 1
  if ! is_vpn_running; then
    echo "Failed to start VPN process."
    [[ -f "${LOG_FILE}" ]] && tail -n 10 "${LOG_FILE}"
    rm -f "${temp_config}"
    rm -f "${PID_FILE}"
    exit 1
  fi

  count=0
  while [[ ${count} -lt ${CONNECT_TIMEOUT_SECONDS} ]]; do
    if grep -q "Initialization Sequence Completed" "${LOG_FILE}"; then
      echo "VPN connection successful"
      tail -n 1 "${LOG_FILE}"
      rm -f "${temp_config}"
      exit 0
    fi

    if ! is_vpn_running; then
      break
    fi

    if grep -Eq "AUTH_FAILED|Options error|Exiting due to fatal error|Cannot resolve host address" "${LOG_FILE}"; then
      break
    fi

    sleep 1
    count=$((count+1))
  done

  if is_vpn_running; then
    echo "VPN process is running and still initializing."
    echo "Check ${LOG_FILE} for progress."
    rm -f "${temp_config}"
    exit 0
  fi

  echo "Failed to connect to VPN."
  echo "Check ${LOG_FILE} for details:"
  if [[ -f "${LOG_FILE}" ]]; then
    tail -n 10 "${LOG_FILE}"
  fi

  if [[ -f "${PID_FILE}" ]]; then
    pid=$(read_pid || true)
    if [[ -n "${pid:-}" ]]; then
      sudo kill "${pid}" 2>/dev/null || true
    fi
    rm -f "${PID_FILE}"
  fi
  rm -f "${temp_config}"
  if [[ -n "${auth_file}" ]]; then
    rm -f "${auth_file}"
  fi
  exit 1
fi
