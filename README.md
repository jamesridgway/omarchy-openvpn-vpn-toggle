# OpenVPN Toggle for Omarchy's Waybar

Based on the WireGuard toggle from [JacobusXIII/omarchy-wireguard-vpn-toggle](https://github.com/JacobusXIII/omarchy-wireguard-vpn-toggle).

A clean, automated installer for adding an OpenVPN toggle to Omarchy's Waybar status bar. Provides a convenient visual indicator and quick toggle for your OpenVPN connections.

Based on the guide from [Omarchy Discussion #1366](https://github.com/basecamp/omarchy/discussions/1366).

## Features

- 🔒 **One-click VPN toggle** - Left-click to connect/disconnect
- 🎨 **Visual status indicator** - Integrates with Omarchy's icon theming
- 🔄 **Profile switching** - Right-click menu to switch between VPN configs
- ⚡ **Passwordless operation** - Optional sudoers configuration
- 🛡️ **The Omarchy way** - All scripts follow Omarchy bash practices with proper error handling
- 📦 **Automated installation** - Simple installer handles everything for Omarchy setups

## Prerequisites

**⚠️ This tool is designed specifically for [Omarchy](https://github.com/basecamp/omarchy) setups only.**

- **Omarchy** - This VPN toggle is designed to integrate with Omarchy's Waybar configuration
- **Bash** 4.0+
- **OpenVPN** (`openvpn`)
- **jq** (JSON processor for safe config manipulation)
- **OpenVPN configuration files** (.ovpn files from your VPN provider)
  - Downloaded from providers like VPNBook, ProtonVPN, NordVPN, etc.
  - Placed in `~/.config/openvpn/`
  - Username and password will be configured via the selection menu

### Install Dependencies

Since Omarchy is designed for Arch Linux:

```bash
sudo pacman -S openvpn waybar jq
```

## Installation

### Quick Install (One-Liner)

Install directly from GitHub with a single command:

**Using curl:**
```bash
curl -fsSL https://raw.githubusercontent.com/james-ridgway/omarchy-openvpn-vpn-toggle/main/install.sh | bash
```

**Using wget:**
```bash
wget -qO- https://raw.githubusercontent.com/james-ridgway/omarchy-openvpn-vpn-toggle/main/install.sh | bash
```

This will:
- Automatically detect one-liner mode
- Run the full installation with interactive prompts
- Ask for sudoers configuration (optional passwordless toggling)
- Clean up temporary files when done

**Note:** You'll need OpenVPN configuration files (.ovpn) and credentials before the VPN toggle will work (see step 2 below).

---

### Manual Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/james-ridgway/omarchy-openvpn-vpn-toggle.git
cd omarchy-openvpn-vpn-toggle
```

#### 2. Set Up OpenVPN Configuration

If you haven't already, you need OpenVPN configuration files (.ovpn) from your VPN provider.

**For VPNBook users:**

1. Visit the [VPNBook free VPN page](https://www.vpnbook.com/)
2. Download OpenVPN configuration files (UDP recommended)
3. Copy them to `~/.config/openvpn/`:
   ```bash
   cp vpnbook-*.ovpn ~/.config/openvpn/
   ```
4. Note the username and password shown on the VPNBook website

**For ProtonVPN users:**

1. Visit the [ProtonVPN downloads page](https://account.protonvpn.com/downloads)
2. Download OpenVPN configuration files (UDP recommended)
3. Copy them to `~/.config/openvpn/`:
   ```bash
   cp your-config.ovpn ~/.config/openvpn/
   ```
4. Use your ProtonVPN account credentials

See the [ProtonVPN OpenVPN guide](https://protonvpn.com/support/linux-openvpn) for detailed instructions.

**For other VPN providers:**

Most VPN providers offer OpenVPN configuration files. Download the .ovpn files and copy them to `~/.config/openvpn/`. You'll configure credentials through the selection menu (right-click on the VPN icon).

#### 3. Run the Installer

```bash
./install.sh
```

The installer will:
- ✅ Check for required dependencies
- ✅ Verify OpenVPN configurations exist
- ✅ Install scripts to `~/.config/waybar/scripts/ovpn-toggle/`
- ✅ Add `custom/ovpn` module to Omarchy's Waybar config (after network module)
- ✅ Add `#custom-ovpn` to style.css alongside `#custom-omarchy`
- ✅ Optionally configure sudoers for passwordless operation

#### 4. Restart Waybar

```bash
killall waybar && waybar &
```

Or restart your compositor.

## Usage

### Toggle VPN Connection

**Left-click** on the VPN icon in Omarchy's Waybar to connect or disconnect.

### Switch VPN Profile

**Right-click** on the VPN icon to open an interactive menu where you can select a different OpenVPN configuration.

### Password Authentication

All VPN connections require a username and password. The script automatically handles credential management.

**Setting up credentials:**

When you select a VPN (via right-click menu), you'll be prompted to enter your username and password. These are securely stored in `~/.config/waybar/scripts/ovpn-toggle/vpn.conf` and automatically provided to OpenVPN when connecting.

**Option: Config Comments**
You can also add your credentials directly to your `.ovpn` file as comments, and the script will pick them up automatically:

```bash
# VPN_USER=your_username
# VPN_PASSWORD=your_password
client
dev tun
...
```

The script will detect these credentials and store them in `vpn.conf` for automatic authentication.

### Manual Control

You can also use the scripts directly from the command line:

```bash
# Toggle VPN on/off
~/.config/waybar/scripts/ovpn-toggle/vpn-toggle.sh

# Check current status
~/.config/waybar/scripts/ovpn-toggle/vpn-status.sh

# Select VPN profile
~/.config/waybar/scripts/ovpn-toggle/vpn-select.sh
```

## Customization

### Styling

The installer automatically adds `#custom-ovpn` to your `style.css` alongside other icons:

```css
#custom-omarchy,
#custom-ovpn {
  /* Your existing Omarchy icon styles */
}
```

By default, the VPN icon inherits the same styling as your other custom modules (colors, spacing, etc.). You can customize this by:

- **Keeping it grouped** with other icons to inherit their styles
- **Separating it** to apply custom styles only to the VPN icon:
  ```css
  #custom-ovpn {
    color: #your-color;
    /* Your custom styles */
  }
  ```

### Change Icons

The VPN icons can be changed by editing your Omarchy Waybar config's `format-icons`:

```json
"format-icons": {
  "default": "",    // Default/fallback icon (blank)
  "none": "󰻌",       // No config
  "connected": "󰦝",   // VPN connected
  "disconnected": "󰦞" // VPN disconnected
}
```

Replace the Nerd Font icons with your preferred icons or emoji.

## Project Structure

```
omarchy-openvpn-vpn-toggle/
├── scripts/              # VPN toggle scripts
│   ├── vpn-status.sh    # Checks VPN connection status
│   ├── vpn-toggle.sh    # Toggles VPN on/off
│   └── vpn-select.sh    # Interactive VPN profile selector
├── install.sh           # Main installer script
├── LICENSE              # MIT License
├── README.md            # This file
└── .gitignore
```

### Installed Files

The installer creates/modifies these files:

**In `~/.config/waybar/scripts/ovpn-toggle/`:**
- `vpn-status.sh` - Checks VPN connection status (returns JSON with icon state)
- `vpn-toggle.sh` - Toggles VPN on/off
- `vpn-select.sh` - Interactive VPN profile selector
- `vpn.conf` - Stores currently selected VPN configuration

**In `~/.config/waybar/`:**
- `config.jsonc` or `config` - Waybar config (adds custom/ovpn module with format-icons)
- `style.css` - Waybar styles (adds #custom-ovpn alongside #custom-omarchy)
- `*.backup.YYYYMMDD-HHMMSS` - Timestamped backups of modified files

## Troubleshooting

### Password Prompt When Toggling

If you're prompted for your sudo password when toggling VPN:

1. Run the installer again and choose to configure sudoers
2. Or manually add this line using `sudo visudo`:
   ```
   %wheel ALL=(ALL) NOPASSWD: /usr/bin/openvpn, /usr/bin/kill, /usr/bin/expect
   ```

### VPN Icon Not Appearing

1. **Check Waybar config is valid JSON:**
   ```bash
   cat ~/.config/waybar/config.jsonc | jq
   ```

2. **Ensure scripts are executable:**
   ```bash
   chmod +x ~/.config/waybar/scripts/ovpn-toggle/vpn-*.sh
   ```

3. **Check Waybar logs:**
   ```bash
   journalctl --user -u waybar -f
   ```

4. **Verify scripts exist:**
   ```bash
   ls -lh ~/.config/waybar/scripts/ovpn-toggle/vpn-*.sh
   ```

### "No OpenVPN configurations found"

Ensure you have `.ovpn` files in `~/.config/openvpn/`:

```bash
ls -lh ~/.config/openvpn/
```

If empty, download configuration files from your VPN provider (VPNBook, ProtonVPN, etc.) and copy them:

```bash
cp your-config.ovpn ~/.config/openvpn/
```

### Connection Fails

Test manually to identify the issue:

```bash
# Try connecting manually (replace with your actual .ovpn file path)
sudo openvpn --config ~/path/to/your-config.ovpn
```

You'll be prompted for username and password. Check for errors in the output. Press Ctrl+C to stop.

**Common issues:**
- Wrong username/password: Re-run the selection menu (right-click) to update credentials
- Firewall blocking: Check UFW rules or firewall settings
- DNS issues: Check `/etc/resolv.conf` after connection

### Script Syntax Errors

All scripts follow strict bash practices. If you modify them, validate syntax:

```bash
bash -n ~/.config/waybar/scripts/ovpn-toggle/vpn-status.sh
bash -n ~/.config/waybar/scripts/ovpn-toggle/vpn-toggle.sh
bash -n ~/.config/waybar/scripts/ovpn-toggle/vpn-select.sh
```

## Security Considerations

### Sudoers Configuration

The sudoers configuration allows running `openvpn`, `kill`, and `expect` commands without a password. This is limited to:
- Only the `/usr/bin/openvpn`, `/usr/bin/kill`, and `/usr/bin/expect` binaries
- Only for users in the `wheel`/`sudo` group

This is generally safe, but be aware that anyone with access to your user account can control VPN connections and potentially terminate processes without additional authentication.

If this is a concern in your environment, you can skip the sudoers setup and enter your password each time you toggle the VPN.

### Configuration File Security

OpenVPN configuration files (.ovpn) in `/etc/openvpn/client/` and the credentials file (`~/.config/waybar/scripts/ovpn-toggle/vpn.conf`) may contain sensitive information. The scripts handle them securely:

- Credentials are stored in your user directory with restricted permissions
- Only your user account can read the vpn.conf file
- .ovpn files in `/etc/openvpn/client/` should have restricted permissions

For additional security, set proper permissions:

```bash
sudo chmod 600 /etc/openvpn/client/*.ovpn
sudo chown root:root /etc/openvpn/client/*.ovpn
chmod 600 ~/.config/waybar/scripts/ovpn-toggle/vpn.conf
```

## Uninstallation

To remove the VPN toggle, you can use the uninstaller:

```bash
./install.sh --uninstall
```

Or manually:

1. **Remove the scripts:**
   ```bash
   rm -rf ~/.config/waybar/scripts/ovpn-toggle
   ```

2. **Remove from Waybar config:**
   - Delete `"custom/ovpn"` from `modules-right` array
   - Delete the `"custom/ovpn"` configuration block
   - (Or restore from timestamped backup: `~/.config/waybar/config.jsonc.backup.YYYYMMDD-HHMMSS`)

3. **Remove from `~/.config/waybar/style.css`:**
   - Remove `#custom-ovpn,` from the line with `#custom-omarchy`
   - (Or restore from timestamped backup: `~/.config/waybar/style.css.backup.YYYYMMDD-HHMMSS`)

4. **Remove sudoers rule:**
   ```bash
   sudo rm /etc/sudoers.d/openvpn-vpn-toggle
   ```

5. **Restart Waybar:**
   ```bash
   killall waybar && waybar &
   ```

## Development

### Code Style

All bash scripts follow the Omarchy way - bash practices observed in the [Omarchy](https://github.com/basecamp/omarchy) repository:

- Shebang and strict mode: `#!/bin/bash` with `set -eEo pipefail`
- Error handling: `trap catch_errors ERR INT TERM; trap exit_handler EXIT`
- Function definitions: `name() { ... }` (no `function` keyword)
- Use `local` for function-scoped variables
- `[[ ... ]]` for conditions
- Quoted variable expansions: `"${VAR}"`
- Command availability: `command -v tool &>/dev/null`
- 2-space indentation
- UPPER_SNAKE_CASE for globals, lower_snake_case for locals

### Testing

Validate syntax of all scripts:

```bash
bash -n install.sh
for script in scripts/*.sh; do bash -n "$script"; done
```

## Credits

Based on the manual setup guide by [@rulonder](https://github.com/rulonder) in [Omarchy Discussion #1366](https://github.com/basecamp/omarchy/discussions/1366).

This fork builds on [daniel-mekuria/omarchy-openvpn-vpn-toggle](https://github.com/daniel-mekuria/omarchy-openvpn-vpn-toggle) and incorporates work from two unmerged PRs against it:

- [PR #1](https://github.com/daniel-mekuria/omarchy-openvpn-vpn-toggle/pull/1) by [@pabumake](https://github.com/pabumake) — connection reliability and config-handling fixes (PID validation, safer `vpn.conf` quoting, configurable connect timeout, fast-fail on auth/DNS errors, log file relocated under the user's config dir, deduplicated connect logic).
- [PR #2](https://github.com/daniel-mekuria/omarchy-openvpn-vpn-toggle/pull/2) by [@cfulton](https://github.com/cfulton) — namespacing the install path (`~/.config/waybar/scripts/ovpn-toggle/`), Waybar module (`custom/ovpn`), and CSS selector (`#custom-ovpn`) so this can coexist with similar WireGuard waybar toggles.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to:
- Report bugs by opening an issue
- Suggest features or improvements
- Submit pull requests

When contributing code, please follow the existing bash style guide.

## Related Projects

- [Omarchy](https://github.com/basecamp/omarchy) - Configuration framework this is designed for
- [Waybar](https://github.com/Alexays/Waybar) - Highly customizable Wayland bar
- [WireGuard](https://www.wireguard.com/) - Fast, modern VPN protocol
- [ProtonVPN](https://protonvpn.com/) - Privacy-focused VPN service

---

**Enjoy your new VPN toggle!** 🔒✨

