# Giám sát KVM — Prometheus + Grafana

Stack giám sát chạy trên hypervisor **ght-faceid-server** (`10.168.1.2/24` và `192.168.3.100/24`). Phạm vi:

- Hypervisor KVM: CPU, RAM, đĩa, load, libvirt (trạng thái từng VM)
- Guest VM: `node_exporter` + ICMP/SSH/HTTP
- Máy vật lý trên LAN: `node_exporter`, nhiệt độ (hwmon / thermal zone), ICMP/SSH
- Megvii AI Box (MegCube): API `GET /v1/MEGBOX/devices`
- Switch Oraybox / 蒲公英: API `GET /cgi-bin/oraybox?_api=ether_status_get` (chỉ cổng LAN)
- Website public: GET domain (200, body, Kong no-route, Cloudflare 502/52x; DNS vs origin `27.72.98.70`)

Thư mục gốc: `/home/ght/deploy/monitoring`. Compose project: `kvm-monitoring`.

---

## Truy cập

| UI | URL |
|----|-----|
| Grafana | http://10.168.1.2:3000 (cũng http://192.168.3.100:3000) |
| Prometheus | http://10.168.1.2:9091 |
| Alertmanager | http://10.168.1.2:9093 |
| json-exporter | http://10.168.1.2:7979 |
| Websites dashboard | http://10.168.1.2:3000/d/websites |

Đăng nhập Grafana: user `admin` (hoặc `GRAFANA_ADMIN_USER` trong `.env`). Mật khẩu: `GRAFANA_ADMIN_PASSWORD` trong `monitoring/.env`. File mẫu: `.env.example`.

Dashboard mặc định (home): **KVM Fleet Overview**. Grafana refresh **10s**. Prometheus scrape mặc định **15s** (job AI Box / Oraybox / website: **1m**).

Cockpit trên host đã chiếm cổng **`:9090`**, nên Prometheus map ra host **`:9091`** (trong container vẫn là `9090`).

---

## Kiến trúc

```
                    ┌─────────────────────────────────────────────┐
                    │           ght-faceid-server (KVM)           │
                    │                                             │
  Guest VMs :9100 ──┤  node-exporter :9100   (host network)       │
  Physical  :9100 ──┤  libvirt-exporter :9177 (libvirt sock-ro)   │
  ICMP/SSH/HTTP  ───┤  blackbox-exporter :9115 (host + NET_RAW)   │
  MEGBOX / Oray API─┤  json-exporter :7979                        │
                    │         ▲                                   │
                    │         │ scrape                            │
                    │  prometheus :9091  ──► alertmanager :9093   │
                    │         │                                   │
                    │  grafana :3000  (datasource Prometheus)     │
                    └─────────────────────────────────────────────┘
```

| Container | Image | Cổng host | Ghi chú |
|-----------|-------|-----------|---------|
| prometheus | `prom/prometheus:v2.55.1` | 9091 → 9090 | TSDB giữ **15 ngày**, `--web.enable-lifecycle` (reload bằng HTTP POST) |
| grafana | `grafana/grafana:11.5.2` | 3000 | Dashboard file-provisioned, home = `kvm-fleet-overview.json` |
| alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Receiver mặc định trống (chưa Telegram/email) |
| blackbox-exporter | `prom/blackbox-exporter:v0.25.0` | 9115 (host network) | ICMP cần `NET_RAW` |
| json-exporter | `prometheuscommunity/json-exporter:v0.7.0` | 7979 | Module `megbox` và `oraybox` |
| node-exporter | `prom/node-exporter:v1.8.2` | 9100 (host network) | Metrics hypervisor |
| libvirt-exporter | `ghcr.io/inovex/prometheus-libvirt-exporter:2.3.1` | 9177 (host network) | Socket `/var/run/libvirt/libvirt-sock-ro` |

Prometheus scrape hypervisor qua `host.docker.internal` (`extra_hosts` → `host-gateway`). Blackbox và node/libvirt exporter chạy `network_mode: host` để ping/TCP đúng từ máy thật.

Volume Docker: `prometheus-data`, `grafana-data`, `alertmanager-data`.

---

## Cấu trúc thư mục

