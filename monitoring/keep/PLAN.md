# Kế hoạch triển khai Keep song song kvm-monitoring

**Trạng thái:** plan + khung file. **Chưa `docker compose up` Keep, chưa sửa Alertmanager đang chạy.**

Giai đoạn hiện tại: Keep là **inbox alarm**. Grafana giữ vai trò quan sát fleet. **Không gửi Telegram / OTT** cho đến Phase 2 (go/no-go riêng).

Thư mục này: `/home/ght/deploy/monitoring/keep`.

Khảo sát host **2026-09-21** trên `ght-faceid-server`.

---

## 0. Quyết định kiến trúc

### 0.1 Nguồn alert

**Đường chính (A):** Prometheus `alerts.yml` → Alertmanager `:9093` → webhook Keep `POST /alerts/event/prometheus`.

**Đường dự phòng (B):** Grafana Unified Alerting contact point webhook → `POST /alerts/event/grafana`. **Không bật** trừ khi A hỏng.

Lý do chọn A:

- Toàn bộ rule production đã nằm trong `prometheus/alerts.yml` (libvirt, blackbox, node, AI Box, Oraybox). Grafana 11.5.2 trên host **không** có contact point provisioned (`GET /api/v1/provisioning/contact-points` → 401, thư mục provisioning chỉ datasource + dashboard).
- Keep khuyến nghị **push**; pull Grafana/Prometheus mất workflow automation và lệch chu kỳ (`KEEP_PULL_INTERVAL`).
- Bật cả A và B → **trùng notify** cùng một `alertname`.

Keep **không** pull Grafana trong Phase 0–1 (`KEEP_PULL_DATA_ENABLED=false`, `install_webhook: false`).

### 0.2 Gắn Compose

**Chọn overlay** `keep/docker-compose.yml` cùng project name `kvm-monitoring`.

| | Overlay cùng project (chọn) | Project thứ hai `keep` |
|--|-----------------------------|-------------------------|
| DNS nội bộ | `keep-backend`, `alertmanager`, `grafana`, `prometheus` trên `kvm-monitoring_default` | Phải `external: kvm-monitoring_default` rồi dùng tên service |
| Lệnh | `docker compose -f docker-compose.yml -f keep/docker-compose.yml` | Hai lệnh `up`, hai `ps` |
| Upgrade Keep | Sửa overlay, không đụng image Prometheus/Grafana | Tách hẳn, dễ quên network |
| Backup | Volume `keep-data` cạnh `prometheus-data` | Volume project khác |
| Rủi ro | `compose down` không chỉ định file có thể chỉ dừng file mặc định | Container Keep sống sót khi down monitoring |

Cùng host, cùng `restart: unless-stopped`. **Không** đổi image/cổng stack hiện tại. **Không** đụng Cockpit `:9090`.

### 0.3 Cổng (đã kiểm `ss` 2026-09-21)

| Dịch vụ | Cổng host | Trạng thái |
|---------|-----------|------------|
| Keep UI | **3001** → container 3000 | **trống** |
| Keep API | **8080** → 8080 | **trống** |
| Soketi WS | **6001** → 6001 | **trống** |
| Soketi metrics | `127.0.0.1:9601` | **trống** |

Bận: 3000 Grafana, 7979 json-exporter, 9090 Cockpit, 9091 Prometheus, 9093 Alertmanager, 9100 node-exporter, 9115 blackbox, 9177 libvirt.

Canonical URL (giống `GF_SERVER_ROOT_URL`): `http://10.168.1.2:3001`. Bind `0.0.0.0` trên hypervisor LAN; client `192.168.3.100` dùng IP `10.168.1.2` cho NextAuth/WebSocket.

### 0.4 Image và thành phần

- `keep-backend`: `us-central1-docker.pkg.dev/keephq/keep/keep-api:0.54.2` (tag GitHub `v0.54.2`, 2026-07-13)
- `keep-frontend`: `keep-ui:0.54.2`
- `keep-websocket-server`: `quay.io/soketi/soketi:1.4-16-debian`
- DB Phase 0–2: **SQLite** volume `keep-data` (`/state/db.sqlite3`). Fleet nhỏ; Postgres chỉ khi SQLite lock/slow.
- Redis/ARQ: tắt (mặc định). Scheduler workflow Keep: bật sẵn, không có workflow Telegram cho đến Phase 2.

