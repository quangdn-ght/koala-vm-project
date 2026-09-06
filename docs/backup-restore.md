# Hướng dẫn backup và restore VM (vận hành)

Tài liệu dành cho nhân sự trực máy chủ KVM (`ght-faceid-server`). Đọc xong có thể kiểm tra backup hàng ngày và khôi phục VM khi sự cố.

Mọi lệnh chạy trên **host** (không vào trong VM), thư mục:

```bash
cd /home/ght/deploy
```

---

## 1. Hệ thống đang làm gì?

Ba VM được backup tự động mỗi đêm:

| Tên vận hành | Tên libvirt | Disk đang chạy | Kích thước backup (tham khảo) |
|--------------|-------------|----------------|-------------------------------|
| FaceID | `faceid` | `/mnt/data/faceid.qcow2` | ~198 GiB |
| WiseEye | `wiseeye` | `/mnt/data/vm-images/wiseeye-vm.qcow2` | ~69 GiB |
| Kong (FShare) | `kong-gateway` | `/mnt/data/kong-gateway.qcow2` | ~28 GiB |

Mỗi lần backup tạo **cặp file** (thiếu một trong hai thì không restore được):

- `*-backup-YYYYMMDD-HHMMSS.qcow2` — ảnh đĩa VM
- `*-backup-YYYYMMDD-HHMMSS.xml` — cấu hình libvirt

**Hai nơi lưu:**

| Nơi | Path | Giữ bao lâu | Vai trò |
|-----|------|-------------|---------|
| Local (nóng) | `/mnt/data/snapshot/` | **1 ngày** (bản mới nhất) | Restore nhanh trên host |
| SMB (lạnh) | `/mnt/Backup/snapshot/` | **7 ngày** | Khi local đã xóa hoặc host hỏng disk |

SMB: `10.168.1.3:/Backup` tự mount vào `/mnt/Backup` khi boot (và khi truy cập path). Không cần gõ mật khẩu khi vận hành.

---

## 2. Lịch tự động (không cần làm gì nếu bình thường)

Các job chạy tuần tự, có khóa chung — không chồng ghi đĩa.

| Giờ | Việc | Thời gian ước lượng |
|-----|------|---------------------|
| **00:00** | Backup Kong | ~1–2 phút |
| **00:05** | Backup WiseEye | ~3 phút |
| **00:15** | Backup FaceID | ~8–15 phút |
| **01:00** | Copy bản local (7 ngày gần nhất) sang SMB | ~55 phút (~90 MB/s) |
| **22:00** | Xóa bản local cũ hơn 1 ngày | Nhanh |

Quy tắc an toàn: **file local chỉ bị xóa khi đã có đủ cặp qcow2 + xml trên SMB, đúng dung lượng.** Nếu copy SMB lỗi, bản local được giữ lại.

Trong ngày (sau backup đêm, trước 22:00) local có thể có **2 bản** (hôm qua + hôm nay). Sau 22:00 còn 1 bản.

---

## 3. Kiểm tra hàng ngày (5 phút)

Làm buổi sáng. Nếu một bước đỏ → xem mục 7.

### Bước 1 — VM đang chạy?

```bash
virsh list --all
```

`faceid`, `wiseeye`, `kong-gateway` phải là `running`.

### Bước 2 — SMB còn gắn?

```bash
df -h /mnt/Backup
ls /mnt/Backup/snapshot
```

Phải thấy `//10.168.1.3/Backup` và các file `*-backup-*.qcow2`.

### Bước 3 — Có bản đêm qua trên local và SMB?

Thay `YYYYMMDD` bằng ngày hôm nay (ví dụ `20260907`):

```bash
ls -lh /mnt/data/snapshot/*-backup-YYYYMMDD-*.qcow2
ls -lh /mnt/Backup/snapshot/*-backup-YYYYMMDD-*.qcow2
```

Mỗi VM một file qcow2. Thiếu SMB → xem log sync.

### Bước 4 — Log có chữ completed / không failed?

```bash
tail -20 /mnt/data/snapshot/backup-kong-gateway.log
tail -20 /mnt/data/snapshot/backup-wiseeye.log
tail -20 /mnt/data/snapshot/backup.log
tail -30 /mnt/data/snapshot/sync-smb.log
tail -20 /mnt/data/snapshot/cleanup-backups.log
```

Chữ cần thấy: `Backup completed successfully`, `SMB cold-storage sync completed`.

### Bước 5 — Còn chỗ trống?

```bash
df -h /mnt/data /mnt/Backup
```

Cảnh báo khi `/mnt/data` > 85% hoặc `/mnt/Backup` > 80%.