```
monitoring/
├── docker-compose.yml
├── .env / .env.example          GRAFANA_ADMIN_USER / GRAFANA_ADMIN_PASSWORD
├── aibox/
│   └── devices.json             inventory AI Box (nguồn sự thật)
├── websites/
│   ├── sites.json               inventory domain public (nguồn sự thật)
│   └── survey.md                khảo sát DNS/GET / Cloudflare
├── oraybox/
│   ├── devices.json             inventory switch Oraybox
│   └── scan-report.md           kết quả quét LAN 192.168.3.0/24
├── json_exporter/
│   └── config.yml               ánh xạ JSON → metric Prometheus
├── prometheus/
│   ├── prometheus.yml           scrape jobs
│   ├── alerts.yml               recording rules + alert rules
│   └── targets/                 file_sd (icmp / ssh / http / aibox / oraybox)
├── blackbox/blackbox.yml
├── alertmanager/alertmanager.yml
├── grafana/
│   ├── dashboards/              JSON provisioned (folder Grafana: KVM)
│   └── provisioning/            datasource Prometheus + dashboard provider
├── cache/                       tarball node_exporter (amd64 + arm64)
└── scripts/
    ├── gen-aibox-targets.py
    ├── gen-oraybox-targets.py
    ├── gen-website-targets.py   HTTP + DNS origin IP
    ├── gen-dashboards.py        sinh lại toàn bộ dashboard Grafana
    ├── install-node-exporter-guests.sh
    └── install-node-exporter-physical.sh
```

Dashboard Grafana **không sửa tay lâu dài**. Sửa `scripts/gen-dashboards.py` rồi chạy script; Grafana đọc lại file mỗi 30s (`updateIntervalSeconds`).

---

## Khởi động / dừng

```bash
cd /home/ght/deploy/monitoring
docker compose --env-file .env up -d
docker compose ps
docker compose logs -f --tail=80
```

Dừng stack (giữ volume dữ liệu):

```bash
docker compose --env-file .env down
```

Reload Prometheus sau khi sửa `prometheus.yml` / `alerts.yml` (cần `--web.enable-lifecycle`):

```bash
curl -X POST http://127.0.0.1:9091/-/reload
```

File trong `prometheus/targets/*.yml` dùng `file_sd` với `refresh_interval: 30s` — Prometheus tự đọc lại, không bắt buộc reload. Reload vẫn hữu ích khi muốn thấy target ngay.

Sau khi đổi `scrape_interval` của job trong `prometheus.yml`, recreate Prometheus:

```bash
cd /home/ght/deploy/monitoring
docker compose --env-file .env up -d prometheus
```

---

## Inventory

### Hypervisor

| Host | IP LAN | Vai trò |
|------|--------|---------|
| ght-faceid-server | 10.168.1.2, 192.168.3.100 | KVM host, chạy cả stack monitoring |

Job Prometheus: `host` (`:9100`), `libvirt` (`:9177`). Label `role=hypervisor`.

### Guest VM (job `nodes`)

| VM | IP | node_exporter | Ghi chú |
|----|-----|---------------|---------|
| kong-gateway | 10.168.1.104 | :9100 | Production |
| faceid | 10.168.1.55 | :9100 | Production |
| wiseeye | 10.168.1.56 | :9100 | Production |
| chebichat | 10.168.1.59 | :9100 | Production |
| unilever | 10.168.1.58 | :9100 | Optional — alert warning nếu tắt, có thể không SSH được khi shut off |
| nx-vms | (libvirt, shut off) | — | Optional — IP `10.168.1.106` đã chuyển sang máy vật lý `ght-elitedesk` |

Cài `node_exporter` trên guest (systemd, listen `:9100`):

```bash
bash /home/ght/deploy/monitoring/scripts/install-node-exporter-guests.sh
```

Script dùng SSH key (`BatchMode`), cache tarball trong `cache/`. VM không SSH được sẽ `SKIP`.

### Máy vật lý (job `physical`)

| Host | IP | Arch |
|------|-----|------|
| gx10-b273 | 10.168.1.5 | arm64 |
| GHT-Koala-01 | 10.168.1.50 | amd64 |
| intel-nuc7 | 10.168.1.51 | amd64 |
| ght-demo-server | 10.168.1.54 | amd64 |
| ght-dev-server | 192.168.3.101 | amd64 |
| ght-elitedesk | 10.168.1.106 | amd64 | HP EliteDesk 800 G6; hostname OS `ght`; SSH key `ght@`; Nextcloud `:80` |

