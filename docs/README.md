# Tài liệu deploy

Mục lục để review và quản lý. Tài liệu vận hành nằm theo từng VM; backup/restore host và SMB là runbook chung. Task, sự cố, báo cáo và prompt tách riêng để không lẫn với hướng dẫn hiện hành.

## Cách dùng khi review

1. Backup/restore hàng ngày → [backup-restore.md](backup-restore.md).
2. Bắt đầu từ `vms/<tên-vm>/README.md` — tài liệu vận hành từng VM.
3. Chỉ đọc `changelog-*`, `tasks/`, `issues/`, `reports/` khi cần ngữ cảnh lịch sử.
4. File trong `tasks/` là yêu cầu gốc, không phải hướng dẫn chạy production.

## Cấu trúc

```
docs/
├── README.md                 ← file này
├── backup-restore.md         Runbook backup/restore (local + SMB)
├── vms/
│   ├── faceid/               FaceID (Ubuntu 16.04, preseed)
│   ├── fshare/               FShare (Ubuntu 22.04, cloud-init)
│   └── wiseeye/              WiseEye (Ubuntu 22.04 + docker-compose)
├── issues/                   Ghi chú sự cố đã xử lý
├── tasks/                    Yêu cầu gốc / checklist (lưu trữ)
├── reports/                  Báo cáo phân tích có ngày
└── prompts/                  Prompt đã dùng để sinh script
```

## Vận hành host

| Tài liệu | Đối tượng | Nội dung |
|----------|-----------|----------|
| [backup-restore.md](backup-restore.md) | Nhân sự vận hành | Lịch backup 3 VM, kiểm tra hàng ngày, restore local/SMB, sự cố |

## VMs

| VM | Đọc trước | Chi tiết | Lịch sử |
|----|-----------|----------|---------|
| **faceid** | [vms/faceid/README.md](vms/faceid/README.md) | [Cài đặt](vms/faceid/install.md) · [Truy cập](vms/faceid/access.md) · [Sự cố](vms/faceid/troubleshooting.md) | [SUMMARY.txt](vms/faceid/SUMMARY.txt) (cũ, credential có thể lệch) · [Báo cáo compact 2026-01-06](reports/2026-01-06-faceid-compaction.md) |
| **fshare** | [vms/fshare/README.md](vms/fshare/README.md) | CLI: `./fshare-vm` | [CLI complete](vms/fshare/changelog-cli.md) · [Cloud-init](vms/fshare/changelog-cloud-init.md) |
| **wiseeye** | [vms/wiseeye/README.md](vms/wiseeye/README.md) | [Deploy app](vms/wiseeye/deployment.md) | [Boot OS fail](issues/wiseeye-boot-os-fail.md) |

VM khác trong repo (`chebichat`, `nx-vms`, `unilever`) chưa có tài liệu trong `docs/`.

## Ứng dụng trên VM (ngoài docs/)

Giữ cạnh code để deploy không phải nhảy thư mục:

- [koala/hrm-sync/DEPLOYMENT.md](../koala/hrm-sync/DEPLOYMENT.md) — sync HRM trên FaceID
- [koala/wiseeye-sync/](../koala/wiseeye-sync/) — compose WiseEye (xem [deployment](vms/wiseeye/deployment.md))

## Tasks (lưu trữ)

| File | Nội dung |
|------|----------|
| [tasks/kvm-host-setup.md](tasks/kvm-host-setup.md) | Cài KVM/Cockpit trên host + spec FaceID ban đầu |
| [tasks/install-vm-22.04.md](tasks/install-vm-22.04.md) | Yêu cầu tạo VM wiseeye 22.04 |
| [tasks/wiseeye-vm.md](tasks/wiseeye-vm.md) | Checklist deploy WiseEye |

## Issues

| File | VM | Tóm tắt |
|------|----|---------|
| [issues/wiseeye-boot-os-fail.md](issues/wiseeye-boot-os-fail.md) | wiseeye | Restore XML trỏ sai disk; `wiseeye.qcow2` lỗi netplan/cloud-init |

## Reports

| File | Ngày | Nội dung |
|------|------|----------|
| [reports/2026-01-06-faceid-compaction.md](reports/2026-01-06-faceid-compaction.md) | 2026-01-06 | FaceID: preseed vs cloud-init, compact disk 209→177 GB |

## Prompts

| File | Mục đích |
|------|----------|
| [prompts/fstrim.md](prompts/fstrim.md) | Spec script TRIM + compact qcow2 |

## Quy ước khi thêm tài liệu

- **Backup/restore host** → `backup-restore.md`.
- **Vận hành hiện tại từng VM** → `vms/<vm>/README.md` (hoặc `install.md` / `deployment.md` cùng thư mục).
- **Thay đổi đã xong, chỉ để đối chiếu** → `vms/<vm>/changelog-<chu-de>.md`.
- **Sự cố** → `issues/<vm>-<ten-ngan>.md`.
- **Yêu cầu gốc** → `tasks/<ten>.md`, không sửa thành runbook.
- **Phân tích có ngày** → `reports/YYYY-MM-DD-<chu-de>.md`.
- **Prompt** → `prompts/<chu-de>.md`.
- Đặt tên file chữ thường, kebab-case; cập nhật bảng trong file này khi thêm file mới.
