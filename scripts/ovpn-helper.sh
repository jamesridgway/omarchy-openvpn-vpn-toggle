#!/bin/bash
# Installed as /usr/local/bin/omarchy-ovpn-helper, owned by root, mode 0755.
#
# Privileged helper invoked from the user-side vpn-toggle.sh through
# a narrow sudoers rule:
#
#     %wheel ALL=(ALL) NOPASSWD: /usr/local/bin/omarchy-ovpn-helper
#
# This binary is the *only* thing the user-side ever invokes via sudo.
# It accepts two verbs and no other arguments, so the NOPASSWD grant
# can't be repurposed to run arbitrary openvpn flags or kill arbitrary
# PIDs.

set -eEo pipefail

usage() {
  echo "Usage: omarchy-ovpn-helper {start|stop}" >&2
  exit 2
}

if [[ -z "${SUDO_USER:-}" ]] || [[ -z "${SUDO_UID:-}" ]]; then
  echo "Error: must be invoked via sudo." >&2
  exit 2
fi

if [[ $# -ne 1 ]]; then
  usage
fi

# Resolve the caller's home directory from the password database, not
# from $HOME (sudo may preserve the invoking user's $HOME, but we want
# the canonical record).
USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
if [[ -z "${USER_HOME}" ]] || [[ ! -d "${USER_HOME}" ]]; then
  echo "Error: cannot resolve home directory for ${SUDO_USER}" >&2
  exit 2
fi

OVPN_DIR="${USER_HOME}/.config/waybar/scripts/ovpn-toggle"
PID_FILE="${OVPN_DIR}/vpn.pid"
LOG_FILE="${OVPN_DIR}/vpn.log"
CONFIG_FILE="${OVPN_DIR}/vpn.conf"

# Refuse to operate on anything that isn't a regular file owned by the
# calling user. Symlinks are rejected outright so an attacker who can
# write into the user's directory can't redirect us to /etc/shadow etc.
require_user_file() {
  local path=$1
  if [[ -L "${path}" ]]; then
    echo "Error: refusing to follow symlink at ${path}" >&2
    exit 2
  fi
  if [[ ! -f "${path}" ]]; then
    echo "Error: not a regular file: ${path}" >&2
    exit 2
  fi
  local owner
  owner=$(stat -c '%u' "${path}")
  if [[ "${owner}" != "${SUDO_UID}" ]]; then
    echo "Error: ${path} is not owned by ${SUDO_USER} (uid ${SUDO_UID})" >&2
    exit 2
  fi
}

read_profile_name() {
  require_user_file "${CONFIG_FILE}"
  local raw
  raw=$(awk '
    /^VPN_NAME=/ {
      sub(/^VPN_NAME=/, "")
      print
      exit
    }
  ' "${CONFIG_FILE}")
  # The user-side writes vpn.conf via printf %q. For values matching
  # our allowlist [A-Za-z0-9._-]+, %q is a no-op (no escaping needed),
  # so we can compare the raw bytes to the regex directly. Anything
  # that came back quoted (single-ticks, backslashes, $'…' form) will
  # fail the match and be rejected.
  if [[ ! "${raw}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: VPN_NAME in vpn.conf is empty or contains disallowed characters." >&2
    exit 2
  fi
  printf '%s' "${raw}"
}

cmd=$1
case "${cmd}" in
  start)
    profile=$(read_profile_name)
    auth_file="${OVPN_DIR}/.vpn_auth_${profile}"
    temp_config="${OVPN_DIR}/.vpn_config_sanitized_${profile}.ovpn"

    require_user_file "${auth_file}"
    require_user_file "${temp_config}"

    # The auth file holds the cleartext password; insist on 0600/0400
    # before we hand it to openvpn (which will read it as root).
    auth_perms=$(stat -c '%a' "${auth_file}")
    if [[ "${auth_perms}" != "600" ]] && [[ "${auth_perms}" != "400" ]]; then
      echo "Error: ${auth_file} has insecure permissions (${auth_perms}); expected 600." >&2
      exit 2
    fi

    exec /usr/bin/openvpn \
      --config "${temp_config}" \
      --auth-user-pass "${auth_file}" \
      --auth-retry nointeract \
      --script-security 1 \
      --daemon \
      --writepid "${PID_FILE}" \
      --log "${LOG_FILE}"
    ;;
  stop)
    if [[ ! -f "${PID_FILE}" ]]; then
      echo "VPN is not running."
      exit 0
    fi
    pid=$(<"${PID_FILE}")
    if [[ ! "${pid}" =~ ^[0-9]+$ ]]; then
      echo "Error: PID file at ${PID_FILE} does not contain a numeric PID." >&2
      exit 2
    fi
    if [[ ! -d "/proc/${pid}" ]]; then
      echo "VPN process ${pid} is no longer running."
      exit 0
    fi
    # Refuse to signal anything that isn't openvpn — the PID file lives
    # under the user's home and could in principle be tampered with.
    proc_comm=$(<"/proc/${pid}/comm")
    if [[ "${proc_comm}" != "openvpn" ]]; then
      echo "Error: PID ${pid} is '${proc_comm}', refusing to kill (not openvpn)." >&2
      exit 2
    fi
    exec /usr/bin/kill "${pid}"
    ;;
  *)
    usage
    ;;
esac
