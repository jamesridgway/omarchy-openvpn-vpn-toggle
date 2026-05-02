#!/bin/bash
set -eEo pipefail

# Configuration
CONFIGS_PATH="${HOME}/.config/openvpn"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/vpn.pid"
CREDS_DIR="${SCRIPT_DIR}/.creds"
TOGGLE_SCRIPT="${SCRIPT_DIR}/vpn-toggle.sh"

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

write_vpn_config() {
  local vpn_name=$1
  local config_file=$2
  local user=$3
  local pass=$4

  {
    printf 'VPN_NAME=%q\n' "${vpn_name}"
    printf 'VPN_CONFIG_PATH=%q\n' "${config_file}"
    printf 'VPN_USER=%q\n' "${user}"
    printf 'VPN_PASSWORD=%q\n' "${pass}"
  } > "${SCRIPT_DIR}/vpn.conf"
}

# Find available VPN configurations (.ovpn files)
mapfile -t configs < <(find "${CONFIGS_PATH}" -maxdepth 1 -name "*.ovpn" 2>/dev/null | sort)

if [[ ${#configs[@]} -eq 0 ]]; then
  echo "No OpenVPN configurations (.ovpn files) found in ${CONFIGS_PATH}"
  exit 1
fi

# Present a selection menu
echo "Select a VPN configuration (0 to cancel):"
select vpn_config in "${configs[@]}"; do
  # Check if user entered 0 to cancel
  if [[ "${REPLY}" == "0" ]]; then
    echo "Selection cancelled"
    exit 0
  fi

  if [[ -n "${vpn_config}" ]]; then
    vpn_name="$(basename "${vpn_config}" .ovpn)"
    # Get the current VPN name
    if [[ -f "${SCRIPT_DIR}/vpn.conf" ]]; then
      if ! source "${SCRIPT_DIR}/vpn.conf" 2>/dev/null; then
        echo "Warning: Existing vpn.conf is invalid and will be replaced."
      fi
    fi

    config_file="${vpn_config}"

    # Check for credentials in comments (format: # VPN_USER=username)
    user=$(sed -n 's/^[#;]\s*VPN_USER=\(.*\)/\1/p' "${config_file}" | head -n 1 | tr -d '\r')
    pass=$(sed -n 's/^[#;]\s*VPN_PASSWORD=\(.*\)/\1/p' "${config_file}" | head -n 1 | tr -d '\r')

    # Check stored creds if not found in file
    stored_cred_file="${CREDS_DIR}/${vpn_name}.creds"
    if [[ -z "$user" ]] && [[ -f "${stored_cred_file}" ]]; then
         # Read stored
         mapfile -t stored_creds < "${stored_cred_file}"
         s_user="${stored_creds[0]}"
         s_pass="${stored_creds[1]}"

         if [[ -n "$s_user" ]]; then
             echo "Found saved credentials for ${vpn_name} (User: ${s_user})."
             read -p "Use saved credentials? [Y/n]: " use_stored
             use_stored=${use_stored:-Y}
             if [[ "$use_stored" =~ ^[Yy]$ ]]; then
                 user="$s_user"
                 pass="$s_pass"
             fi
         fi
    fi

    if [[ -z "$user" ]]; then
      # Prompt user if not found in config
      echo "Please enter credentials for ${vpn_name} (leave empty to skip):"
      read -p "Username: " user
      if [[ -n "$user" ]]; then
          read -s -p "Password: " pass
          echo ""
      fi
    else
      echo "Using credentials."
    fi

    # Save creds if we have them
    if [[ -n "$user" ]]; then
         mkdir -p "${CREDS_DIR}"
         # Save safe permissions
         old_umask=$(umask)
         umask 077
         echo "$user" > "${stored_cred_file}"
         echo "$pass" >> "${stored_cred_file}"
         umask $old_umask
    fi

    # Update vpn.conf with escaped values so special characters survive sourcing.
    write_vpn_config "${vpn_name}" "${config_file}" "${user}" "${pass}"
    echo "VPN configuration updated to ${vpn_name}"

    # If a VPN is connected, disconnect and reconnect via the toggle script
    # so connection logic lives in one place.
    if is_vpn_running; then
      current_pid=$(read_pid)
      echo "Disconnecting current VPN..."
      sudo kill "${current_pid}" 2>/dev/null || true
      rm -f "${PID_FILE}"
      rm -f "${SCRIPT_DIR}"/.vpn_auth_*

      echo "Connecting to ${vpn_name}..."
      "${TOGGLE_SCRIPT}"
    fi

    break
  else
    echo "Invalid selection."
  fi
done
