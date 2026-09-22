#!/usr/bin/env bash
# Overlay Keep vào project kvm-monitoring. Chạy từ bất kỳ cwd nào.
#   bash keep/up.sh up -d
#   bash keep/up.sh ps
#   bash keep/up.sh logs -f --tail=80 keep-backend keep-frontend
#   bash keep/up.sh stop keep-backend keep-frontend keep-websocket-server
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ ! -f .env ]]; then
  echo "missing $ROOT/.env (KEEP_JWT_SECRET, KEEP_DEFAULT_PASSWORD, …)" >&2
  exit 1
fi
if ! grep -q '^KEEP_JWT_SECRET=.\+' .env; then
  echo "KEEP_JWT_SECRET empty in $ROOT/.env" >&2
  exit 1
fi
exec docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml "$@"