---

## 4. Xem danh sách backup

**Local:**

```bash
./faceid-vm list-backups
./wiseeye-vm list-backups
./fshare-vm list-backups
```

**SMB (7 ngày):**

```bash
sudo ./scripts/helpers/restore-vm-from-smb.sh list
```

Cột `XML` phải `yes`, cột `QEMU` phải `ok`. Timestamp dạng `20260906-000001`.

---

## 5. Backup thủ công (bảo trì, trước khi sửa lớn)

Chạy **lần lượt**, đợi xong mới chạy VM tiếp theo. Không chạy song song với job đêm.

```bash
# Kong (~28G)
sudo ./scripts/helpers/backup-fshare-vm.sh

# WiseEye (~69G)
sudo ./scripts/helpers/backup-wiseeye-vm.sh

# FaceID (~198G)
sudo ./scripts/helpers/backup-faceid-vm.sh
```

Hoặc CLI:

```bash
./fshare-vm backup
./wiseeye-vm backup
./faceid-vm backup
```

Đẩy ngay lên SMB (không đợi 01:00):

```bash
sudo ./scripts/helpers/sync-snapshot-to-smb.sh
```

Xem trước (không copy):

```bash
sudo DRY_RUN=1 ./scripts/helpers/sync-snapshot-to-smb.sh
```

---

## 6. Restore — chọn đúng tình huống

**Cảnh báo:** restore đè disk đang chạy. VM sẽ tắt trong lúc copy. FaceID ~198G qua SMB mất khoảng 35–40 phút.

Ghi lại timestamp trước khi làm. Ví dụ: `20260906-000001`.

### Tình huống A — Local còn file (sự cố trong ngày)

1. Xác nhận file:

```bash
ls -lh /mnt/data/snapshot/faceid-backup-TIMESTAMP.qcow2
ls -lh /mnt/data/snapshot/faceid-backup-TIMESTAMP.xml
```

2. Xem hướng dẫn (chưa thực thi):

```bash
./faceid-vm restore TIMESTAMP
./wiseeye-vm restore TIMESTAMP
./fshare-vm restore TIMESTAMP
```

3. Restore nhanh (thay đúng tên VM và path disk):

**FaceID**

```bash
sudo virsh destroy faceid
sudo mv /mnt/data/faceid.qcow2 /mnt/data/faceid.qcow2.old
sudo cp /mnt/data/snapshot/faceid-backup-TIMESTAMP.qcow2 /mnt/data/faceid.qcow2
sudo virsh start faceid
sudo virsh list --all
```

**WiseEye**

```bash
sudo virsh destroy wiseeye
sudo mv /mnt/data/vm-images/wiseeye-vm.qcow2 /mnt/data/vm-images/wiseeye-vm.qcow2.old
sudo cp /mnt/data/snapshot/wiseeye-backup-TIMESTAMP.qcow2 /mnt/data/vm-images/wiseeye-vm.qcow2
sudo virsh start wiseeye
```

**Kong**

```bash
sudo virsh destroy kong-gateway
sudo mv /mnt/data/kong-gateway.qcow2 /mnt/data/kong-gateway.qcow2.old
sudo cp /mnt/data/snapshot/kong-gateway-backup-TIMESTAMP.qcow2 /mnt/data/kong-gateway.qcow2
sudo virsh start kong-gateway
```

Kiểm tra VM `running`, rồi SSH thử. Disk cũ nằm file `*.qcow2.old` — xóa sau khi xác nhận ổn (tiết kiệm chỗ).

### Tình huống B — Local hết, còn trên SMB (sau 22:00 hoặc local bị xóa)

**Cách 1 — kéo về local rồi restore như A (an toàn hơn, dễ kiểm tra):**

```bash
sudo ./scripts/helpers/restore-vm-from-smb.sh list
sudo ./scripts/helpers/restore-vm-from-smb.sh fetch faceid TIMESTAMP
./faceid-vm restore TIMESTAMP
# rồi làm các lệnh virsh/cp ở tình huống A
```

Đổi `faceid` thành `wiseeye` hoặc `kong-gateway` khi restore VM khác.

**Cách 2 — một lệnh (tắt VM, đổi disk, bật lại).** Disk đang chạy được đổi tên thành `*.pre-restore-<giờ>`.

```bash
sudo ./scripts/helpers/restore-vm-from-smb.sh restore faceid TIMESTAMP --yes
sudo ./scripts/helpers/restore-vm-from-smb.sh restore wiseeye TIMESTAMP --yes
sudo ./scripts/helpers/restore-vm-from-smb.sh restore kong-gateway TIMESTAMP --yes
```