Kéo image trước khi up. Nếu tag 0.54.2 404, pin digest của `:latest` lúc đó.

### 0.5 Telegram

Workflow mẫu: `workflows/examples/critical-telegram.yml` (`disabled: true`). **Không** mount vào `KEEP_WORKFLOWS_DIRECTORY` active. Không điền `TELEGRAM_BOT_TOKEN` cho đến Phase 2.

---

## 1. Khảo sát (đã làm — lặp lại trước mỗi phase)

### Mục đích

Chốt file đang chạy, alert đang fire, Grafana contact point, cổng trống.

### File đã đọc

- `docker-compose.yml` — project `kvm-monitoring`, network `kvm-monitoring_default`
- `alertmanager/alertmanager.yml` — receiver `default` **trống**, route critical chỉ đổi `group_wait`/`repeat_interval`, inhibit critical→warning theo `[alertname, vm]`
- `prometheus/alerts.yml` — recording + 5 group: `host`, `vms`, `physical`, `aibox`, `oraybox`
- Grafana provisioning: datasource Prometheus + dashboards file; **không** có alerting contact point
- `prometheus/prometheus.yml` — `external_labels.monitor=ght-faceid-server`, scrape 15s, aibox/oraybox 1m

### Alert đang fire (2026-09-21, `GET :9091/api/v1/alerts`)

| State | Severity | Alert | Đối tượng |
|-------|----------|-------|-----------|
| firing | critical | `AppHTTPDown` | host=oraybox-10, job=blackbox-http |
| firing | (cleared) | `HostSwapFull` | hypervisor — swap ~6%, MemAvailable ~14 GiB; rule now requires RAM+swap exhaustion |
| firing | critical | `OrayboxApiDown` | oraybox-10 |
| firing | warning | `OrayboxScrapeFailed` | oraybox-10 |
| firing | warning | `PhysicalNodeExporterDown` | intel-nuc7 |
| firing | warning | `PhysicalSSHDown` | intel-nuc7 |
| firing | critical | `PhysicalUnreachable` | intel-nuc7 |
| firing | warning | `VMDownOptional` | unilever |

`AppHTTPDown` đã thu hẹp `role=~"guest|physical"`. Oraybox CGI 500 là `OrayboxApiDown` warning.

### Lệnh lặp lại

```bash
bash /home/ght/deploy/monitoring/keep/scripts/query-alerts.sh
ss -tln | grep -E ':3001|:8080|:6001|:9090|:3000 '
curl -sS http://127.0.0.1:9093/-/ready
```

### Tiêu chí xong

Bảng fire/pending mới nhất; cổng 3001/8080/6001 vẫn trống; AM `ready`.

### Rollback

Không đổi production ở bước khảo sát.

---

## 2. Kiến trúc mục tiêu

```
 Guest/physical/AI Box/Oraybox
        │  scrape 15s (aibox/oraybox 1m)
        ▼
 prometheus :9091  ──►  grafana :3000   (datasource, dashboard fleet)
        │ evaluate 15s
        │ alerts.yml
        ▼
 alertmanager :9093
        │ webhook (Phase 1+)  POST /alerts/event/prometheus
        │ basic_auth api_key / KEEP_WEBHOOK_API_KEY
        ▼
 keep-backend :8080  ──sqlite── keep-data
        │
        ├── keep-frontend :3001   inbox / ack / preset
        ├── keep-websocket :6001  realtime UI
        └── (Phase 2) workflow Telegram
```

Grafana **không** thay Nightingale, **không** migrate dashboard. Keep **không** phải nguồn metrics. TSDB Prometheus **15 ngày** giữ nguyên.

Deep link Grafana:

