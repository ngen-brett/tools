#!/usr/bin/env bash
set -euo pipefail

# Must run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

USER="assist"
SSH_KEY_URL="https://raw.githubusercontent.com/ngen-brett/tools/refs/heads/main/keys/id_ed25519_assist.pub"
SUDOERS_FILE="/etc/sudoers.d/${USER}"

# Detect package manager
if   command -v dnf    &>/dev/null; then PM="dnf"
elif command -v yum    &>/dev/null; then PM="yum"
elif command -v apt    &>/dev/null; then PM="apt"
elif command -v zypper &>/dev/null; then PM="zypper"
else
  echo "Unsupported distro: no known package manager" >&2
  exit 1
fi

# Install sudo if needed
if ! command -v sudo &>/dev/null; then
  case "$PM" in
    dnf|yum)
      $PM install -y sudo
      ;;
    apt)
      apt update
      apt install -y sudo
      ;;
    zypper)
      zypper install -y sudo
      ;;
  esac
fi

# Install openssh-server if needed
if ! command -v sshd &>/dev/null; then
  case "$PM" in
    dnf|yum)
      $PM install -y openssh-server
      ;;
    apt)
      apt update
      apt install -y openssh-server
      ;;
    zypper)
      zypper install -y openssh
      ;;
  esac
fi

# Create system user if not exists
if ! id -u "$USER" &>/dev/null; then
  useradd --create-home --shell /bin/bash "$USER"
fi

# Configure SSH key
USER_HOME=$(eval echo "~${USER}")
AUTH_DIR="${USER_HOME}/.ssh"
AUTHORIZED_KEYS="${AUTH_DIR}/authorized_keys"

mkdir -p "$AUTH_DIR"
curl -fsSL "$SSH_KEY_URL" > "$AUTHORIZED_KEYS"
chown -R "$USER":"$USER" "$AUTH_DIR"
chmod 700 "$AUTH_DIR"
chmod 600 "$AUTHORIZED_KEYS"

# Enable and start SSH service
systemctl enable sshd
systemctl start sshd

# Configure firewall: allow ssh
if command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-service=ssh
  firewall-cmd --reload
elif command -v ufw &>/dev/null; then
  ufw allow OpenSSH
  ufw reload
else
  if command -v iptables &>/dev/null; then
    iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
      iptables -I INPUT -p tcp --dport 22 -j ACCEPT
    command -v netfilter-persistent &>/dev/null && netfilter-persistent save
  fi
fi

# Grant sudo NOPASSWD for the assist user
echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "${SUDOERS_FILE}" > /dev/null
chmod 0440 "${SUDOERS_FILE}"
# Validate sudoers syntax
visudo -cf "${SUDOERS_FILE}"

# Display IPv4 and IPv6 for default route interface
DEFAULT_DEV=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
if [[ -n "$DEFAULT_DEV" ]]; then
  echo "Default route via interface: $DEFAULT_DEV"
  echo "IPv4 address:"
  ip -4 addr show dev "$DEFAULT_DEV" | awk '/inet /{print $2}'
  echo "IPv6 address:"
  ip -6 addr show dev "$DEFAULT_DEV" | awk '/inet6 /{print $2}'
else
  echo "No default route found"
fi