Thiếu `--yes` thì script từ chối chạy.

### Tình huống C — Chỉ cần bản test, không đụng VM đang chạy

Copy disk backup ra file mới và clone VM (xem output của `./faceid-vm restore TIMESTAMP`, mục Method 3). Không dùng `restore --yes`.

---

## 7. Sự cố thường gặp

### SMB không mount / `ls /mnt/Backup` trống

```bash
findmnt /mnt/Backup
ls /mnt/Backup
sudo mount -a
df -h /mnt/Backup
```

Nếu vẫn lỗi: kiểm tra ping `10.168.1.3`, file `/etc/cifs-credentials-backup` (chỉ root đọc), dòng CIFS trong `/etc/fstab`.

### Backup đêm không chạy

```bash
sudo crontab -l
grep CRON /var/log/syslog | grep -E 'backup-|sync-snapshot|cleanup-old'
```

Phải có 5 dòng cron (Kong, WiseEye, FaceID, sync SMB, cleanup).

### Sync SMB failed — local không bị xóa

Đúng thiết kế. Đọc `/mnt/data/snapshot/sync-smb.log`. Chạy lại:

```bash
sudo ./scripts/helpers/sync-snapshot-to-smb.sh
```

File `*.partial` trên SMB là bản copy dở — lần sync sau sẽ ghi tiếp hoặc thay.

### Hết chỗ `/mnt/data`

Local chỉ nên còn 1 ngày sau 22:00. Kiểm tra:

```bash
ls -lh /mnt/data/snapshot/*-backup-*.qcow2
df -h /mnt/data
```

Không xóa tay file chưa có trên SMB. Nếu SMB đã có đủ cặp, có thể chạy cleanup:

```bash
sudo DRY_RUN=1 RETENTION_DAYS=1 ./scripts/helpers/cleanup-old-backups.sh
sudo RETENTION_DAYS=1 ./scripts/helpers/cleanup-old-backups.sh
```

### Restore xong VM không boot

1. `virsh list --all` — state?
2. `virsh start <tên>` và `virsh console <tên>`
3. Còn disk `*.pre-restore-*` hoặc `*.qcow2.old` → đổi lại tên rồi `virsh start`

---

## 8. File log và script

| Việc | File / lệnh |
|------|-------------|
| Log Kong | `/mnt/data/snapshot/backup-kong-gateway.log` |
| Log WiseEye | `/mnt/data/snapshot/backup-wiseeye.log` |
| Log FaceID | `/mnt/data/snapshot/backup.log` |
| Log copy SMB | `/mnt/data/snapshot/sync-smb.log` |
| Log xóa local | `/mnt/data/snapshot/cleanup-backups.log` |
| Backup Kong | `scripts/helpers/backup-fshare-vm.sh` |
| Backup WiseEye | `scripts/helpers/backup-wiseeye-vm.sh` |
| Backup FaceID | `scripts/helpers/backup-faceid-vm.sh` |
| Copy SMB | `scripts/helpers/sync-snapshot-to-smb.sh` |
| Xóa local | `scripts/helpers/cleanup-old-backups.sh` |
| Restore SMB | `scripts/helpers/restore-vm-from-smb.sh` |

Crontab: `sudo crontab -l` (user **root**, không phải `crontab -l` của user thường).

---

## 9. Việc không làm

- Không xóa tay file trong `/mnt/data/snapshot` khi chưa thấy cùng tên trên `/mnt/Backup/snapshot`.
- Không chạy backup song song hai VM.
- Không chạy `restore ... --yes` khi chưa có timestamp đúng từ `list`.
- Không copy backup vào disk đang VM `running` (phải `virsh destroy` trước).
- Không điền mật khẩu SMB vào ticket/chat — đã lưu trên host.

---

## 10. Dung lượng SMB (tham khảo)

Một ngày ~294 GiB (FaceID + WiseEye + Kong). Ổ `/mnt/Backup` ~9.7 T.

| Giữ trên SMB | Ước lượng | Ghi chú |
|--------------|-----------|---------|
| 7 ngày (hiện tại) | ~2.0 T | An toàn |
| 14 ngày | ~4.0 T | An toàn |
| 21 ngày | ~6.0 T | Mức nên dùng nếu muốn giữ lâu hơn |
| 30 ngày | ~8.6 T | Sát trần, không khuyến nghị |

Chỉ tăng số ngày khi đã thống nhất với quản trị host (đổi `SMB_RETENTION_DAYS` trong sync, không tự sửa crontab cho việc này nếu chưa được giao).
