# KVM monitoring (Prometheus + Grafana)

Phase 0–2 stack on the KVM host: hypervisor metrics, per-guest OS metrics, ICMP/SSH/HTTP probes.

## Access

| UI | URL |
|----|-----|
| Grafana | http://10.168.1.2:3000 (also http://192.168.3.100:3000) |
| Prometheus | http://10.168.1.2:9091 |
| Alertmanager | http://10.168.1.2:9093 |

Grafana login: `admin` / password in `monitoring/.env` (`GRAFANA_ADMIN_PASSWORD`).

Home dashboard: **KVM Fleet Overview**. Per-VM: **Guest VM Detail** (dropdown `vm`). Hypervisor: **KVM Host**. Physical LAN hosts: **Physical Hosts Overview** / **Physical Host Detail**. Temperature (all bare metal, including hypervisor): **Physical Temperature**. Megvii AI Box: **Megvii AI Box**.

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

Physical Ubuntu hosts (not `10.168.1.2`):

```bash
bash /home/ght/deploy/monitoring/scripts/install-node-exporter-physical.sh
```

| Host | IP | Arch |
|------|----|------|
| gx10-b273 | 10.168.1.5 | arm64 |
| GHT-Koala-01 | 10.168.1.50 | amd64 |
| intel-nuc7 | 10.168.1.51 | amd64 |
| ght-demo-server | 10.168.1.54 | amd64 |
| ght-dev-server | 192.168.3.101 | amd64 |

## HTTP probes

Edit `prometheus/targets/http.yml` then Prometheus reloads the file_sd automatically (30s), or:

```bash
curl -X POST http://127.0.0.1:9091/-/reload
```

## Megvii AI Box

Inventory (source of truth): `aibox/devices.json`. Two MegCube boxes on the physical LAN:

| Name | IP | Model |
|------|----|-------|
| megbox-105 | 10.168.1.105 | MegCube-B4X16-311 |
| megbox-102 | 10.168.1.102 | MegCube-B4H16-311 |

Every scrape (default **1m**) json_exporter `GET`s `http://<ip>/v1/MEGBOX/devices` and maps `hardwareStatus` (CPU %, CPU/GPU/case temp, RAM, storage) plus identity (`deviceModel`, firmware, serial) into Prometheus. ICMP and HTTP 200 probes run on the global 15s interval.

Add/edit a box in the JSON, then:

```bash
python3 /home/ght/deploy/monitoring/scripts/gen-aibox-targets.py
curl -X POST http://127.0.0.1:9091/-/reload
```

To change the JSON scrape interval, set `scrape_interval` in `aibox/devices.json` **and** `job_name: aibox` in `prometheus/prometheus.yml` (Prometheus only honors the job field), then recreate Prometheus:

```bash
cd /home/ght/deploy/monitoring
docker compose --env-file .env up -d prometheus
```

Grafana dashboard **Megvii AI Box** (uid `aibox-megvii`). json_exporter listens on `:7979`.

## Oraybox switches

Inventory: `oraybox/devices.json`. Four 蒲公英 / Oraybox switches on `192.168.3.0/24`:

| Name | IP | MAC |
|------|----|-----|
| oraybox-2 | 192.168.3.2 | a0:c5:f2:b6:be:9c |
| oraybox-3 | 192.168.3.3 | a0:c5:f2:b6:c0:52 |
| oraybox-10 | 192.168.3.10 | a0:c5:f2:b6:be:b8 |
| oraybox-80 | 192.168.3.80 | a0:c5:f2:b6:be:ae |

`oraybox-10` answers ICMP; `ether_status_get` currently returns HTTP 500 (`Failed to create CGI process`), so API/JSON scrape stay down until the box recovers.

Every scrape (default **1m**) json_exporter `GET`s `http://<ip>/cgi-bin/oraybox?_api=ether_status_get` and maps **LAN** ports (`lan1`–`lan4`: link, speed, mode) into `oraybox_lan_info`. WAN is ignored. ICMP and HTTP 200 probes on the same API URL run on the global 15s interval.

Add/edit a switch in the JSON, then:

```bash
python3 /home/ght/deploy/monitoring/scripts/gen-oraybox-targets.py
curl -X POST http://127.0.0.1:9091/-/reload
```

To change the JSON scrape interval, set `scrape_interval` in `oraybox/devices.json` **and** `job_name: oraybox` in `prometheus/prometheus.yml`, then:

```bash
cd /home/ght/deploy/monitoring
docker compose --env-file .env up -d prometheus
```

Grafana dashboard **Oraybox switches** (uid `oraybox-lan`).

## Alerts

Rules: `prometheus/alerts.yml`. They show on Prometheus `/alerts` and the fleet dashboard table (`ALERTS{alertstate="firing"}`).

Alertmanager has no Telegram/email receiver yet — add one in `alertmanager/alertmanager.yml` when a bot token exists.

## Layout

```
monitoring/
├── docker-compose.yml
├── aibox/               Megvii AI Box inventory (devices.json)
├── oraybox/             Oraybox switch inventory (devices.json)
├── json_exporter/       MEGBOX + Oraybox JSON → Prometheus metrics
├── prometheus/          scrape + alerts + file_sd targets
├── blackbox/
├── alertmanager/
├── grafana/dashboards/  provisioned JSON
└── scripts/
```
