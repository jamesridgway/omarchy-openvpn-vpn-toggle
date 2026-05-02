#!/bin/bash
set -eEo pipefail

# WireGuard VPN Toggle Installer for Omarchy's Waybar
# Based on: https://github.com/basecamp/omarchy/discussions/1366
# 
# Can be used as:
# 1. Local install: ./install.sh
# 2. One-liner: curl -fsSL https://raw.githubusercontent.com/JacobusXIII/omarchy-wireguard-vpn-toggle/main/install.sh | bash
# 3. Uninstall: ./install.sh --uninstall

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# GitHub configuration for one-liner mode
GITHUB_USER="james-ridgway"
GITHUB_REPO="omarchy-openvpn-vpn-toggle"
GITHUB_BRANCH="main"

# Runtime configuration
WAYBAR_OVPN_SELECTOR="custom-ovpn"
WAYBAR_OVPN_MODULE_NAME="custom/ovpn"
WAYBAR_CONFIG_DIR="${HOME}/.config/waybar"
SCRIPTS_DIR="${WAYBAR_CONFIG_DIR}/scripts"
OVPN_SCRIPTS_DIR="${SCRIPTS_DIR}/ovpn-toggle"
VPN_CONFIGS_PATH="${HOME}/.config/openvpn"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "/tmp")"
REPO_SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
TEMP_INSTALL_DIR=""
PID_FILE="${OVPN_SCRIPTS_DIR}/vpn.pid"

# Error handling
catch_errors() {
  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    print_error "Installation failed with exit code ${exit_code}"
    # Clean up temp directory if it exists
    if [[ -n "${TEMP_INSTALL_DIR}" ]] && [[ -d "${TEMP_INSTALL_DIR}" ]]; then
      rm -rf "${TEMP_INSTALL_DIR}"
    fi
  fi
  return "${exit_code}"
}

exit_handler() {
  local exit_code=$?
  # Clean up temp directory if it exists and installation was successful
  if [[ ${exit_code} -eq 0 ]] && [[ -n "${TEMP_INSTALL_DIR}" ]] && [[ -d "${TEMP_INSTALL_DIR}" ]]; then
    rm -rf "${TEMP_INSTALL_DIR}"
  fi
  exit "${exit_code}"
}

trap catch_errors ERR INT TERM
trap exit_handler EXIT

# Print functions
print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

# Check if scripts need to be downloaded (not running from repo)
need_download() {
  # Check if scripts directory exists
  if [[ ! -d "${REPO_SCRIPTS_DIR}" ]]; then
    return 0
  fi
  
  return 1
}

# Download repository for oneliner mode
download_repository() {
  print_info "Downloading repository..."
  
  TEMP_INSTALL_DIR="/tmp/omarchy-openvpn-vpn-toggle-$$"
  
  # Try git clone first
  if command -v git &>/dev/null; then
    if git clone --depth 1 --branch "${GITHUB_BRANCH}" \
        "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" \
        "${TEMP_INSTALL_DIR}" &>/dev/null; then
      print_success "Repository downloaded via git"
      REPO_SCRIPTS_DIR="${TEMP_INSTALL_DIR}/scripts"
      return 0
    fi
  fi
  
  # Fallback to tarball download
  print_info "Downloading repository tarball..."
  local tarball_url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"
  
  mkdir -p "${TEMP_INSTALL_DIR}"
  
  if command -v curl &>/dev/null; then
    if curl -fsSL "${tarball_url}" | tar -xz -C "${TEMP_INSTALL_DIR}" --strip-components=1 2>/dev/null; then
      print_success "Repository downloaded via curl"
      REPO_SCRIPTS_DIR="${TEMP_INSTALL_DIR}/scripts"
      return 0
    fi
  elif command -v wget &>/dev/null; then
    if wget -qO- "${tarball_url}" | tar -xz -C "${TEMP_INSTALL_DIR}" --strip-components=1 2>/dev/null; then
      print_success "Repository downloaded via wget"
      REPO_SCRIPTS_DIR="${TEMP_INSTALL_DIR}/scripts"
      return 0
    fi
  fi
  
  print_error "Failed to download repository"
  print_error "Please install git, curl, or wget"
  exit 1
}

