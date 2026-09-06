#!/usr/bin/env bash
# Install node_exporter as a systemd service on guest VMs.
set -euo pipefail

VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/cache"
TARBALL="node_exporter-${VERSION}.linux-amd64.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${TARBALL}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new)

# user@ip  vm-name
GUESTS=(
  "ght@10.168.1.104 kong-gateway"
  "koala@10.168.1.55 faceid"
  "ght@10.168.1.56 wiseeye"
  "ght@10.168.1.58 unilever"
  "ght@10.168.1.59 chebichat"
  "ght@10.168.1.106 nx-vms"
)

mkdir -p "$CACHE"
if [[ ! -f "$CACHE/$TARBALL" ]]; then
  echo "Downloading $URL"
  curl -fsSL -o "$CACHE/$TARBALL" "$URL"
fi
tar -tzf "$CACHE/$TARBALL" >/dev/null

REMOTE_INSTALL=$(cat <<'EOS'
set -euo pipefail
VERSION="$1"
tarfile="/tmp/node_exporter-${VERSION}.linux-amd64.tar.gz"
sudo mkdir -p /opt/node_exporter /usr/local/bin
tmpdir=$(mktemp -d)
tar -xzf "$tarfile" -C "$tmpdir"
sudo cp "$tmpdir"/node_exporter-*/node_exporter /usr/local/bin/node_exporter
sudo chmod 755 /usr/local/bin/node_exporter
rm -rf "$tmpdir" "$tarfile"
if ! id node_exporter >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter || \
    sudo useradd --system --no-create-home --shell /bin/false node_exporter
fi
sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<'UNIT'
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
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl is-active node_exporter
ss -lnt | grep -q ':9100' && echo "LISTEN 9100"
EOS
)

install_one() {
  local spec="$1"
  local ssh_target="${spec%% *}"
  local vm="${spec##* }"
  echo "=== $vm ($ssh_target) ==="
  if ! ssh "${SSH_OPTS[@]}" "$ssh_target" 'echo ok' >/dev/null 2>&1; then
    echo "SKIP $vm: SSH unreachable"
    return 1
  fi
  scp "${SSH_OPTS[@]}" "$CACHE/$TARBALL" "$ssh_target:/tmp/$TARBALL"
  ssh "${SSH_OPTS[@]}" "$ssh_target" "bash -s -- $VERSION" <<<"$REMOTE_INSTALL"
  echo "OK $vm"
}

fail=0
ok=0
for g in "${GUESTS[@]}"; do
  if install_one "$g"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
done
echo "Installed $ok guest(s), skipped/failed $fail"
# Do not fail the script when a guest is shut off (e.g. unilever).
exit 0