Hypervisor **không** nằm trong job `physical` (đã có job `host`).

```bash
bash /home/ght/deploy/monitoring/scripts/install-node-exporter-physical.sh
```

Nếu `up{job="physical"} == 0` trên một máy (ví dụ intel-nuc7), dashboard nhiệt độ sẽ không có hwmon/thermal của máy đó.

### Hạ tầng ping (role `infra`)

| Tên | IP | Mục đích |
|-----|-----|----------|
| gateway | 10.168.1.1 | Gateway LAN |
| nas-backup | 10.168.1.3 | NAS backup |

Chỉ ICMP; không cài node_exporter.

---

## Prometheus jobs

Scrape mặc định **15s**, timeout **10s**, `evaluation_interval` 15s. `external_labels.monitor = ght-faceid-server`.

| Job | Target | Chu kỳ | Nội dung |
|-----|--------|--------|----------|
| `prometheus` | localhost:9090 | 15s | Self-scrape |
| `host` | host.docker.internal:9100 | 15s | node_exporter hypervisor |
| `libvirt` | host.docker.internal:9177 | 15s | Domain state, vCPU, RSS; relabel `domain` → `vm` |
| `nodes` | từng guest `:9100` | 15s | OS metrics guest; `instance` = tên VM |
| `physical` | từng máy vật lý `:9100` | 15s | OS metrics; `instance` = hostname |
| `blackbox-icmp` | `targets/icmp*.yml` | 15s | Ping IPv4 |
| `blackbox-ssh` | `targets/ssh*.yml` | 15s | TCP connect `:22` |
| `blackbox-http` | `targets/http*.yml` | 15s | HTTP 200/301/302 |
| `blackbox-http-website` | `targets/websites.yml` | **1m** (timeout 20s) | GET domain public |
| `blackbox-dns-website` | `targets/websites-dns.yml` | **1m** | A vs origin; `website:dns_path` 2=CF / 1=origin / 0=fail |
| `aibox` | `targets/aibox.yml` qua json-exporter | **1m** (timeout 20s) | MEGBOX JSON |
| `oraybox` | `targets/oraybox.yml` qua json-exporter | **1m** (timeout 20s) | Oraybox LAN JSON |

Blackbox probe: Prometheus gửi `__param_target` tới `host.docker.internal:9115` (`/probe`). json-exporter: `__address__` = `json-exporter:7979`.

---

## Blackbox probes

Cấu hình: `blackbox/blackbox.yml`.

| Module | Prober | Timeout | Hành vi |
|--------|--------|---------|---------|
| `icmp` | icmp | 5s | IPv4 only |
| `tcp_connect` | tcp | 5s | SSH `:22` |
| `http_2xx` | http | 8s | GET, follow redirect, chấp nhận 200/301/302, bỏ verify TLS |
| `http_website` | http | 15s | `kind=web` frontend/web-app: **200** cuối, body không rỗng, TLS verify, fail Kong no-route và Cloudflare 502/52x |
| `http_website_api` | http | 15s | `kind=api` service API (không phải SPA): **200 hoặc 404** + JSON (`{`); `{"detail":"Not Found"}` trên GET `/` là **healthy** |
| `http_website_origin` | http | 15s | Giống web, **bỏ verify TLS** (Kong origin `27.72.98.70` cert self-signed `CN=localhost`) |
| `http_website_plain` | http | 15s | HTTP không bắt SSL (dự phòng `xworks.local`) |
| `dns_website_*` | dns | 5s | Query A qua `1.1.1.1`; `probe_success=1` nếu A là `27.72.98.70`. Recording `website:dns_path`: **2** Cloudflare (valid), **1** origin (vàng), **0** DNS fail |

### Website public (`websites/sites.json`)

Sửa JSON rồi:

```bash
python3 /home/ght/deploy/monitoring/scripts/gen-website-targets.py
cd /home/ght/deploy/monitoring && docker compose restart blackbox
curl -sS -X POST http://127.0.0.1:9091/-/reload
```

