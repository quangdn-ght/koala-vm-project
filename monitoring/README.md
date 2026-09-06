# KVM monitoring (Prometheus + Grafana)

Phase 0–2 stack on the KVM host: hypervisor metrics, per-guest OS metrics, ICMP/SSH/HTTP probes.

## Access

| UI | URL |
|----|-----|
| Grafana | http://10.168.1.2:3000 (also http://192.168.3.100:3000) |
| Prometheus | http://10.168.1.2:9091 |
| Alertmanager | http://10.168.1.2:9093 |

Grafana login: `admin` / password in `monitoring/.env` (`GRAFANA_ADMIN_PASSWORD`).

Home dashboard: **KVM Fleet Overview**. Per-VM: **Guest VM Detail** (dropdown `vm`). Host: **KVM Host**.

Refresh is 10s; Prometheus scrape is 15s.

## Start / stop

```bash
cd /home/ght/deploy/monitoring
docker compose --env-file .env up -d
docker compose ps
docker compose logs -f --tail=80
```

Cockpit already uses `:9090`; Prometheus is mapped to **`:9091`**.

## Guest node_exporter

```bash
bash /home/ght/deploy/monitoring/scripts/install-node-exporter-guests.sh
```

Installs systemd `node_exporter` on `:9100`. Skip VMs with no SSH (currently `unilever` if shut off).

## HTTP probes

Edit `prometheus/targets/http.yml` then Prometheus reloads the file_sd automatically (30s), or:

```bash
curl -X POST http://127.0.0.1:9091/-/reload
```

## Alerts

Rules: `prometheus/alerts.yml`. They show on Prometheus `/alerts` and the fleet dashboard table (`ALERTS{alertstate="firing"}`).

Alertmanager has no Telegram/email receiver yet — add one in `alertmanager/alertmanager.yml` when a bot token exists.

## Layout

```
monitoring/
├── docker-compose.yml
├── prometheus/          scrape + alerts + file_sd targets
├── blackbox/
├── alertmanager/
├── grafana/dashboards/  provisioned JSON
└── scripts/
```
