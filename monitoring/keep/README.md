# Keep — inbox alarm (đang chạy)

Grafana metrics: http://10.168.1.2:3000  
Keep inbox: **http://10.168.1.2:3001**  
Keep API: http://10.168.1.2:8080/docs  

Telegram **chưa** bật.

## Xem trên web

1. Mở **http://10.168.1.2:3001** (dùng IP này; NextAuth gắn `NEXTAUTH_URL` đó).
2. Đăng nhập:
   - User: `keep`
   - Password: `KEEP_DEFAULT_PASSWORD` trong `/home/ght/deploy/monitoring/.env`
     ```bash
     grep '^KEEP_DEFAULT_PASSWORD=' /home/ght/deploy/monitoring/.env
     ```
3. Menu trái:
   - **Alerts** — inbox (PhysicalUnreachable intel-nuc7, OrayboxApiDown, VMDownOptional, …)
   - **Incidents** — nhóm alert (mặc định sau login)
   - Filter `severity=critical` hoặc label `class=down` cho máy mất hẳn
4. Ack / resolve trên Keep **không** tắt rule Prometheus; silence Alertmanager nếu muốn ngừng webhook.
5. Deep link Grafana từ annotation / mở tay:
   - Fleet: http://10.168.1.2:3000/d/kvm-fleet
   - Host: http://10.168.1.2:3000/d/kvm-host
   - Physical: http://10.168.1.2:3000/d/physical-host
   - Alertmanager: http://10.168.1.2:9093

## Compose (start / stop)

Secret (`KEEP_JWT_SECRET`, password, …) nằm ở **`/home/ght/deploy/monitoring/.env`**. File `keep/.env` **không** được overlay đọc.

**Lệnh đúng** (từ bất kỳ thư mục nào):

```bash
bash /home/ght/deploy/monitoring/keep/up.sh up -d
bash /home/ght/deploy/monitoring/keep/up.sh ps
bash /home/ght/deploy/monitoring/keep/up.sh logs -f --tail=80 keep-backend keep-frontend
```

Tương đương, phải đứng ở `monitoring/` và truyền **cả hai** file compose + `--env-file`:

```bash
cd /home/ght/deploy/monitoring
docker compose --env-file .env -f docker-compose.yml -f keep/docker-compose.yml up -d
```

`cd keep && docker compose up` sẽ lỗi `KEEP_JWT_SECRET is missing` vì Compose chỉ nạp `keep/.env`.

Kế hoạch đầy đủ: [PLAN.md](./PLAN.md)

Test plan mockup (lỗi hạ tầng → Keep, không shutdown prod): [TEST-PLAN.md](./TEST-PLAN.md)

```bash
python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py list
python3 /home/ght/deploy/monitoring/keep/scripts/mock_alerts.py fire-pack down
```