Healthy HTTP:

- `kind=web` (frontend / web-app): status cuối **200**, có body, không Kong “no Route”, không Cloudflare 502/52x.
- `kind=api` (service API, không phải web-app): GET `/` trả JSON, kể cả `{"detail":"Not Found"}` với **200 hoặc 404** FastAPI, vẫn **healthy**. Vẫn fail Kong no-route và Cloudflare 502/52x.

Ví dụ API: `https://sync.giahungtech.com.vn/` (`kind=api`).

| Điều kiện | Alert / Grafana | Sev |
|-----------|-----------------|-----|
| GET fail (kể cả CF 502) | `WebsiteHTTPDown` | critical (`service`), 2m |
| A record Cloudflare (104.x / 172.67.x, …) | `website:dns_path=2` | **valid** (xanh) — không alert |
| A record direct `27.72.98.70` | `website:dns_path=1` | **vàng** (origin, natural) — không alert |
| DNS fail / NXDOMAIN | `website:dns_path=0` | đỏ trên timeline |

`xworks.local` `enabled: false` (NXDOMAIN). File generated: `prometheus/targets/websites.yml` + `websites-dns.yml` — **không** đặt tên `http-*.yml`.

Khảo sát: `websites/survey.md`. Dashboard: `/d/websites`.

### HTTP ứng dụng (`prometheus/targets/http.yml`)

Sửa file này rồi đợi file_sd 30s, hoặc `POST /-/reload`.

| Target | VM / host | App |
|--------|-----------|-----|
| http://10.168.1.104:8001/status | kong-gateway | kong-status |
| http://10.168.1.55/ | faceid | faceid-web |
| http://10.168.1.56:3128/ | wiseeye | wiseeye-frontend |
| http://10.168.1.56:3003/docs | wiseeye | wiseeye-backend |
| http://10.168.1.59:3000/ | chebichat | chebichat-web |
| http://10.168.1.59:3001/ | chebichat | chebichat-web-vi |
| http://192.168.3.101:3000/api/health | ght-dev-server | fshare-dl |
| http://10.168.1.106/ | ght-elitedesk | nextcloud |

Target HTTP cho AI Box / Oraybox **không** sửa trong `http.yml` — chúng được sinh từ inventory (xem dưới).

---

## Grafana dashboards

Provider: folder **KVM**, file `/var/lib/grafana/dashboards`, cập nhật 30s. Datasource uid `prometheus`, interval 15s.

| File | Title | UID | Tag | Nội dung |
|------|-------|-----|-----|----------|
| `kvm-fleet-overview.json` | KVM Fleet Overview | `kvm-fleet` | kvm | Home: hypervisor + toàn bộ guest, bảng alert |
| `guest-vm-detail.json` | Guest VM Detail | (dropdown `vm`) | kvm | Chi tiết một VM |
| `kvm-host.json` | KVM Host | `kvm-host` | kvm | Hypervisor |
| `physical-hosts-overview.json` | Physical Hosts Overview | | physical | Fleet máy vật lý |
| `physical-host-detail.json` | Physical Host Detail | | physical | Chi tiết một host |
| `physical-temperature.json` | Physical Temperature | `physical-temp` | physical | CPU / NVMe / hwmon mọi bare metal (gồm hypervisor) |
| `aibox-megvii.json` | Megvii AI Box | `aibox-megvii` | aibox | CPU/GPU/case temp, RAM, storage, NTP |
| `oraybox-lan.json` | Oraybox switches | `oraybox-lan` | oraybox | Link LAN `lan1`–`lan4` |

Sinh lại dashboard:

```bash
python3 /home/ght/deploy/monitoring/scripts/gen-dashboards.py
```

---

## Megvii AI Box

Nguồn sự thật: `aibox/devices.json`.

| Name | IP | Model | device_id | serial |
|------|-----|-------|-----------|--------|
| megbox-105 | 10.168.1.105 | MegCube-B4X16-311 | M014101572511120027 | M014101572511120027 |
| megbox-102 | 10.168.1.102 | MegCube-B4H16-311 | M030201202112001534 | M014100742201000875 |

