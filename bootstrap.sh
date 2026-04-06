#!/usr/bin/env bash
set -euo pipefail

# Minimal onboarding bootstrap for Debian/Ubuntu.
# Installs Ansible (bootstrap) and runs ansible/playbook.yml on localhost.
# Usage:
#   sudo ./bootstrap.sh            # runs playbook for SUDO_USER
#   sudo ./bootstrap.sh --docker   # also install Docker

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: sudo $0 [--docker]
Options:
  --docker   Install Docker (docker-ce, docker-cli, docker-compose-plugin)
EOF
}

INSTALL_DOCKER=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker) INSTALL_DOCKER=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root (use sudo)" >&2
  exit 1
fi

# Determine target user (the human account to configure)
TARGET_USER=${SUDO_USER:-${USER:-}}
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "No non-root target user detected via SUDO_USER. Please set TARGET_USER env or run as sudo from a real user." >&2
  echo "Example: sudo TARGET_USER=alice $0" >&2
  exit 1
fi

echo "Running onboarding for user: $TARGET_USER"

export DEBIAN_FRONTEND=noninteractive

echo "Updating apt and installing bootstrap packages..."
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release software-properties-common

echo "Installing Ansible (apt package)..."
apt-get update -y
apt-get install -y ansible python3-apt

# Try to discover latest OpenTofu linux_amd64 asset URL from GitHub
OPENTOFU_URL=""
if command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  echo "Attempting to locate latest OpenTofu release (optional) ..."
  set +e
  json=$(curl -sSfL https://api.github.com/repos/opentofu/opentofu/releases/latest)
  # parse browser_download_url for linux_amd64 asset
  OPENTOFU_URL=$(python3 - <<PY
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        name = a.get('name','')
        if 'linux' in name and ('amd64' in name or 'x86_64' in name):
            print(a.get('browser_download_url',''))
            sys.exit(0)
except Exception:
    pass
sys.exit(0)
PY
  <<<"$json")
  set -e
  if [[ -n "$OPENTOFU_URL" ]]; then
    echo "Found OpenTofu asset: $OPENTOFU_URL"
  else
    echo "No OpenTofu asset found; playbook will skip binary install unless provided." >&2
  fi
fi

echo "Creating temporary Ansible inventory..."
INVENTORY="$SCRIPT_DIR/ansible/inventory"
cat > "$INVENTORY" <<EOF
[local]
localhost ansible_connection=local
EOF

echo "Running Ansible playbook..."
ansible-playbook -i "$INVENTORY" "$SCRIPT_DIR/ansible/playbook.yml" \
  --extra-vars "target_user=$TARGET_USER install_docker=$INSTALL_DOCKER opentofu_url='$OPENTOFU_URL'"

echo "Onboarding complete."