# Uninstall logic
uninstall() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}Uninstalling OpenVPN Toggle${NC}"
  echo -e "${BLUE}========================================${NC}\n"

  # 1. Remove scripts
  print_info "Removing scripts..."
  local -a scripts=("vpn-status.sh" "vpn-toggle.sh" "vpn-select.sh" "vpn.conf")
  for script in "${scripts[@]}"; do
    if [[ -f "${OVPN_SCRIPTS_DIR}/${script}" ]]; then
      rm "${OVPN_SCRIPTS_DIR}/${script}"
      print_success "Removed ${script}"
    fi
  done

  # 2. Remove from Waybar config
  print_info "Updating Waybar configuration..."
  local config_file="${WAYBAR_CONFIG_DIR}/config.jsonc"
  if [[ ! -f "${config_file}" ]]; then
    config_file="${WAYBAR_CONFIG_DIR}/config"
  fi

  if [[ -f "${config_file}" ]]; then
    local backup_file="${config_file}.backup.uninstall.$(date +%Y%m%d-%H%M%S)"
    cp "${config_file}" "${backup_file}"
    print_success "Backed up config to ${backup_file}"

    # Remove the custom module from modules-right
    if jq -e --arg m "${WAYBAR_OVPN_MODULE_NAME}" \
        '.["modules-right"] | index($m)' "${config_file}" &>/dev/null; then
      jq --arg m "${WAYBAR_OVPN_MODULE_NAME}" \
        '.["modules-right"] -= [$m]' "${config_file}" > "${config_file}.tmp"
      mv "${config_file}.tmp" "${config_file}"
      print_success "Removed ${WAYBAR_OVPN_MODULE_NAME} from modules-right"
    fi

    # Remove the custom module definition
    if jq -e --arg m "${WAYBAR_OVPN_MODULE_NAME}" \
        '.[$m]' "${config_file}" &>/dev/null; then
      jq --arg m "${WAYBAR_OVPN_MODULE_NAME}" \
        'del(.[$m])' "${config_file}" > "${config_file}.tmp"
      mv "${config_file}.tmp" "${config_file}"
      print_success "Removed ${WAYBAR_OVPN_MODULE_NAME} module definition"
    fi
  else
    print_warning "Waybar config file not found"
  fi

  # 3. Remove from Waybar styles
  print_info "Updating Waybar styles..."
  local style_file="${WAYBAR_CONFIG_DIR}/style.css"
  if [[ -f "${style_file}" ]]; then
    local backup_file="${style_file}.backup.uninstall.$(date +%Y%m%d-%H%M%S)"
    cp "${style_file}" "${backup_file}"
    print_success "Backed up style to ${backup_file}"

    if grep -q "#${WAYBAR_OVPN_SELECTOR}" "${style_file}"; then
      # Precise two-line removal of the selector pair we wrote at install time.
      sed -i -e "/#custom-omarchy,/{N;s/#custom-omarchy,\n#${WAYBAR_OVPN_SELECTOR}/#custom-omarchy/}" "${style_file}"
      # Fallback cleanup if the exact match failed (e.g. user modified it).
      if grep -q "#${WAYBAR_OVPN_SELECTOR}" "${style_file}"; then
         sed -i "/#${WAYBAR_OVPN_SELECTOR}/d" "${style_file}"
      fi
      print_success "Removed #${WAYBAR_OVPN_SELECTOR} from style.css"
    fi
  else
    print_warning "style.css not found"
  fi

  # 4. Remove sudoers rule
  if [[ -f "/etc/sudoers.d/openvpn-vpn-toggle" ]]; then
    print_info "Removing sudoers rule..."
    if sudo rm "/etc/sudoers.d/openvpn-vpn-toggle"; then
      print_success "Removed /etc/sudoers.d/openvpn-vpn-toggle"
    else
      print_error "Failed to remove sudoers rule"
    fi
  fi

  echo ""
  print_success "Uninstallation complete!"
  restart_waybar
  exit 0
}