Mỗi scrape (mặc định **1m**) json-exporter `GET http://<ip>/v1/MEGBOX/devices` (module `megbox`). Metric chính:

- `megbox_api_code` — 0 = thành công
- `megbox_info` — identity (model, firmware, serial, license, …)
- `megbox_cpu_usage_percent`, `megbox_cpu_temp_celsius`, `megbox_gpu_temp_celsius`, `megbox_case_temp_celsius`
- `megbox_memory_*_mib`, `megbox_storage_*_mib`
- `megbox_ntp_enabled`, `megbox_ntp_fail_count`

ICMP và HTTP 200 trên cùng URL API chạy theo chu kỳ 15s toàn cục.

Thêm / sửa box trong JSON, rồi:

```bash
python3 /home/ght/deploy/monitoring/scripts/gen-aibox-targets.py
curl -X POST http://127.0.0.1:9091/-/reload
```

Script ghi `prometheus/targets/aibox.yml`, `icmp-aibox.yml`, `http-aibox.yml` (file generated — không sửa tay).

Đổi chu kỳ scrape JSON: sửa `scrape_interval` trong **cả** `aibox/devices.json` và `job_name: aibox` trong `prometheus/prometheus.yml` (Prometheus chỉ tôn trọng field của job), rồi recreate Prometheus.

---

## Oraybox / 蒲公英

Nguồn sự thật: `oraybox/devices.json`. Bốn switch trên `192.168.3.0/24` (OUI `a0:c5:f2`). UI: `http://<ip>/oraybox/index.html`. Báo cáo quét: `oraybox/scan-report.md`.

| Name | IP | MAC |
|------|-----|-----|
| oraybox-2 | 192.168.3.2 | a0:c5:f2:b6:be:9c |
| oraybox-3 | 192.168.3.3 | a0:c5:f2:b6:c0:52 |
| oraybox-10 | 192.168.3.10 | a0:c5:f2:b6:be:b8 |
| oraybox-80 | 192.168.3.80 | a0:c5:f2:b6:be:ae |

Mỗi scrape (**1m**) json-exporter `GET http://<ip>/cgi-bin/oraybox?_api=ether_status_get` (module `oraybox`). Chỉ map cổng **LAN** `lan1`–`lan4` (WAN bỏ qua) thành `oraybox_lan_info` với label `port`, `speed`, `mode`, `link`.

`oraybox-10` thường ping được nhưng `ether_status_get` trả HTTP 500 (`Failed to create CGI process`). Khi đó ICMP vẫn lên; scrape JSON / probe HTTP API xuống cho đến khi box phục hồi.

Thêm / sửa switch:

```bash
python3 /home/ght/deploy/monitoring/scripts/gen-oraybox-targets.py
curl -X POST http://127.0.0.1:9091/-/reload
```

Ghi `oraybox.yml`, `icmp-oraybox.yml`, `http-oraybox.yml`.

Đổi chu kỳ scrape: đồng bộ `oraybox/devices.json` và `job_name: oraybox` trong `prometheus.yml`, rồi `docker compose --env-file .env up -d prometheus`.

**Ràng buộc json-exporter:** mọi metric object cùng `fqName` `oraybox_lan_info` phải dùng **cùng một chuỗi help**. Help khác nhau → process panic.

---

## Recording rules

File `prometheus/alerts.yml`, group `recording`, interval 15s.

| Metric | Ý nghĩa |
|--------|---------|
| `vm:cpu_usage_ratio` | libvirt CPU time / số vCPU |
| `vm:rss_bytes` | RSS domain |
| `guest:root_disk_used_ratio` | Đĩa `/` guest |
| `guest:mem_used_ratio` | RAM guest (1 − MemAvailable/MemTotal) |
| `physical:root_disk_used_ratio` / `physical:mem_used_ratio` | Tương tự máy vật lý |
| `physical:cpu_temp_celsius` | Ưu tiên `coretemp` / `dell_smm` / `x86_pkg_temp`; ARM/SoC fallback `acpitz` / `thermal_thermal_zone`. **Không** dùng cảm biến PCH cho alert CPU |
| `physical:nvme_temp_celsius` | Chip `nvme_*` |
| `physical:temp_max_celsius` | Max hwmon trong khoảng 0–120°C |
| `aibox:mem_used_ratio` / `aibox:storage_used_ratio` | RAM / storage MegCube |
| `oraybox:lan_link_up` | 1 nếu `link="up"`, 0 nếu scrape được nhưng down |
| `website:dns_path` | **2** Cloudflare proxy (valid), **1** A=`27.72.98.70` (vàng), **0** DNS fail |

