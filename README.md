# Setup Assist User Script

This repository contains a script to create a user named `assist`, configure SSH access using a public key, enable and start the SSH service, configure the host firewall to allow SSH, grant passwordless sudo privileges to the user, and display the default network interface IP addresses.

## Prerequisites

- A Linux server (Fedora, RHEL, CentOS, Debian, Ubuntu, openSUSE, etc.)
- `curl` installed
- Root or sudo privileges
- Network access to fetch the script and SSH key

## Files Structure

```plain
.
├── keys/
│   └── id_ed25519_assist.pub  # SSH public key
└── setup-assist.sh            # Setup script
```

## Usage

Without cloning the repository, you can pull and execute the setup script directly with:

```bash
curl -fsSL https://raw.githubusercontent.com/ngen-brett/tools/refs/heads/main/setup-assist.sh | sudo bash
```

This command will:

1. Download the `setup-assist.sh` script from GitHub.
2. Execute the script with `bash` under `sudo` to ensure it runs with root privileges.

## What It Does

1. Installs `openssh-server` if not already present.
2. Creates a system user `assist` with a home directory.
3. Fetches the SSH public key from `keys/id_ed25519_assist.pub` and installs it for the `assist` user.
4. Enables and starts the SSH daemon (`sshd`).
5. Configures the firewall (using `firewall-cmd`, `ufw`, or `iptables`) to allow SSH.
6. Grants the `assist` user passwordless sudo access by creating a sudoers file.
7. Detects the default network interface and displays its IPv4 and IPv6 addresses.

## Notes

- The SSH public key URL is hardcoded to `https://raw.githubusercontent.com/ngen-brett/tools/refs/heads/main/keys/id_ed25519_assist.pub`. Ensure this file exists and is reachable.
- Supported package managers: `dnf`, `yum`, `apt`, `zypper`.
- Firewall tools supported: `firewall-cmd`, `ufw`, `iptables`.

## License

This project is released under the MIT License.