# Main installation logic
main() {
  # Check for uninstall flag
  if [[ "$1" == "--uninstall" ]]; then
    uninstall
  fi

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}OpenVPN Toggle for Omarchy${NC}"
  echo -e "${BLUE}========================================${NC}\n"

  # Download repository if scripts not present
  if need_download; then
    print_info "Running in one-liner mode"
    download_repository
    echo ""
  fi

  # Check if running as root
  if [[ ${EUID} -eq 0 ]]; then
    print_error "Please do not run this script as root. It will prompt for sudo when needed."
    exit 1
  fi

  check_dependencies
  check_openvpn_configs
  create_waybar_directory
  verify_repo_scripts
  install_scripts
  create_vpn_config
  update_waybar_config
  update_waybar_styles
  configure_firewall
  configure_sudoers
  show_completion_message
  restart_waybar
}
check_dependencies() {
  print_info "Checking dependencies..."

  local -a dependencies=("openvpn" "waybar" "jq")
  local -a missing_deps=()

  if ! command -v openvpn &>/dev/null; then
    missing_deps+=("openvpn")
  fi

  if ! command -v waybar &>/dev/null; then
    missing_deps+=("waybar")
  fi

  if ! command -v jq &>/dev/null; then
    missing_deps+=("jq")
  fi

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    print_error "Missing dependencies: ${missing_deps[*]}"
    echo ""
    print_info "Install missing dependencies:"
    echo "  sudo pacman -S openvpn waybar jq"
    exit 1
  fi

  print_success "All dependencies are installed"
}

check_openvpn_configs() {
  print_info "Checking for OpenVPN configurations..."

  if [[ ! -d "${VPN_CONFIGS_PATH}" ]]; then
    print_warning "OpenVPN configuration directory not found: ${VPN_CONFIGS_PATH}"
    print_info "Creating directory..."
    mkdir -p "${VPN_CONFIGS_PATH}"
    chmod 755 "${VPN_CONFIGS_PATH}"
  fi

  local ovpn_count
  ovpn_count=$(find "${VPN_CONFIGS_PATH}" -maxdepth 1 -name "*.ovpn" 2>/dev/null | wc -l)
  
  if [[ ${ovpn_count} -eq 0 ]]; then
    print_warning "No OpenVPN .ovpn files found in ${VPN_CONFIGS_PATH}"
    print_info "You'll need to add .ovpn files to ${VPN_CONFIGS_PATH} before the VPN toggle will work."
    print_info "Download them from your VPN provider (e.g., VPNBook, ProtonVPN, etc.)"
    
    read -p "Continue anyway? (y/N) " -n 1 -r </dev/tty
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
      exit 1
    fi
  else
    print_success "Found ${ovpn_count} OpenVPN configuration(s)"
  fi
}

create_waybar_directory() {
  if [[ ! -d "${WAYBAR_CONFIG_DIR}" ]]; then
    print_info "Creating Waybar config directory..."
    mkdir -p "${WAYBAR_CONFIG_DIR}"
    print_success "Created ${WAYBAR_CONFIG_DIR}"
  fi
  
  if [[ ! -d "${SCRIPTS_DIR}" ]]; then
    print_info "Creating Waybar scripts directory..."
    mkdir -p "${SCRIPTS_DIR}"
    print_success "Created ${SCRIPTS_DIR}"
  fi

  if [[ ! -d "${OVPN_SCRIPTS_DIR}" ]]; then
    print_info "Creating Waybar VPN scripts directory..."
    mkdir -p "${OVPN_SCRIPTS_DIR}"
    print_success "Created ${OVPN_SCRIPTS_DIR}"
  fi
}

verify_repo_scripts() {
  if [[ ! -d "${REPO_SCRIPTS_DIR}" ]]; then
    print_error "Scripts directory not found: ${REPO_SCRIPTS_DIR}"
    print_error "Please ensure you're running this script from the repository root."
    exit 1
  fi
}

install_scripts() {
  print_info "Installing VPN toggle scripts..."

  local -a scripts=("vpn-status.sh" "vpn-toggle.sh" "vpn-select.sh")
  
  for script in "${scripts[@]}"; do
    if [[ -f "${REPO_SCRIPTS_DIR}/${script}" ]]; then
      cp "${REPO_SCRIPTS_DIR}/${script}" "${OVPN_SCRIPTS_DIR}/"
      chmod +x "${OVPN_SCRIPTS_DIR}/${script}"
      print_success "Installed ${script}"
    else
      print_error "Script not found: ${REPO_SCRIPTS_DIR}/${script}"
      exit 1
    fi
  done
}

