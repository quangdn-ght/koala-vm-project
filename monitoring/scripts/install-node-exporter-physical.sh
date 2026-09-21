#!/usr/bin/env bash
# Install node_exporter on LAN physical hosts (not the KVM hypervisor).
set -euo pipefail

VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/cache"
KNOWN_HOSTS="/tmp/physical-node-exporter-known-hosts"

SSH_BASE=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KNOWN_HOSTS"
          -o ConnectTimeout=10 -o PreferredAuthentications=keyboard-interactive,password
          -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1)

# ip user password hostname arch
HOSTS=(
  "10.168.1.5 ght 1 gx10-b273 arm64"
  "10.168.1.50 koala 1 GHT-Koala-01 amd64"
  "10.168.1.51 koala koala intel-nuc7 amd64"
  "10.168.1.54 ght 1 ght-demo-server amd64"
  "192.168.3.101 ght Giahung@2024 ght-dev-server amd64"
)

mkdir -p "$CACHE"

download_arch() {
  local arch="$1"
  local tar="node_exporter-${VERSION}.linux-${arch}.tar.gz"
  local url="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${tar}"
  if [[ ! -f "$CACHE/$tar" ]]; then
    echo "Downloading $url"
    curl -fsSL -o "$CACHE/$tar" "$url"
  fi
  tar -tzf "$CACHE/$tar" >/dev/null
}

download_arch amd64
download_arch arm64

REMOTE_INSTALL=$(cat <<'EOS'
set -euo pipefail
VERSION="$1"
ARCH="$2"
SUDO_PASS="$3"
tarfile="/tmp/node_exporter-${VERSION}.linux-${ARCH}.tar.gz"
sudo_cmd() {
  if sudo -n true 2>/dev/null; then
    sudo "$@"
  else
    printf '%s\n' "$SUDO_PASS" | sudo -S -p '' "$@"
  fi
}
sudo_cmd mkdir -p /usr/local/bin
tmpdir=$(mktemp -d)
tar -xzf "$tarfile" -C "$tmpdir"
sudo_cmd cp "$tmpdir"/node_exporter-*/node_exporter /usr/local/bin/node_exporter
sudo_cmd chmod 755 /usr/local/bin/node_exporter
rm -rf "$tmpdir" "$tarfile"
if ! getent group node_exporter >/dev/null; then
  sudo_cmd groupadd --system node_exporter || true
fi
if ! id node_exporter >/dev/null 2>&1; then
  sudo_cmd useradd --system --no-create-home --shell /usr/sbin/nologin -g node_exporter node_exporter || \
    sudo_cmd useradd --system --no-create-home --shell /bin/false -g node_exporter node_exporter
fi
sudo_cmd tee /etc/systemd/system/node_exporter.service >/dev/null <<'UNIT'
[Unit]
Description=Prometheus Node Exporter
After=network-online.target
[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100 --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run|var/lib/docker/.+|snap/.+)($|/)
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
sudo_cmd systemctl daemon-reload
sudo_cmd systemctl enable --now node_exporter
sudo_cmd systemctl is-active node_exporter
(ss -lnt 2>/dev/null || netstat -lnt) | grep -q ':9100' && echo "LISTEN 9100"
EOS
)

install_one() {
  local ip="$1" user="$2" pass="$3" name="$4" arch="$5"
  local tar="node_exporter-${VERSION}.linux-${arch}.tar.gz"
  echo "=== $name ($user@$ip $arch) ==="
  export SSHPASS="$pass"
  if ! sshpass -e ssh "${SSH_BASE[@]}" "${user}@${ip}" 'echo ok' >/dev/null; then
    echo "SKIP $name: SSH failed"
    return 1
  fi
  sshpass -e scp "${SSH_BASE[@]}" "$CACHE/$tar" "${user}@${ip}:/tmp/$tar"
  sshpass -e ssh "${SSH_BASE[@]}" "${user}@${ip}" "bash -s -- $VERSION $arch $pass" <<<"$REMOTE_INSTALL"
  echo "OK $name"
}

ok=0
fail=0
for row in "${HOSTS[@]}"; do
  # shellcheck disable=SC2086
  set -- $row
  if install_one "$1" "$2" "$3" "$4" "$5"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
done
echo "Installed $ok physical host(s), failed $fail"
[[ "$fail" -eq 0 ]]
