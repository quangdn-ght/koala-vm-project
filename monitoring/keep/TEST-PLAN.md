# Test plan mockup — lỗi hạ tầng / hệ thống → Keep

Mục tiêu: bắn **cảnh báo giả** vào Keep (http://10.168.1.2:3001) để luyện inbox, filter `class=down`, ack — **không** shutdown VM prod, **không** DROP ICMP trên gateway.

Telegram **tắt**. Nguồn mock: webhook Keep (`POST /alerts/event/prometheus`), label bắt buộc `keep_test=true`.

Live thật (Prometheus → Alertmanager → Keep) chỉ dùng khi đã duyệt; cột “Live drill” dưới đây là hướng dẫn, mặc định **không chạy**.

---

## 1. Nguyên tắc

| | |
|--|--|
| Ưu tiên xem trên Keep | `class=down` (máy/VM/gateway mất hẳn) |
| Service | host vẫn ping, HTTP/SSH/API chết (`class=service`) |
| Capacity | RAM+swap, disk, nhiệt — nguy cơ treo/shutdown (`class=capacity`) |
| Filter Keep | `keep_test="true"` (tách khỏi alert production) |
| Fingerprint | `mock-<ID>` — resolve cùng ID để đóng alert |
| Grafana | vẫn là nơi xem metric; Keep là inbox |

Baseline production hiện tại (không phải mock): `VMDownOptional` unilever, `OrayboxApiDown` oraybox-10 (CGI 500, ping được).

---

## 2. Chạy mock

```bash
# secret từ monitoring/.env
set -a; . /home/ght/deploy/monitoring/.env; set +a

python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py list
python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py fire-pack down
python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py fire S01 C01
python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py resolve-pack all
```

Keep UI: **http://10.168.1.2:3001** → **Alerts**. Lọc label `keep_test` = `true`.

User: `keep`. Password: `KEEP_DEFAULT_PASSWORD` trong `monitoring/.env`.

---

## 3. Ma trận kịch bản

### Pack `down` — ưu tiên cao nhất

| ID | Alert | Đối tượng mock | Ý nghĩa | Keep | Grafana |
|----|--------|----------------|---------|------|---------|
| D01 | PhysicalUnreachable | intel-nuc7 | Máy vật lý mất ping | critical `down` | `/d/physical-host?var-host=intel-nuc7` |
| D02 | VMDown | faceid | Domain libvirt không running | critical `down` | `/d/kvm-guest?var-vm=faceid` |
| D03 | GuestUnreachable | wiseeye | Guest ping fail | critical `down` | `/d/kvm-guest?var-vm=wiseeye` |
| D04 | InfraUnreachable | gateway 10.168.1.1 | Mất gateway LAN | critical `down` | `/d/kvm-fleet` |
| D05 | InfraUnreachable | nas-backup 10.168.1.3 | Mất NAS | critical `down` | `/d/kvm-fleet` |
| D06 | NodeExporterHostDown | hypervisor | Mất metric OS KVM host | critical `down` | `/d/kvm-host` |
| D07 | LibvirtExporterDown | hypervisor | Mất visibility toàn bộ VM | critical `down` | `/d/kvm-fleet` |
| D08 | AiBoxUnreachable | megbox-105 | AI Box mất ping | critical `down` | `/d/aibox-megvii?var-host=megbox-105` |
| D09 | OrayboxUnreachable | oraybox-2 | Switch mất ping | critical `down` | `/d/oraybox-lan?var-host=oraybox-2` |
| D10 | OrayboxAllLanDown | oraybox-80 | Mọi cổng LAN down | critical `down` | `/d/oraybox-lan?var-host=oraybox-80` |

**Kỳ vọng Keep:** 10 alert critical, filter `class=down`. SSH/node_exporter **không** đi kèm (rule production đã `and ICMP==1`).

### Pack `service` — host sống, app chết

| ID | Alert | Ý nghĩa | Sev |
|----|--------|---------|-----|
| S01 | AppHTTPDown faceid-web | Web FaceID 500/timeout | critical |
| S02 | AppHTTPDown kong-status | Kong status fail | critical |
| S03 | AppHTTPDown nx-vms-web | NX VMS web fail | critical |
| S04 | SSHDown chebichat | :22 đóng, ping OK | warning |
| S05 | AiBoxApiDown megbox-102 | MEGBOX API fail, ping OK | critical |
| S06 | OrayboxApiDown oraybox-10 | CGI 500, ping OK | warning |
| S07 | WebsiteHTTPDown face-id | GET domain fail / Kong no-route | critical |
| S08 | WebsiteHTTPDown zlink CF 502 | Cloudflare Bad gateway | critical |

**Kỳ vọng:** `AppHTTPDown` **không** xuất hiện cho Oraybox (matcher `role=guest|physical`). S06 là warning. S08 critical `class=service` (CF 502, không `class=down`). Cloudflare proxy (A ≠ 27.72.98.70) **không** alert.

### Pack `capacity` — treo / OOM / disk / nhiệt

| ID | Alert | Ý nghĩa | Sev |
|----|--------|---------|-----|
| C01 | HostSwapFull | swap>80% **và** MemAvailable&lt;4GiB | critical |
| C02 | HostMemLow | RAM host &lt; 4 GiB | critical |
| C03 | HostDataDiskSpaceCritical | `/mnt/data` &lt; 10% | critical |
| C04 | GuestDiskFullCritical | root guest &gt; 95% | critical |
| C05 | PhysicalCPUTempCritical | CPU &gt; 90°C | critical |
| C06 | PhysicalNVMeTempCritical | NVMe &gt; 80°C | critical |
| C07 | AiBoxCPUTempCritical | AI Box CPU &gt; 90°C | critical |
| C08 | HostSwapHigh | swap&gt;80%, RAM còn dư | warning |

**Kỳ vọng:** C08 không cùng “mức page” với C01. Disk 64% thật **không** sinh C03.

### Pack `optional`

| ID | Alert | Ghi chú |
|----|--------|---------|
| W01 | VMDownOptional unilever | VM optional; production thường đã fire |

---

## 4. Checklist theo dõi trên Keep

Sau `fire-pack down`:

1. [ ] Alerts hiện D01–D10, `keep_test=true`
2. [ ] D01 nổi (PhysicalUnreachable) — máy down hoàn toàn
3. [ ] Incidents: Keep có thể gom theo alertname (tùy rule mặc định)
4. [ ] Ack một alert mock — Prometheus/Grafana **không** đổi
5. [ ] `resolve-pack down` — status resolved trên Keep
6. [ ] Grafana `/d/kvm-fleet` bảng **Servers / VMs down** **không** chứa mock (mock không vào Prometheus `ALERTS{}`)

Sau `fire-pack service` + `capacity`:

7. [ ] Filter `class=service` / `class=capacity`
8. [ ] C01 và C08 phân biệt critical vs warning
9. [ ] S06 warning, S01 critical

Dedup:

10. [ ] `fire D01` hai lần → Keep **một** fingerprint `mock-D01`
11. [ ] `resolve D01` rồi `fire D01` → alert mới / re-open

Keep down (drill stack):

12. [ ] `docker stop keep-backend` → Grafana+Prometheus vẫn xem được; AM log webhook fail
13. [ ] `docker start keep-backend` → AM retry; **không** storm Telegram (chưa bật)

---

## 5. Live drill (cần duyệt — mặc định không chạy)

Chỉ khi đã xong mock và có cửa sổ bảo trì. Rollback ngay.

| ID | Việc | Rủi ro | Rollback |
|----|------|--------|----------|
| D03 live | **Không** shutdown faceid. Có thể tắt NIC trên VM lab | Mất dịch vụ | bật NIC / domain start |
| D04 live | `iptables -I OUTPUT -d 10.168.1.1 -p icmp -j DROP` **rất ngắn** | Mất quan sát gateway | `iptables -D …` |
| D06 live | `systemctl stop node-exporter` trên host **hoặc** `docker stop node-exporter` | Mất metric host | `docker start node-exporter` |
| D07 live | `docker stop libvirt-exporter` | Mất bảng VM | `docker start libvirt-exporter` |
| S01 live | dừng nginx/app trên VM **lab**, không prod | HTTP down | start lại app |
| C01 live | **Không** fill swap giả. Chỉ quan sát metric hiện tại (swap ~6%, RAM ~14GiB → rule inactive) | — | — |

unilever / oraybox-10 / intel-nuc7: dùng **alert đang có** nếu chúng fire — không cần mock trùng.

---

## 6. Mapping rule thật (`prometheus/alerts.yml`)

Mock ID trùng `alertname` với rule production. Khi live drill, Keep nhận từ Alertmanager (không có `keep_test` trừ khi gắn label test).

Secondary rule (SSH, node_exporter, scrape) **chỉ fire khi ICMP=1**. Live down một host → Keep chỉ còn `*Unreachable` / `VMDown`.

---

## 7. Dọn dẹp

```bash
python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py resolve-pack all
```

Trên Keep: filter `keep_test=true` → Resolved. Có thể xóa/dismiss trên UI.

Không đụng volume Prometheus (15 ngày) hay Grafana dashboards.