create_vpn_config() {
  if [[ ! -f "${OVPN_SCRIPTS_DIR}/vpn.conf" ]]; then
    local first_config
    first_config=$(find "${VPN_CONFIGS_PATH}" -maxdepth 1 -name "*.ovpn" 2>/dev/null | head -n 1)

    if [[ -n "${first_config}" ]]; then
      local vpn_name
      vpn_name=$(basename "${first_config}" .ovpn)
      {
        printf 'VPN_NAME=%q\n' "${vpn_name}"
        printf 'VPN_CONFIG_PATH=%q\n' "${first_config}"
        printf 'VPN_USER=%q\n' ""
        printf 'VPN_PASSWORD=%q\n' ""
      } > "${OVPN_SCRIPTS_DIR}/vpn.conf"
      print_success "Created vpn.conf with default: ${vpn_name}"
      print_warning "You'll need to configure credentials via the selection menu (right-click)"
    else
      {
        printf 'VPN_NAME=%q\n' ""
        printf 'VPN_CONFIG_PATH=%q\n' ""
        printf 'VPN_USER=%q\n' ""
        printf 'VPN_PASSWORD=%q\n' ""
      } > "${OVPN_SCRIPTS_DIR}/vpn.conf"
      print_warning "Created empty vpn.conf. Configure via the selection menu (right-click)"
    fi
  else
    print_info "vpn.conf already exists, skipping..."
  fi
}

update_waybar_config() {
  print_info "Updating Waybar configuration..."

  local config_file="${WAYBAR_CONFIG_DIR}/config.jsonc"
  if [[ ! -f "${config_file}" ]]; then
    config_file="${WAYBAR_CONFIG_DIR}/config"
  fi

  if [[ ! -f "${config_file}" ]]; then
    print_warning "Waybar config file not found at ${config_file}"
    return 0
  fi

  local backup_file="${config_file}.backup.$(date +%Y%m%d-%H%M%S)"
  cp "${config_file}" "${backup_file}"
  print_success "Backed up existing config to ${backup_file}"

  # Check if the configured module already exists
  if jq -e --arg m "${WAYBAR_OVPN_MODULE_NAME}" '.[$m]' "${config_file}" &>/dev/null; then
    print_info "${WAYBAR_OVPN_MODULE_NAME} already present in Waybar config"
    return 0
  fi

  # Add the configured module to modules-right after network
  if jq -e '.["modules-right"]' "${config_file}" &>/dev/null; then
    # Find network and insert the configured module right after it, preserving order
    jq --arg m "${WAYBAR_OVPN_MODULE_NAME}" '.["modules-right"] = (
      .["modules-right"] |
      to_entries |
      map(
        if .value == "network" then
          [., {"key": (.key + 0.5), "value": $m}]
        else
          .
        end
      ) |
      flatten |
      sort_by(.key) |
      map(.value)
    )' "${config_file}" > "${config_file}.tmp"
    mv "${config_file}.tmp" "${config_file}"
    print_success "Added ${WAYBAR_OVPN_MODULE_NAME} to modules-right after network"
  else
    print_warning "Could not find modules-right in config"
  fi

  # Add the configured module definition
  jq \
    --arg m "${WAYBAR_OVPN_MODULE_NAME}" \
    --arg dir "${OVPN_SCRIPTS_DIR}" '. += {
    ($m): {
      "format": "{icon}",
      "format-icons": {
        "default": "",
        "none": "󰻌",
        "connected": "󰦝",
        "disconnected": "󰦞"
      },
      "interval": 3,
      "return-type": "json",
      "exec": ($dir + "/vpn-status.sh"),
      "on-click": ($dir + "/vpn-toggle.sh"),
      "on-click-right": ("omarchy-launch-floating-terminal-with-presentation " + $dir + "/vpn-select.sh"),
      "signal": 8
    }
  }' "${config_file}" > "${config_file}.tmp"

  mv "${config_file}.tmp" "${config_file}"
  print_success "Added ${WAYBAR_OVPN_MODULE_NAME} module definition"
}