| Role | URL |
|------|-----|
| fleet | http://10.168.1.2:3000/d/kvm-fleet |
| hypervisor | http://10.168.1.2:3000/d/kvm-host |
| guest | http://10.168.1.2:3000/d/kvm-guest?var-vm=FACEID |
| physical | http://10.168.1.2:3000/d/physical-host?var-host=HOST |
| nhiệt độ | http://10.168.1.2:3000/d/physical-temp |
| AI Box | http://10.168.1.2:3000/d/aibox-megvii?var-host=HOST |
| Oraybox | http://10.168.1.2:3000/d/oraybox-lan?var-host=HOST |
| AM | http://10.168.1.2:9093 |

---

## 3. Map rule `prometheus/alerts.yml` → Keep / Telegram

Telegram cột = **Phase 2+**. Phase 0–1: mọi dòng “Keep inbox” chỉ hiện UI.

### Hypervisor (`group: host`)

| Alert | Sev | Keep | Telegram Phase 2 | Ghi chú |
|-------|-----|------|------------------|---------|
| NodeExporterHostDown | critical | inbox | có | |
| LibvirtExporterDown | critical | inbox | có | |
| HostMemLow | critical | inbox | có | RAM &lt; 4 GiB |
| HostSwapFull | critical | inbox | có | swap>80% **và** MemAvailable<4GiB 10m; swap đầy + RAM dư chỉ `HostSwapHigh` |
| HostDataDiskSpaceCritical | critical | inbox | có | `/mnt/data` &lt; 10% |
| HostDataDiskSpace | warning | inbox | không | `/mnt/data` &lt; 20% |
| HostRootDiskSpace | warning | inbox | không | |
| HostLoadHigh | warning | inbox | delay 30m (tùy chọn) | user muốn “load kéo dài”; rule hiện 10m warning |

### Guest / libvirt (`group: vms`)

| Alert | Sev | Keep | Telegram Phase 2 |
|-------|-----|------|------------------|
| VMDown | critical | inbox | có (prod: faceid, wiseeye, kong-gateway, chebichat, nx-vms) |
| VMDownOptional | warning | inbox | **không** (unilever) — **đang fire** |
| GuestUnreachable | critical | inbox | có |
| AppHTTPDown | critical (`service`) | inbox | `role=~"guest|physical"` |
| SSHDown | warning | inbox | host prod, delay |
| GuestNodeExporterDown | warning | inbox | delay / không page |
| GuestDiskFullCritical | critical | inbox | có |
| GuestDiskFull / GuestMemHigh / GuestCPUHigh | warning | inbox | không |
| InfraUnreachable | critical (`down`) | inbox | có (gateway/NAS ping fail) |

### Physical

| Alert | Sev | Keep | Telegram Phase 2 |
|-------|-----|------|------------------|
| PhysicalUnreachable | critical | inbox | có, **trừ intel-nuc7** (silence/maintenance) — **đang fire** |
| PhysicalSSHDown / PhysicalNodeExporterDown | warning | inbox | không (nuc7 đã biết) |
| PhysicalDiskFullCritical | critical | inbox | có |
| PhysicalDiskFull / MemHigh / SwapFull | warning | inbox | không |
| PhysicalCPUTempHigh / Critical, NVMe* | warning/critical | inbox | Telegram chỉ Critical, trừ spike ngắn |
| PhysicalTempMissing | warning | inbox | không |

### AI Box

| Alert | Keep | Telegram Phase 2 |
|-------|------|------------------|
| AiBoxUnreachable, AiBoxApiDown | inbox | có |
| AiBoxScrapeFailed, AiBoxApiError | inbox | không |
| AiBoxCPUTempCritical, AiBoxStorageCritical | inbox | có |
| AiBoxCPUHigh, CPUTempHigh, MemHigh, StorageHigh, NtpFail | inbox | không |

### Oraybox

| Alert | Keep | Telegram Phase 2 |
|-------|------|------------------|
| OrayboxUnreachable | inbox | có |
| OrayboxApiDown | inbox | có, **trừ oraybox-10** CGI 500 đã biết — **đang fire** |
| OrayboxAllLanDown | inbox | có |
| OrayboxScrapeFailed / OrayboxApiError | inbox | không |

