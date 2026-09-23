# Khảo sát website GET — 2026-09-23

Probe từ hypervisor `ght-faceid-server`. Origin tĩnh: **`27.72.98.70`** (Kong). IP khác = Cloudflare proxy (104.x / 172.64–67.x).

Healthy:

- `kind=web`: GET follow-redirect, status cuối **200**, body không rỗng, không Kong “no Route”, không Cloudflare 502/52x.
- `kind=api` (service API, không phải frontend): JSON trên GET `/` — kể cả `{"detail":"Not Found"}` (200 hoặc 404 FastAPI) — **healthy**.

| name | URL | A record | Origin? | HTTPS | Ghi chú |
|------|-----|----------|---------|-------|---------|
| face-id | https://face-id.cloud/ | 27.72.98.70 | có | cert Kong self-signed `CN=localhost` | Module `http_website_origin` (skip TLS verify). HTTP 302 → `/signin` 200. |
| sync-face-id | https://sync.face-id.cloud/ | 172.67.150.97, 104.21.63.213 | CF | 200 | |
| zlink-face-id | https://zlink.face-id.cloud/ | 172.67.150.97, 104.21.63.213 | CF | 200 | Header `server: cloudflare` + `via: kong/3.9.1` |
| giahungtech | https://giahungtech.com.vn/ | 104.26.x, 172.67.72.19 | CF | 200 | |
| www-giahungtech | https://www.giahungtech.com.vn/ | **NXDOMAIN** | — | fail | Sẽ `WebsiteHTTPDown` cho đến khi có DNS |
| sync-giahungtech | https://sync.giahungtech.com.vn/ | CF | CF | 404 JSON `{"detail":"Not Found"}` | `kind=api` — **healthy** (service API, không phải web-app) |
| xworks | https://xworks.vn/ | 104.21.70.59, 172.67.220.116 | CF | 200 | |
| admin-xworks | https://admin.xworks.vn/ | CF | CF | 200 | |
| xworks-local | https://xworks.local/ | **NXDOMAIN** | — | fail | `enabled: false` |
| media-xworks | https://media.xworks.vn/ | CF | CF | **400/403** AccessDenied (S3 qua Kong+CF) | Sẽ `WebsiteHTTPDown` |
| zalo-xworks | https://zalo.xworks.vn/ | CF | CF | 200 | |
| cloud-megvii | https://cloud.megvii.com.vn/ | 27.72.98.70 | có | Kong self-signed | Giống face-id — `tls: origin` |
| deepsight-megvii | https://deepsight.megvii.com.vn/ | 104.21.58.38, 172.67.155.245 | CF | 200 | |
| chebichat | https://chebichat.com.vn/ | 104.21.35.5, 172.67.210.114 | CF | 200 | |
| www-chebichat | https://www.chebichat.com.vn/ | CF | CF | 200 | |

## Cloudflare vs origin

- **Cloudflare proxy** (A ≠ `27.72.98.70`, query OK): `website:dns_path=2` — **valid**, Grafana xanh. Không alert Keep.
- **Direct origin** (`A` = `27.72.98.70`): `website:dns_path=1` — Grafana **vàng** (natural). Không alert Keep.
- **DNS fail / NXDOMAIN**: `website:dns_path=0` — đỏ.
- HTTP 502/52x Bad gateway / `cf-error-*` khi đang qua CF → `WebsiteHTTPDown` critical.
- Kong origin cert self-signed: không bật TLS verify cho `tls: origin`.