update_waybar_styles() {
  print_info "Updating Waybar styles..."

  local style_file="${WAYBAR_CONFIG_DIR}/style.css"

  if [[ -f "${style_file}" ]]; then
    local backup_file="${style_file}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "${style_file}" "${backup_file}"
    print_success "Backed up existing style to ${backup_file}"
    
    # Add the configured selector alongside #custom-omarchy
    if grep -q "#${WAYBAR_OVPN_SELECTOR}" "${style_file}"; then
      print_info "#${WAYBAR_OVPN_SELECTOR} already present in style.css"
    elif grep -q "#custom-omarchy" "${style_file}"; then
      local selector="#${WAYBAR_OVPN_SELECTOR}"
      sed -i "s|#custom-omarchy|#custom-omarchy,\\n${selector}|g" "${style_file}"
      print_success "Added ${selector} to style.css alongside #custom-omarchy"
    else
      print_warning "Could not find #custom-omarchy in style.css"
    fi
  else
    print_warning "style.css not found at ${style_file}"
  fi
}
configure_firewall() {
  if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo ""
    print_warning "UFW Firewall Detected"
    print_info "UFW often blocks VPN traffic on the 'tun' interface by default."
    read -p "Would you like to allow VPN traffic (tun+) in UFW? (y/N) " -n 1 -r </dev/tty
    echo
    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
      if sudo ufw allow in on tun+ && sudo ufw allow out on tun+; then
        print_success "Added UFW rules for tun+ interface"
      else
        print_warning "Failed to add UFW rules"
      fi
    fi
  fi
}

configure_sudoers() {
  echo ""
  print_warning "Sudoers Configuration Required"
  echo ""
  print_info "To enable passwordless VPN toggling, openvpn and kill commands need to be added to sudoers."
  print_warning "This allows running 'openvpn' and 'kill' commands without entering your password."
  echo ""
  
  read -p "Would you like to configure sudoers now? (y/N) " -n 1 -r </dev/tty
  echo

  if [[ ${REPLY} =~ ^[Yy]$ ]]; then
    print_info "Adding sudoers rule..."
    
    local user_group
    if groups | grep -q wheel; then
      user_group="wheel"
    elif groups | grep -q sudo; then
      user_group="sudo"
    else
      print_error "Could not determine your sudo group (wheel or sudo)"
      user_group="wheel"
      print_warning "Defaulting to 'wheel' group. You may need to adjust this."
    fi

    local sudoers_line="%${user_group} ALL=(ALL) NOPASSWD: /usr/bin/openvpn, /usr/bin/kill, /usr/bin/expect"
    local temp_sudoers
    temp_sudoers=$(mktemp)
    
    echo "${sudoers_line}" > "${temp_sudoers}"
    
    if sudo visudo -c -f "${temp_sudoers}" &>/dev/null; then
      echo "${sudoers_line}" | sudo tee /etc/sudoers.d/openvpn-vpn-toggle > /dev/null
      sudo chmod 440 /etc/sudoers.d/openvpn-vpn-toggle
      print_success "Sudoers rule added successfully"
    else
      print_error "Sudoers validation failed"
      rm "${temp_sudoers}"
      exit 1
    fi
    
    rm "${temp_sudoers}"
  else
    print_warning "Skipping sudoers configuration."
    print_info "You'll need to manually add this line to sudoers (using 'sudo visudo'):"
    echo "  %wheel ALL=(ALL) NOPASSWD: /usr/bin/openvpn, /usr/bin/kill, /usr/bin/expect"
    echo ""
    print_warning "Without this, you'll be prompted for your password when toggling VPN."
  fi
}

show_completion_message() {
  echo ""
  print_success "Installation complete!"
  echo ""
  print_info "Next steps:"
  echo "  1. Restart Waybar (you'll be prompted next)"
  echo "  2. Add .ovpn files to ${VPN_CONFIGS_PATH} with: cp file.ovpn ${VPN_CONFIGS_PATH}/"
  echo "  3. Right-click the VPN icon to select VPN and enter credentials"
  echo "  4. Left-click the VPN icon to toggle connection"
  echo ""
  print_info "For VPNBook, see: https://www.vpnbook.com/"
  print_info "For ProtonVPN, see: https://protonvpn.com/support/linux-openvpn"
  echo ""
}

restart_waybar() {
  echo ""
  read -p "Would you like to restart Waybar now? (Y/n) " -n 1 -r </dev/tty
  echo
  
  if [[ ${REPLY} =~ ^[Nn]$ ]]; then
    print_info "Skipping Waybar restart"
    print_info "Remember to restart Waybar manually: killall waybar && waybar &"
    return 0
  fi
  
  print_info "Restarting Waybar..."
  if pgrep -x waybar >/dev/null; then
    killall waybar
    sleep 0.5
  fi
  
  waybar &>/dev/null &
  print_success "Waybar restarted"
}

main "$@"
