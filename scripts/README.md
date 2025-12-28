# Hướng Dẫn Sử Dụng Script Backup và Restore

## Mục Lục
- [Giới Thiệu](#giới-thiệu)
- [Yêu Cầu Hệ Thống](#yêu-cầu-hệ-thống)
- [Các Tính Năng Chính](#các-tính-năng-chính)
- [Hướng Dẫn Chi Tiết](#hướng-dẫn-chi-tiết)
  - [1. Backup Thư Mục /data](#1-backup-thư-mục-data)
  - [2. Sao Chép Backup Đến Server Từ Xa](#2-sao-chép-backup-đến-server-từ-xa)
  - [3. Restore Dữ Liệu Từ Backup](#3-restore-dữ-liệu-từ-backup)
  - [4. Quản Lý Database MySQL](#4-quản-lý-database-mysql)
  - [5. Dọn Dẹp Backup Cũ](#5-dọn-dẹp-backup-cũ)
- [Lưu Ý Quan Trọng](#lưu-ý-quan-trọng)
- [Xử Lý Sự Cố](#xử-lý-sự-cố)

---

## Giới Thiệu

Script `backup.sh` cung cấp các công cụ toàn diện để:
- Tạo bản sao lưu nén cho thư mục `/data`
- Đồng bộ backup đến server từ xa
- Khôi phục dữ liệu từ file backup
- Quản lý database MySQL (tạo và restore)
- Tự động dọn dẹp các backup cũ

## Yêu Cầu Hệ Thống

Trước khi sử dụng script, đảm bảo hệ thống của bạn đã cài đặt các công cụ sau:

```bash
# Kiểm tra và cài đặt các công cụ cần thiết
sudo apt update
sudo apt install -y tar gzip pv rsync mysql-client
```

**Các công cụ cần thiết:**
- `tar`: Để nén và giải nén file
- `gzip`: Để nén dữ liệu
- `pv` (Pipe Viewer): Hiển thị thanh tiến trình
- `rsync`: Đồng bộ file đến server từ xa
- `mysql-client`: Quản lý MySQL database

## Các Tính Năng Chính

| Tính Năng | Mô Tả | Ước Tính Thời Gian |
|-----------|-------|---------------------|
| **Backup Dữ Liệu** | Nén và sao lưu thư mục /data với thanh tiến trình | Phụ thuộc vào kích thước |
| **Remote Sync** | Sao chép backup đến server từ xa qua rsync | Phụ thuộc vào băng thông |
| **Restore Dữ Liệu** | Khôi phục dữ liệu từ file backup | Phụ thuộc vào kích thước |
| **MySQL Backup** | Backup và restore MySQL database | Nhanh |
| **Auto Cleanup** | Tự động xóa backup cũ, chỉ giữ 3 bản mới nhất | < 1 phút |

---

## Hướng Dẫn Chi Tiết

### 1. Backup Thư Mục /data

**Mục đích:** Tạo bản sao lưu nén của toàn bộ thư mục `/data` với timestamp tự động.

**Câu lệnh:**
```bash
sudo tar -czf - /data 2>/dev/null | pv -s 22G > /tmp/data-backup-$(date +%Y%m%d-%H%M%S).tar.gz
```

**Giải thích chi tiết:**
- `sudo`: Chạy với quyền root để truy cập tất cả file
- `tar -czf -`: 
  - `-c`: Tạo archive mới
  - `-z`: Nén bằng gzip
  - `-f -`: Ghi output ra stdout (để pipe sang pv)
- `/data`: Thư mục nguồn cần backup
- `2>/dev/null`: Ẩn thông báo lỗi (ví dụ: file không có quyền truy cập)
- `pv -s 22G`: Hiển thị thanh tiến trình với kích thước ước tính 22GB
- `> /tmp/data-backup-$(date +%Y%m%d-%H%M%S).tar.gz`: Lưu file với tên chứa timestamp

**Ví dụ tên file output:**
- `data-backup-20251227-143025.tar.gz` (27/12/2025 lúc 14:30:25)

**Lưu ý:**
- Điều chỉnh tham số `-s 22G` theo kích thước thực tế của thư mục `/data`
- Kiểm tra dung lượng trống trong `/tmp` trước khi chạy:
  ```bash
  df -h /tmp
  ```

**Kiểm tra kích thước thư mục /data:**
```bash
sudo du -sh /data
```

### 2. Sao Chép Backup Đến Server Từ Xa

**Mục đích:** Đồng bộ file backup từ server từ xa về máy local hoặc ngược lại.

**Câu lệnh (Pull từ Remote):**
```bash
rsync -avh --progress 10.168.1.52:/tmp/data-backup-20251226-005314.tar.gz ./
```

**Câu lệnh (Push đến Remote):**
```bash
rsync -avh --progress /tmp/data-backup-20251227-143025.tar.gz 10.168.1.52:/backup/
```

**Giải thích tham số:**
- `-a`: Archive mode (giữ nguyên permissions, timestamps, symlinks)
- `-v`: Verbose (hiển thị chi tiết quá trình)
- `-h`: Human-readable (hiển thị kích thước dễ đọc)
- `--progress`: Hiển thị thanh tiến trình
- `10.168.1.52`: Địa chỉ IP server từ xa
- `./`: Thư mục đích (thư mục hiện tại)

**Yêu cầu:**
- Đã cấu hình SSH key hoặc biết mật khẩu SSH
- Port 22 (SSH) phải mở trên server đích

**Thiết lập SSH key (không cần mật khẩu):**
```bash
# Tạo SSH key (nếu chưa có)
ssh-keygen -t rsa -b 4096

# Copy key đến server từ xa
ssh-copy-id user@10.168.1.52
```

### 3. Restore Dữ Liệu Từ Backup

**Mục đích:** Khôi phục dữ liệu từ file backup `.tar.gz`.

#### 3.1. Restore từ Remote Backup

**Câu lệnh:**
```bash
pv /data/data-backup-20251226-005314.tar.gz | tar -xzf - --strip-components=1 data/
```

**Giải thích:**
- `pv /data/data-backup-...tar.gz`: Đọc file backup và hiển thị tiến trình
- `tar -xzf -`: Giải nén từ stdin
- `--strip-components=1`: Bỏ 1 level thư mục đầu tiên (bỏ `data/` trong archive)
- `data/`: Chỉ extract thư mục data

#### 3.2. Restore từ Local Backup

**Câu lệnh:**
```bash
pv ./data-backup-20251226-005314.tar.gz | tar -xzf - --strip-components=1 data/
```

**Lưu ý quan trọng:**
- ⚠️ **Cẩn thận:** Restore sẽ ghi đè lên dữ liệu hiện tại
- Luôn backup trước khi restore
- Đảm bảo đủ dung lượng đĩa

**Kiểm tra nội dung backup trước khi restore:**
```bash
tar -tzf data-backup-20251226-005314.tar.gz | head -20
```

#### 3.3. Restore Archive Chung

**Câu lệnh:**
```bash
pv ./archive_2025-12-25.tar.gz | tar -xzf - --strip-components=1 ./
```

**Áp dụng cho:** Restore archive tổng quát không phải từ thư mục cụ thể.

### 4. Quản Lý Database MySQL

#### 4.1. Tạo Database Mới

**Mục đích:** Tạo database MySQL trước khi restore.

**Câu lệnh:**
```bash
mysql -u root -proot -e "CREATE DATABASE koala_online_tdc;"
```

**Giải thích:**
- `-u root`: User MySQL
- `-proot`: Password (⚠️ không có khoảng trắng giữa `-p` và password)
- `-e`: Execute command
- `CREATE DATABASE koala_online_tdc;`: Tạo database

**Lưu ý bảo mật:**
```bash
# Tốt hơn: Nhập password tương tác
mysql -u root -p -e "CREATE DATABASE koala_online_tdc;"

# Hoặc sử dụng file config
mysql --defaults-extra-file=/path/to/mysql.cnf -e "CREATE DATABASE koala_online_tdc;"
```

**Kiểm tra database đã tồn tại:**
```bash
mysql -u root -p -e "SHOW DATABASES;"
```

#### 4.2. Restore MySQL Database

**Mục đích:** Khôi phục database từ file SQL dump.

**Câu lệnh:**
```bash
pv koala_online_2025-12-11.sql | mysql -u root -proot koala_online_tdc
```

**Giải thích:**
- `pv koala_online_2025-12-11.sql`: Đọc file SQL với thanh tiến trình
- `mysql ... koala_online_tdc`: Import vào database chỉ định

**Backup MySQL Database:**
```bash
# Backup single database
mysqldump -u root -p koala_online_tdc | pv > koala_online_$(date +%Y-%m-%d).sql

# Backup all databases
mysqldump -u root -p --all-databases | pv > all-databases_$(date +%Y-%m-%d).sql
```

**Verify sau khi restore:**
```bash
mysql -u root -p koala_online_tdc -e "SHOW TABLES;"
```

### 5. Dọn Dẹp Backup Cũ

**Mục đích:** Tự động xóa các backup cũ, chỉ giữ lại 3 bản mới nhất để tiết kiệm dung lượng.

**Câu lệnh:**
```bash
cd /mnt/data/snapshot && \
ls -t faceid-backup-*.qcow2 | tail -n +4 | xargs -r rm -f && \
ls -t faceid-backup-*.xml | tail -n +4 | xargs -r rm -f
```

**Giải thích từng bước:**
1. `cd /mnt/data/snapshot`: Chuyển đến thư mục chứa backup
2. `ls -t faceid-backup-*.qcow2`: List file QCOW2, sắp xếp theo thời gian (mới nhất trước)
3. `tail -n +4`: Lấy từ dòng thứ 4 trở đi (bỏ qua 3 file mới nhất)
4. `xargs -r rm -f`: Xóa các file còn lại
   - `-r`: Không chạy nếu input rỗng
   - `-f`: Force delete, không hỏi xác nhận

**Điều chỉnh số lượng backup giữ lại:**
```bash
# Giữ lại 5 bản mới nhất
ls -t faceid-backup-*.qcow2 | tail -n +6 | xargs -r rm -f

# Giữ lại 10 bản mới nhất
ls -t faceid-backup-*.qcow2 | tail -n +11 | xargs -r rm -f
```

**Kiểm tra trước khi xóa:**
```bash
# Xem file sẽ bị xóa (dry-run)
cd /mnt/data/snapshot
ls -t faceid-backup-*.qcow2 | tail -n +4
```

**Tự động hóa với Cron:**
```bash
# Chạy cleanup hàng ngày lúc 2:00 AM
crontab -e

# Thêm dòng sau:
0 2 * * * cd /mnt/data/snapshot && ls -t faceid-backup-*.qcow2 | tail -n +4 | xargs -r rm -f 2>&1 | logger -t backup-cleanup
```

---

## Lưu Ý Quan Trọng

### 🔒 Bảo Mật
- ⚠️ **Không lưu password trong script**: Sử dụng file config hoặc nhập tương tác
- 🔑 Sử dụng SSH key thay vì password cho rsync
- 🛡️ Đặt quyền hạn chế cho file backup:
  ```bash
  chmod 600 data-backup-*.tar.gz
  ```

### 💾 Quản Lý Dung Lượng
- Kiểm tra dung lượng trống trước khi backup:
  ```bash
  df -h /tmp /mnt/data/snapshot
  ```
- Xóa backup cũ thủ công nếu cần:
  ```bash
  find /tmp -name "data-backup-*.tar.gz" -mtime +7 -delete
  ```

### ⏱️ Hiệu Suất
- Backup lớn có thể tốn nhiều thời gian và tài nguyên CPU
- Chạy backup vào giờ thấp điểm nếu có thể
- Sử dụng `nice` để giảm priority:
  ```bash
  nice -n 19 sudo tar -czf - /data 2>/dev/null | pv -s 22G > /tmp/backup.tar.gz
  ```

### 🔄 Tự Động Hóa
Tạo script tự động backup hàng ngày:

```bash
#!/bin/bash
# /usr/local/bin/auto-backup.sh

BACKUP_DIR="/mnt/data/backups"
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/var/log/backup.log"

echo "[$(date)] Starting backup..." >> $LOG_FILE

# Backup /data
sudo tar -czf - /data 2>/dev/null | \
  pv -s 22G > $BACKUP_DIR/data-backup-$DATE.tar.gz

# Sync to remote
rsync -avh --progress $BACKUP_DIR/data-backup-$DATE.tar.gz \
  10.168.1.52:/remote/backups/

# Cleanup old backups (keep last 5)
cd $BACKUP_DIR && ls -t data-backup-*.tar.gz | tail -n +6 | xargs -r rm -f

echo "[$(date)] Backup completed!" >> $LOG_FILE
```

Thêm vào crontab:
```bash
# Backup hàng ngày lúc 3:00 AM
0 3 * * * /usr/local/bin/auto-backup.sh
```

---

## Xử Lý Sự Cố

### Lỗi: "Permission denied"
**Nguyên nhân:** Không có quyền truy cập file/thư mục.

**Giải pháp:**
```bash
# Chạy với sudo
sudo tar -czf - /data ...

# Kiểm tra quyền
ls -ld /data /tmp
```

### Lỗi: "No space left on device"
**Nguyên nhân:** Không đủ dung lượng đĩa.

**Giải pháp:**
```bash
# Kiểm tra dung lượng
df -h

# Dọn dẹp file tạm
sudo rm -rf /tmp/data-backup-*.tar.gz

# Chuyển sang partition khác
sudo tar -czf - /data 2>/dev/null | pv -s 22G > /mnt/other/backup.tar.gz
```

### Lỗi: "pv: command not found"
**Nguyên nhân:** Chưa cài đặt pv.

**Giải pháp:**
```bash
sudo apt install pv
```

### Lỗi: "Access denied for user"
**Nguyên nhân:** Sai username/password MySQL.

**Giải pháp:**
```bash
# Kiểm tra user có tồn tại
mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# Reset MySQL root password nếu cần
sudo mysql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

### Backup bị corrupt
**Kiểm tra tính toàn vẹn:**
```bash
# Test archive
tar -tzf data-backup-20251226-005314.tar.gz > /dev/null

# Nếu OK, không có output
# Nếu corrupt, sẽ báo lỗi
```

### rsync chậm hoặc timeout
**Giải pháp:**
```bash
# Thêm compression
rsync -avhz --progress --timeout=300 source destination

# Tăng timeout
rsync -avh --progress --timeout=600 source destination

# Kiểm tra network
ping 10.168.1.52
traceroute 10.168.1.52
```

---

## Tài Nguyên Tham Khảo

- [GNU tar Manual](https://www.gnu.org/software/tar/manual/)
- [rsync Documentation](https://rsync.samba.org/)
- [MySQL Backup Reference](https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html)

---

**Phiên bản:** 1.0  
**Cập nhật:** 27/12/2025  
**Tác giả:** System Administrator
