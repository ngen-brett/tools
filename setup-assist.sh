#!/usr/bin/env bash
set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root." >&2
  exit 1
fi

USER="assist"
SSH_KEY_URL="https://raw.githubusercontent.com/ngen-brett/tools/refs/heads/main/keys/id_ed25519_assist.pub"
SUDOERS_FILE="/etc/sudoers.d/${USER}"
PM=""
SSH_SERVICE="sshd"

# Detect package manager
if   command -v dnf    &>/dev/null; then PM="dnf"
elif command -v yum    &>/dev/null; then PM="yum"
elif command -v apt    &>/dev/null; then PM="apt"
elif command -v zypper &>/dev/null; then PM="zypper"
else
  echo "ERROR: Unsupported distro: no known package manager." >&2
  exit 1
fi

install_pkg() {
  local pkg=$1
  if ! command -v "$pkg" &>/dev/null; then
    echo "Installing $pkg..."
    case "$PM" in
      dnf|yum)   $PM install -y "$pkg" ;;
      apt)       apt update && apt install -y "$pkg" ;;
      zypper)    zypper install -y "$pkg" ;;
    esac
  else
    echo "$pkg is already installed."
  fi
}

# 1. Install sudo
install_pkg sudo

# 2. Install openssh-server / ssh service
if ! systemctl list-unit-files | grep -q "^${SSH_SERVICE}\.service"; then
  echo "Enabling SSH service package..."
  case "$PM" in
    dnf|yum)   $PM install -y openssh-server ;;
    apt)       apt update && apt install -y openssh-server ;;
    zypper)    zypper install -y openssh ;;
  esac
else
  echo "openssh-server package detected."
fi

# 3. Create assist user if needed
if id -u "$USER" &>/dev/null; then
  echo "User '$USER' already exists."
else
  echo "Creating user '$USER'..."
  useradd --create-home --shell /bin/bash "$USER"
fi

# 4. Configure SSH key for assist
USER_HOME=$(eval echo "~${USER}")
AUTH_DIR="${USER_HOME}/.ssh"
AUTHORIZED_KEYS="${AUTH_DIR}/authorized_keys"

if [[ -f "$AUTHORIZED_KEYS" ]]; then
  echo "authorized_keys for '$USER' already exists; updating key..."
else
  echo "Setting up SSH key for '$USER'..."
  mkdir -p "$AUTH_DIR"
fi
curl -fsSL "$SSH_KEY_URL" > "$AUTHORIZED_KEYS"
chown -R "$USER":"$USER" "$AUTH_DIR"
chmod 700 "$AUTH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
echo "SSH key installed."

# 5. Enable & start SSH service
if systemctl is-enabled "$SSH_SERVICE" &>/dev/null; then
  echo "SSH service already enabled."
else
  echo "Enabling SSH service..."
  systemctl enable "$SSH_SERVICE"
fi
if systemctl is-active "$SSH_SERVICE" &>/dev/null; then
  echo "SSH service is running."
else
  echo "Starting SSH service..."
  systemctl start "$SSH_SERVICE"
fi

# 6. Configure firewall to allow SSH
if command -v firewall-cmd &>/dev/null; then
  if firewall-cmd --list-all --permanent | grep -qw ssh; then
    echo "SSH already allowed in firewalld."
  else
    echo "Allowing SSH in firewalld..."
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
  fi
elif command -v ufw &>/dev/null; then
  if ufw status numbered | grep -qw "OpenSSH"; then
    echo "OpenSSH already allowed in ufw."
  else
    echo "Allowing OpenSSH in ufw..."
    ufw allow OpenSSH
    ufw reload
  fi
elif command -v iptables &>/dev/null; then
  if iptables -C INPUT -p tcp --dport 22 -j ACCEPT &>/dev/null; then
    echo "SSH port already allowed in iptables."
  else
    echo "Allowing SSH port in iptables..."
    iptables -I INPUT -p tcp --dport 22 -j ACCEPT
    command -v netfilter-persistent &>/dev/null && netfilter-persistent save
  fi
else
  echo "No known firewall tool found; skipping firewall configuration."
fi

# 7. Grant NOPASSWD sudo for assist
if [[ -f "$SUDOERS_FILE" ]] && grep -q "^${USER} ALL=(ALL) NOPASSWD:ALL$" "$SUDOERS_FILE"; then
  echo "NOPASSWD sudo entry already present for '$USER'."
else
  echo "Creating sudoers file for '$USER'..."
  echo "${USER} ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
  chmod 0440 "$SUDOERS_FILE"
  echo "Validating sudoers syntax..."
  visudo -cf "$SUDOERS_FILE"
  echo "Sudoers file installed."
fi

# 8. Display default route interface and IP addresses
DEFAULT_DEV=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
if [[ -n "$DEFAULT_DEV" ]]; then
  echo "Default route via interface: $DEFAULT_DEV"
  echo "IPv4 address:"
  ip -4 addr show dev "$DEFAULT_DEV" | awk '/inet /{print $2}'
  echo "IPv6 address:"
  ip -6 addr show dev "$DEFAULT_DEV" | awk '/inet6 /{print $2}'
else
  echo "No default route found."
fi

echo "All steps completed successfully."