---

## Cảnh báo

Rules hiển thị tại Prometheus `/alerts` và Grafana Fleet: bảng **Servers / VMs down** (`class=down`) rồi bảng firing còn lại.

Label `class`: `down` (máy/VM/gateway mất hoàn toàn), `service` (HTTP/API), `capacity` (RAM/swap/disk/nhiệt). Ưu tiên cao nhất: `class=down`.

Alertmanager (`alertmanager/alertmanager.yml`): group theo `[alertname, vm, host]`. `class=down` `group_wait` 15s, `repeat_interval` 30m. Critical khác 1h. Receiver `default` **chưa** gửi Telegram/email. Inhibit: VM/host down ức chế SSH/exporter/HTTP phụ trên cùng `vm`/`host`.

### Hypervisor

| Alert | Điều kiện | Severity | For |
|-------|-----------|----------|-----|
| HostSwapHigh | Swap > 80% | warning | 15m |
| HostSwapFull | Swap > 80% **và** MemAvailable < 4 GiB | critical (`capacity`) | 10m |
| HostMemLow | MemAvailable < 4 GiB | critical (`capacity`) | 5m |
| HostLoadHigh | load15 / số CPU > 1.2 | warning | 10m |
| HostDataDiskSpace | `/mnt/data` < 20% trống | warning | 5m |
| HostDataDiskSpaceCritical | `/mnt/data` < 10% trống | critical | 5m |
| HostRootDiskSpace | `/` < 15% trống | warning | 5m |
| LibvirtExporterDown | `up{job="libvirt"}==0` | critical (`down`) | 2m |
| NodeExporterHostDown | `up{job="host"}==0` | critical (`down`) | 2m |

`/mnt/data` chứa đĩa VM.

### Guest / libvirt

| Alert | Phạm vi | Severity |
|-------|---------|----------|
| VMDown | libvirt state ≠ running, VM production | critical (`down`), 1m |
| VMDownOptional | `unilever` tắt | warning, 5m |
| GuestUnreachable | ICMP guest production | critical (`down`), 2m |
| SSHDown | TCP :22 | warning, 3m |
| AppHTTPDown | HTTP probe `role=guest\|physical` | critical (`service`), 2m |
| WebsiteHTTPDown | GET domain; `kind` = web (frontend) hoặc api (service API) | critical (`service`), 2m |
| GuestNodeExporterDown | `up{job="nodes"}==0` | warning, 3m |
| GuestDiskFull / Critical | root > 85% / 95% | warning / critical |
| GuestMemHigh | RAM > 90% | warning, 10m |
| GuestCPUHigh | vCPU > 90% | warning, 15m |
| InfraUnreachable | ping gateway / NAS | critical (`down`), 2m |

VM production: `faceid`, `wiseeye`, `kong-gateway`, `chebichat`. Optional (warning): `unilever`, `nx-vms` (shut off; IP 10.168.1.106 = physical `ght-elitedesk`).

### Máy vật lý + nhiệt độ

| Alert | Ngưỡng | Severity |
|-------|--------|----------|
| PhysicalUnreachable | ICMP fail | critical (`down`), 2m |
| PhysicalSSHDown | :22 đóng | warning, 3m |
| PhysicalNodeExporterDown | job physical down | warning, 3m |
| PhysicalDiskFull / Critical | root > 85% / 95% | warning / critical |
| PhysicalMemHigh | RAM > 90% | warning, 10m |
| PhysicalSwapFull | swap > 80% | warning, 15m |
| PhysicalCPUTempHigh / Critical | CPU > 80°C / 90°C | warning / critical |
| PhysicalNVMeTempHigh / Critical | NVMe > 70°C / 80°C | warning / critical |
| PhysicalTempMissing | node_exporter lên nhưng không có CPU temp | warning, 10m |

### AI Box