### Việc sửa rule (Phase 3, không chặn Phase 0)

1. `AppHTTPDown` đã thu hẹp `role=~"guest|physical"` (Oraybox/AI Box HTTP dùng rule riêng).
2. Silence / inhibit: `host="intel-nuc7"`, `host="oraybox-10"` cho API/HTTP, `alertname="VMDownOptional"`.
3. Inhibit `equal: [alertname, vm, host]` (bản AM hiện chỉ `vm` — Oraybox/physical không có `vm`).

---

## 4. File và cấu hình

### Overlay Compose

File: `keep/docker-compose.yml` (đã viết sẵn).

Lệnh (Phase 0, **chưa chạy**):

```bash
cd /home/ght/deploy/monitoring
# 1) biến môi trường
cat keep/.env.example  # copy KEEP_* vào .env, đổi secret
umask 077
printf '%s' "$KEEP_WEBHOOK_API_KEY" > alertmanager/keep_webhook_password

# 2) kéo image
docker pull us-central1-docker.pkg.dev/keephq/keep/keep-api:0.54.2
docker pull us-central1-docker.pkg.dev/keephq/keep/keep-ui:0.54.2
docker pull quay.io/soketi/soketi:1.4-16-debian

# 3) up overlay
docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml up -d
docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml ps
```

Alertmanager trong overlay nhận thêm volume `keep_webhook_password`.

### `.env`

Nguồn: `keep/.env.example` → `monitoring/.env` (gitignored). Không commit token.

`KEEP_DEFAULT_API_KEYS=alertmanager:webhook:<secret>` phải **trùng** `KEEP_WEBHOOK_API_KEY` và nội dung `alertmanager/keep_webhook_password`.

### Alertmanager

Mẫu: `keep/alertmanager/alertmanager.phase0.yml` và `alertmanager.phase1.yml`.

Webhook Keep (tài liệu Keep Prometheus provider):

```yaml
receivers:
  - name: keep
    webhook_configs:
      - url: http://keep-backend:8080/alerts/event/prometheus
        send_resolved: true
        http_config:
          basic_auth:
            username: api_key
            password_file: /etc/alertmanager/keep_webhook_password
```

DNS: `keep-backend` chỉ resolve khi Keep nằm **cùng** network compose (overlay).

Reload AM:

```bash
docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml restart alertmanager
# hoặc
curl -X POST http://127.0.0.1:9093/-/reload
```

### Grafana webhook (đường B — không bật)

Contact point thủ công, **không** file-provision dashboard. Policy mặc định Grafana giữ nguyên. Chỉ tạo khi A fail.

### Workflow Telegram (Phase 2)

`keep/workflows/examples/critical-telegram.yml` — template tin ngắn, link fleet + AM + Keep. Copy vào `workflows/active/` + `KEEP_WORKFLOWS_DIRECTORY=/workflows` khi go Phase 2.

### Dashboard Grafana “alerts firing”

KVM Fleet Overview **đã có** bảng `ALERTS{alertstate="firing"}`. Phase 0 **không** sửa `gen-dashboards.py`. Tùy chọn Phase 3: thêm filter `severity="critical"` nếu bảng quá đông.

---

## 5. Trực quan hóa quản lý alarm

Keep UI (`:3001`) = inbox:

- Preset **Critical firing**
- Preset **Hypervisor** (`job=host|libvirt` hoặc `vm=hypervisor`)
- Preset **Guest prod** (`role=guest`, trừ unilever)
- Preset **AI Box** (`role=aibox`)
- Preset **Oraybox** (`role=oraybox`)
- Preset **Known noisy** (intel-nuc7, oraybox-10, unilever) — ack / maintenance window

Keep **không** vẽ CPU/RAM. Grafana vẫn home **KVM Fleet Overview**, refresh 10s.

Ack trên Keep không silence Prometheus; silence AM khi muốn ngừng webhook (Phase 3).

---

