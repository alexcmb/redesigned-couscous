#!/usr/bin/env bash

set -euo pipefail

host="${1:?host required}"
user="${2:?user required}"
key_file="${3:?ssh key file required}"

ssh_opts=(
  -i "$key_file"
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile=/dev/null
)

ssh "${ssh_opts[@]}" "${user}@${host}" 'sudo bash -s' <<'REMOTE'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y fail2ban auditd audispd-plugins

install -d -m 0755 /etc/fail2ban/jail.d
cat >/etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled = true
backend = systemd
mode = aggressive
maxretry = 5
findtime = 10m
bantime = 1h
EOF

ensure_sshd_option() {
  local key="$1"
  local value="$2"
  local config_file="/etc/ssh/sshd_config"

  if grep -qE "^#?${key}[[:space:]]+" "$config_file"; then
    sed -i -E "s/^#?${key}[[:space:]]+.*/${key} ${value}/" "$config_file"
  else
    printf '%s %s\n' "$key" "$value" >>"$config_file"
  fi
}

ensure_sshd_option PermitRootLogin no
ensure_sshd_option PasswordAuthentication no
ensure_sshd_option KbdInteractiveAuthentication no
ensure_sshd_option PubkeyAuthentication yes

systemctl enable fail2ban auditd
systemctl restart fail2ban auditd
systemctl restart ssh
REMOTE