| Alert | Ý nghĩa |
|-------|---------|
| AiBoxUnreachable | ping fail (critical `down`) |
| AiBoxApiDown | HTTP API không 200 (critical `service`) |
| AiBoxScrapeFailed | json-exporter không lấy được hardwareStatus |
| AiBoxApiError | `megbox_api_code != 0` |
| AiBoxCPUHigh | CPU > 80%, 10m |
| AiBoxCPUTempHigh / Critical | CPU > 80°C / 90°C |
| AiBoxMemHigh | RAM > 90% |
| AiBoxStorageHigh / Critical | storage > 85% / 95% |
| AiBoxNtpFail | `ntp_fail_count > 0`, 15m |

### Oraybox

| Alert | Ý nghĩa |
|-------|---------|
| OrayboxUnreachable | ping fail (critical `down`) |
| OrayboxApiDown | `ether_status_get` không HTTP 200 (warning — CGI 500 ≠ switch chết) |
| OrayboxScrapeFailed | json-exporter không scrape được |
| OrayboxApiError | `oraybox_api_code != 0` |
| OrayboxAllLanDown | mọi cổng LAN `link=down` (critical `down`) |

---

## Thao tác thường gặp

**Thêm HTTP probe cho app guest:** sửa `prometheus/targets/http.yml` (label `vm`, `app`, `role`). Đợi 30s hoặc reload.

**Thêm guest vào scrape OS:** thêm target trong `job_name: nodes` (`prometheus.yml`), thêm ICMP/SSH trong `icmp.yml` / `ssh.yml`, thêm dòng SSH vào `install-node-exporter-guests.sh`, reload Prometheus, chạy script cài exporter.

**Thêm máy vật lý:** tương tự job `physical` + `icmp.yml` + `ssh.yml` + script physical.

**Sinh lại dashboard sau khi đổi panel/query:** `python3 scripts/gen-dashboards.py`.

**Xem target sống:** Prometheus → Status → Targets, hoặc `up` / `probe_success`.

---

## Cổng trên host

| Cổng | Dịch vụ |
|------|---------|
| 3000 | Grafana |
| 7979 | json-exporter |
| 9091 | Prometheus (9090 trong container) |
| 9093 | Alertmanager |
| 9100 | node-exporter hypervisor |
| 9115 | blackbox-exporter |
| 9177 | libvirt-exporter |
| 9090 | **Cockpit** (không dùng cho Prometheus) |

---

## Ghi chú vận hành

- Mật khẩu Grafana trong `.env` có thể **không khớp** instance đang chạy nếu Grafana đã khởi tạo volume trước khi đổi password. Khi API trả 401, đặt lại password trong UI hoặc xóa volume Grafana (mất dashboard tùy biến trên UI).
- `json-exporter` panic nếu hai metric cùng tên khác help string — đặc biệt module `oraybox` (`oraybox_lan`).
- `oraybox-10` (192.168.3.10): ICMP lên, CGI `ether_status_get` hay 500.
- Cảm biến nhiệt: GHT-Koala-01, gx10-b273 (ARM acpitz + NVMe), ght-demo-server, ght-dev-server, ght-elitedesk, ght-faceid-server (job `host`). intel-nuc7 không có metric nhiệt nếu `up{job="physical"}==0`.
- Retention Prometheus: **15 ngày** (`--storage.tsdb.retention.time=15d`).
- Swap hypervisor: `/swap.img` (8G) + `/swapfile` (24G) trên filesystem `/` (không đặt trên `/mnt/data`). `vm.swappiness=10` trong `/etc/sysctl.d/99-kvm-host-vm.conf`. `HostSwapFull` **chỉ** critical khi swap > 80% **và** MemAvailable < 4 GiB (10m) — đường stall/OOM. Swap đầy mà RAM còn dư → `HostSwapHigh` warning. `/mnt/data` ~64% used chưa đụng ngưỡng 80%.

## Keep (quản lý alarm)

Keep inbox đang chạy: **http://10.168.1.2:3001** (user `keep`, password `KEEP_DEFAULT_PASSWORD` trong `.env`). Grafana vẫn http://10.168.1.2:3000. **Chưa gửi Telegram.** Chi tiết: `keep/README.md`, kế hoạch `keep/PLAN.md`.
)