## 6. Bảo mật và vận hành

- Auth UI: `AUTH_TYPE=DB`, user `KEEP_DEFAULT_USERNAME`. Đổi password ngay lần đầu.
- PostHog/Sentry/demo: tắt trong compose.
- Bind: cổng Keep trên LAN hypervisor; Soketi metrics chỉ `127.0.0.1:9601`.
- Backup: `docker volume inspect kvm-monitoring_keep-data` + `sqlite3` copy `/state/db.sqlite3`. Cùng lịch backup volume Grafana/Prometheus.
- Log: `docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml logs -f --tail=80 keep-backend keep-frontend`
- Health: `wget`/`python` `http://127.0.0.1:8080/docs`; UI `/`; AM `/-/ready`; Grafana `/api/health`.
- Retention TSDB: **không đổi** 15d.
- Secret: `.env`, `alertmanager/keep_webhook_password` (gitignore).

---

## 7. Thứ tự cắt sóng

### Phase 0 — Keep lên, test webhook, production AM giữ `default` rỗng

**Mục đích:** UI Keep chạy; Alertmanager chưa đẩy fleet.

**File:** overlay compose, `.env`, `keep_webhook_password`, copy `alertmanager.phase0.yml` → `alertmanager/alertmanager.yml`.

**Lệnh:** pull + `compose up -d` overlay; `bash keep/scripts/test-webhook.sh`.

**Xong khi:**

- `keep-backend` healthy, UI login được
- `KeepWebhookTest` hiện inbox
- 8 alert đang fire **không** xuất hiện trong Keep (route production vẫn `default`)
- Grafana `:3000` và Prometheus `:9091` bình thường
- `docker compose ps` stack cũ healthy

**Go:** UI ổn, webhook 2xx. **No-go:** image 404, cổng conflict, AM fail parse yaml.

**Rollback:**

```bash
cd /home/ght/deploy/monitoring
git checkout -- alertmanager/alertmanager.yml
docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml stop keep-backend keep-frontend keep-websocket-server
docker compose --env-file .env up -d alertmanager
```

Volume `keep-data` giữ lại.

### Phase 1 — mọi alert vào Keep inbox, không Telegram

**Mục đích:** Inbox phản ánh AM; **không** OTT.

**File:** `alertmanager.phase1.yml` → `alertmanager/alertmanager.yml`.

**Xong khi:** 8 alert đang fire (hoặc tập hiện tại) xuất hiện Keep; **không** có tin Telegram; Grafana dashboard đọc `ALERTS{}` như cũ.

**Go:** AM webhook 2xx liên tục 15 phút, Keep không 5xx. **No-go:** spam UI do flap (chưa Telegram nên rủi ro thấp).

**Rollback:** trở lại `alertmanager.phase0.yml` hoặc receiver `default` rỗng.

**Silence ngay trong Keep/AM** cho intel-nuc7, oraybox-10 CGI, unilever — nếu không inbox sẽ đầy “đã biết”.

### Phase 2 — critical → Telegram (sau này)

**Mục đích:** chỉ page bất thường cần người.

**Điều kiện:** Phase 1 ổn ≥ 1–2 ngày; bot token; CEL workflow loại trừ `host=~"intel-nuc7|oraybox-10"` và `alertname=VMDownOptional`. `AppHTTPDown` đã thu hẹp `role=~"guest|physical"`.

**Xong khi:** một critical giả (label `keep_test`) ra Telegram một lần; repeat AM 1h không nhân tin (Keep dedup); resolve gửi 1 tin resolved.

**Rollback:** xóa/disable workflow, restart backend; AM vẫn đẩy inbox.

**Giai đoạn hiện tại: dừng sau Phase 1.** Không cấu hình bot.

### Phase 3 — flap ICMP/libvirt

- `group_wait` ICMP 30s–1m; inhibit `GuestUnreachable` khi `VMDown` cùng `vm`
- `AppHTTPDown` đã thu hẹp `role=~"guest|physical"`
- Maintenance window Keep cho nuc7 / oraybox-10
- Tùy chọn panel Fleet chỉ critical (qua `gen-dashboards.py`)

---

## 8. Kiểm thử

| Case | Cách | Kỳ vọng |
|------|------|---------|
| Webhook Keep | `scripts/test-webhook.sh` | Alert `KeepWebhookTest` trên UI |
| Disk hypervisor | Promtool / temporarily lower HostDataDiskSpace (cẩn thận) hoặc annotation test | Phase 1: inbox |
| Ping gateway | `iptables` DROP icmp tới 10.168.1.1 trên host **rất ngắn** | `InfraUnreachable` sau 2m; revert ngay |
| Libvirt domain | **Không** shutdown VM prod. Dùng `unilever` nếu chấp nhận warning đã có |
| json-exporter megbox | `curl http://10.168.1.105/v1/MEGBOX/devices` | So với metric `megbox_*` |
| json-exporter oraybox | `curl http://192.168.3.2/cgi-bin/oraybox?_api=ether_status_get` | oraybox-10 = 500 (đã biết) |
| Dedup | `repeat_interval` AM | Keep 1 fingerprint; Phase 2: 1 tin Telegram |
| Resolve | `send_resolved: true` | Keep status resolved; Phase 2: 1 tin resolved (policy đã chốt: **có** tin resolved cho critical) |
| Keep down | `docker stop keep-backend` | AM vẫn nhận Prometheus; Grafana dashboard bình thường; webhook AM fail (log) |
| Keep up lại | `docker start keep-backend` | AM `repeat_interval` không storm; Keep ingest group hiện tại |

---

## 9. Rủi ro

| Rủi ro | Xử lý |
|--------|--------|
| Telegram API chặn từ LAN VN | Phase 2: `HTTPS_PROXY` trên keep-backend hoặc Bot API local. **Chưa làm.** |
| Trùng notify Grafana + AM | `install_webhook: false`; không tạo Grafana contact point |
| unilever optional | Không Telegram; preset riêng |
| intel-nuc7 / oraybox-10 noise | Silence/maintenance trước Phase 1 |
| `AppHTTPDown` nuốt Oraybox | Đã thu hẹp `role=~"guest|physical"` |
| file_sd 30s vs evaluate 15s | Alert có thể trễ 1 scrape; không đổi |
| Overlay `compose down` thiếu `-f keep/...` | Keep container còn; ghi rõ lệnh trong runbook |
| SQLite lock | Monitor; Postgres sau |
| Dual URL 10.168.1.2 vs 192.168.3.100 | Canonical 10.168.1.2 (cùng Grafana) |
| Image tag 0.54.2 không pull được | Pin digest `:latest` lúc Phase 0 |
| Swap hypervisor | `HostSwapFull` chỉ khi RAM cũng < 4 GiB; swappiness=10. MemAvailable ~11–14 GiB, `/mnt/data` 64% |
| password_file AM thiếu | AM crash config — tạo file trước `up` |

---

## 10. Checklist triển khai (khi được phép)

Phase 0:

1. [ ] `query-alerts.sh` lưu snapshot
2. [ ] Copy `keep/.env.example` → `.env`, generate secret
3. [ ] `printf` `keep_webhook_password`
4. [ ] `docker pull` 3 image
5. [ ] Overlay `up -d` — **không** copy phase1 AM
6. [ ] Login http://10.168.1.2:3001
7. [ ] `test-webhook.sh`
8. [ ] Xác nhận Grafana/Prometheus/AM cũ healthy
9. [ ] (Tùy) copy `alertmanager.phase0.yml` nếu muốn AM có receiver keep cho test label

Dừng tại đây cho đến khi có quyết định Phase 1.

---

## 11. Lệnh rollback khẩn

```bash
cd /home/ght/deploy/monitoring
git checkout -- alertmanager/alertmanager.yml
docker compose --env-file .env up -d alertmanager
docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml stop \
  keep-backend keep-frontend keep-websocket-server
```

Grafana `:3000`, Prometheus `:9091`, Cockpit `:9090` không đổi.
