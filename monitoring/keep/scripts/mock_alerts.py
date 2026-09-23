#!/usr/bin/env python3
"""Gửi alert giả (Alertmanager webhook) vào Keep. Không đụng hạ tầng thật.

Nguồn secret: /home/ght/deploy/monitoring/.env (KEEP_WEBHOOK_API_KEY).

  python3 mock_alerts.py list
  python3 mock_alerts.py fire D01 D07 S01
  python3 mock_alerts.py fire-pack down
  python3 mock_alerts.py resolve D01
  python3 mock_alerts.py resolve-pack all
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENV_FILE = ROOT / ".env"
KEEP_URL_DEFAULT = "http://127.0.0.1:8080/alerts/event/prometheus"
GRAFANA = "http://10.168.1.2:3000"


def load_env() -> dict[str, str]:
    out: dict[str, str] = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            out[k.strip()] = v.strip().strip("'").strip('"')
    out.update({k: v for k, v in os.environ.items() if v})
    return out


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def scenario(
    sid: str,
    pack: str,
    alertname: str,
    severity: str,
    summary: str,
    description: str,
    labels: dict[str, str],
    dashboard: str,
) -> dict:
    labels = {
        "alertname": alertname,
        "severity": severity,
        "keep_test": "true",
        "monitor": "ght-faceid-server",
        **labels,
    }
    return {
        "id": sid,
        "pack": pack,
        "alertname": alertname,
        "severity": severity,
        "dashboard": dashboard,
        "labels": labels,
        "summary": summary,
        "description": description,
    }


SCENARIOS: list[dict] = [
    # --- down: máy / VM / gateway mất hoàn toàn ---
    scenario(
        "D01", "down", "PhysicalUnreachable", "critical",
        "ICMP fail: intel-nuc7 (mock)",
        "Mock: máy vật lý không trả ping. Ưu tiên cao nhất trên Keep (class=down).",
        {"class": "down", "host": "mock-intel-nuc7", "role": "physical", "job": "blackbox-icmp", "instance": "10.168.1.51"},
        f"{GRAFANA}/d/physical-host?var-host=intel-nuc7",
    ),
    scenario(
        "D02", "down", "VMDown", "critical",
        "VM faceid is not running (mock)",
        "Mock: libvirt state ≠ running cho VM production.",
        {"class": "down", "vm": "mock-faceid", "job": "libvirt", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-guest?var-vm=faceid",
    ),
    scenario(
        "D03", "down", "GuestUnreachable", "critical",
        "ICMP fail: wiseeye (mock)",
        "Mock: guest production không ping được từ hypervisor.",
        {"class": "down", "vm": "mock-wiseeye", "role": "guest", "job": "blackbox-icmp", "instance": "10.168.1.56"},
        f"{GRAFANA}/d/kvm-guest?var-vm=wiseeye",
    ),
    scenario(
        "D04", "down", "InfraUnreachable", "critical",
        "Infra ping fail: gateway (mock)",
        "Mock: gateway 10.168.1.1 không trả ICMP.",
        {"class": "down", "vm": "gateway", "role": "infra", "job": "blackbox-icmp", "instance": "10.168.1.1"},
        f"{GRAFANA}/d/kvm-fleet",
    ),
    scenario(
        "D05", "down", "InfraUnreachable", "critical",
        "Infra ping fail: nas-backup (mock)",
        "Mock: NAS backup 10.168.1.3 không trả ICMP.",
        {"class": "down", "vm": "nas-backup", "role": "infra", "job": "blackbox-icmp", "instance": "10.168.1.3"},
        f"{GRAFANA}/d/kvm-fleet",
    ),
    scenario(
        "D06", "down", "NodeExporterHostDown", "critical",
        "Host node_exporter is down (mock)",
        "Mock: mất metric OS hypervisor — nghi ngờ host KVM treo.",
        {"class": "down", "vm": "hypervisor", "job": "host", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-host",
    ),
    scenario(
        "D07", "down", "LibvirtExporterDown", "critical",
        "libvirt-exporter is down (mock)",
        "Mock: không còn thấy trạng thái domain; visibility fleet mất.",
        {"class": "down", "vm": "hypervisor", "job": "libvirt", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-fleet",
    ),
    scenario(
        "D08", "down", "AiBoxUnreachable", "critical",
        "ICMP fail: megbox-105 (mock)",
        "Mock: Megvii AI Box mất ping.",
        {"class": "down", "host": "mock-megbox-105", "role": "aibox", "job": "blackbox-icmp", "instance": "10.168.1.105"},
        f"{GRAFANA}/d/aibox-megvii?var-host=megbox-105",
    ),
    scenario(
        "D09", "down", "OrayboxUnreachable", "critical",
        "ICMP fail: oraybox-2 (mock)",
        "Mock: switch Oraybox mất ping (khác CGI 500 khi vẫn ping được).",
        {"class": "down", "host": "mock-oraybox-2", "role": "oraybox", "job": "blackbox-icmp", "instance": "192.168.3.2"},
        f"{GRAFANA}/d/oraybox-lan?var-host=oraybox-2",
    ),
    scenario(
        "D10", "down", "OrayboxAllLanDown", "critical",
        "oraybox-80 all LAN ports down (mock)",
        "Mock: ether_status_get OK nhưng lan1–lan4 link=down.",
        {"class": "down", "host": "mock-oraybox-80", "role": "oraybox", "job": "oraybox", "instance": "192.168.3.80"},
        f"{GRAFANA}/d/oraybox-lan?var-host=oraybox-80",
    ),
    # --- service: host còn ping, dịch vụ chết ---
    scenario(
        "S01", "service", "AppHTTPDown", "critical",
        "HTTP down: faceid-web on faceid (mock)",
        "Mock: web FaceID HTTP fail trong khi VM vẫn ping.",
        {"class": "service", "vm": "mock-faceid", "app": "faceid-web", "role": "guest", "job": "blackbox-http", "instance": "http://10.168.1.55/"},
        f"{GRAFANA}/d/kvm-guest?var-vm=faceid",
    ),
    scenario(
        "S02", "service", "AppHTTPDown", "critical",
        "HTTP down: kong-status on kong-gateway (mock)",
        "Mock: Kong /status fail.",
        {"class": "service", "vm": "mock-kong-gateway", "app": "kong-status", "role": "guest", "job": "blackbox-http", "instance": "http://10.168.1.104:8001/status"},
        f"{GRAFANA}/d/kvm-guest?var-vm=kong-gateway",
    ),
    scenario(
        "S03", "service", "AppHTTPDown", "critical",
        "HTTP down: nx-vms-web on nx-vms (mock)",
        "Mock: NX VMS web fail.",
        {"class": "service", "vm": "mock-nx-vms", "app": "nx-vms-web", "role": "guest", "job": "blackbox-http", "instance": "http://10.168.1.106:8000/"},
        f"{GRAFANA}/d/kvm-guest?var-vm=nx-vms",
    ),
    scenario(
        "S04", "service", "SSHDown", "warning",
        "SSH :22 closed on chebichat (mock)",
        "Mock: SSH đóng, ICMP vẫn lên.",
        {"class": "service", "vm": "mock-chebichat", "role": "guest", "job": "blackbox-ssh", "instance": "10.168.1.59:22"},
        f"{GRAFANA}/d/kvm-guest?var-vm=chebichat",
    ),
    scenario(
        "S05", "service", "AiBoxApiDown", "critical",
        "MEGBOX API down: megbox-102 (mock)",
        "Mock: GET /v1/MEGBOX/devices không 200, box vẫn ping.",
        {"class": "service", "host": "mock-megbox-102", "role": "aibox", "job": "blackbox-http", "instance": "http://10.168.1.102/v1/MEGBOX/devices"},
        f"{GRAFANA}/d/aibox-megvii?var-host=megbox-102",
    ),
    scenario(
        "S06", "service", "OrayboxApiDown", "warning",
        "Oraybox API down: oraybox-10 (mock CGI 500)",
        "Mock: CGI ether_status_get 500, switch vẫn ping — không class=down.",
        {"class": "service", "host": "mock-oraybox-10", "role": "oraybox", "job": "blackbox-http", "instance": "http://192.168.3.10/cgi-bin/oraybox?_api=ether_status_get"},
        f"{GRAFANA}/d/oraybox-lan?var-host=oraybox-10",
    ),
    scenario(
        "S07", "service", "WebsiteHTTPDown", "critical",
        "Website down: face-id (mock)",
        "Mock: GET https://face-id.cloud/ fail (non-200 / Kong no-route).",
        {"class": "service", "host": "mock-face-id", "app": "face-id", "group": "face-id", "role": "website",
         "kind": "web", "job": "blackbox-http-website", "instance": "https://face-id.cloud/", "origin_expected": "true"},
        f"{GRAFANA}/d/websites",
    ),
    scenario(
        "S08", "service", "WebsiteHTTPDown", "critical",
        "Website down: zlink-face-id Cloudflare 502 (mock)",
        "Mock: domain proxied qua Cloudflare, GET trả 502 Bad gateway / cf-error.",
        {"class": "service", "host": "mock-zlink-face-id", "app": "zlink-face-id", "group": "face-id", "role": "website",
         "kind": "web", "job": "blackbox-http-website", "instance": "https://zlink.face-id.cloud/", "origin_expected": "false"},
        f"{GRAFANA}/d/websites",
    ),
    # --- capacity: stall / OOM / disk / nhiệt ---
    scenario(
        "C01", "capacity", "HostSwapFull", "critical",
        "Host swap > 80% and MemAvailable < 4 GiB (mock)",
        "Mock: RAM+swap cạn — đường stall/OOM hypervisor. Swap đầy mà RAM dư không dùng alert này.",
        {"class": "capacity", "vm": "hypervisor", "job": "host", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-host",
    ),
    scenario(
        "C02", "capacity", "HostMemLow", "critical",
        "Host available RAM < 4 GiB (mock)",
        "Mock: MemAvailable dưới ngưỡng stall.",
        {"class": "capacity", "vm": "hypervisor", "job": "host", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-host",
    ),
    scenario(
        "C03", "capacity", "HostDataDiskSpaceCritical", "critical",
        "/mnt/data < 10% free (mock)",
        "Mock: đĩa VM gần đầy — nguy cơ guest không ghi được disk.",
        {"class": "capacity", "vm": "hypervisor", "job": "host", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-host",
    ),
    scenario(
        "C04", "capacity", "GuestDiskFullCritical", "critical",
        "kong-gateway root disk > 95% (mock)",
        "Mock: root guest đầy — dịch vụ có thể treo ghi log/DB.",
        {"class": "capacity", "vm": "mock-kong-gateway", "role": "guest", "job": "nodes"},
        f"{GRAFANA}/d/kvm-guest?var-vm=kong-gateway",
    ),
    scenario(
        "C05", "capacity", "PhysicalCPUTempCritical", "critical",
        "GHT-Koala-01 CPU 92°C (mock)",
        "Mock: nhiệt CPU > 90°C — nguy cơ thermal shutdown.",
        {"class": "capacity", "host": "mock-GHT-Koala-01", "role": "physical", "job": "physical"},
        f"{GRAFANA}/d/physical-temp",
    ),
    scenario(
        "C06", "capacity", "PhysicalNVMeTempCritical", "critical",
        "ght-demo-server NVMe 82°C (mock)",
        "Mock: NVMe > 80°C.",
        {"class": "capacity", "host": "mock-ght-demo-server", "role": "physical", "job": "physical"},
        f"{GRAFANA}/d/physical-temp",
    ),
    scenario(
        "C07", "capacity", "AiBoxCPUTempCritical", "critical",
        "megbox-105 CPU 91°C (mock)",
        "Mock: AI Box quá nhiệt.",
        {"class": "capacity", "host": "mock-megbox-105", "role": "aibox", "job": "aibox"},
        f"{GRAFANA}/d/aibox-megvii?var-host=megbox-105",
    ),
    scenario(
        "C08", "capacity", "HostSwapHigh", "warning",
        "Host swap > 80% (mock hygiene)",
        "Mock: swap cao nhưng RAM còn — warning, không page như HostSwapFull.",
        {"class": "capacity", "vm": "hypervisor", "job": "host", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-host",
    ),
    # --- optional / đã biết ---
    scenario(
        "W01", "optional", "VMDownOptional", "warning",
        "VM unilever is not running (mock)",
        "Mock: VM optional tắt — inbox Keep, không class=down.",
        {"vm": "unilever", "job": "libvirt", "instance": "ght-faceid-server"},
        f"{GRAFANA}/d/kvm-guest?var-vm=unilever",
    ),
]


BY_ID = {s["id"]: s for s in SCENARIOS}
PACKS = sorted({s["pack"] for s in SCENARIOS})


def am_payload(s: dict, status: str) -> dict:
    return {
        "receiver": "keep",
        "status": status,
        "externalURL": "http://10.168.1.2:9093",
        "alerts": [
            {
                "status": status,
                "labels": s["labels"],
                "annotations": {
                    "summary": s["summary"],
                    "description": s["description"],
                    "dashboard": s["dashboard"],
                },
                "startsAt": now_iso(),
                "endsAt": now_iso() if status == "resolved" else "0001-01-01T00:00:00Z",
                "generatorURL": "http://10.168.1.2:9091/alerts",
                "fingerprint": f"mock-{s['id']}",
            }
        ],
    }


def post(url: str, key: str, body: dict) -> None:
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-API-KEY": key,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(resp.status, resp.read()[:200].decode(errors="replace"))
            return
    except urllib.error.HTTPError as e:
        if e.code != 401:
            raise
    # Fallback: Alertmanager-style basic_auth username=api_key
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    creds = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    creds.add_password(None, url, "api_key", key)
    opener = urllib.request.build_opener(urllib.request.HTTPBasicAuthHandler(creds))
    with opener.open(req, timeout=20) as resp:
        print(resp.status, resp.read()[:200].decode(errors="replace"))


def pick(ids: list[str]) -> list[dict]:
    missing = [i for i in ids if i not in BY_ID]
    if missing:
        sys.exit(f"unknown scenario id: {', '.join(missing)}")
    return [BY_ID[i] for i in ids]


def main() -> None:
    p = argparse.ArgumentParser(description="Mock Keep alerts for infra/system failure drills")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    pf = sub.add_parser("fire")
    pf.add_argument("ids", nargs="+")
    pr = sub.add_parser("resolve")
    pr.add_argument("ids", nargs="+")
    pp = sub.add_parser("fire-pack")
    pp.add_argument("pack", choices=PACKS + ["all"])
    rp = sub.add_parser("resolve-pack")
    rp.add_argument("pack", choices=PACKS + ["all"])
    args = p.parse_args()

    if args.cmd == "list":
        print(f"{'ID':<5} {'pack':<10} {'sev':<10} {'class':<10} alertname")
        for s in SCENARIOS:
            print(f"{s['id']:<5} {s['pack']:<10} {s['severity']:<10} {s['labels'].get('class','-'):<10} {s['alertname']}")
        print(f"\npacks: {', '.join(PACKS)}")
        print("Keep UI filter: keep_test=\"true\"  → http://10.168.1.2:3001")
        return

    env = load_env()
    key = env.get("KEEP_WEBHOOK_API_KEY")
    if not key:
        sys.exit(f"KEEP_WEBHOOK_API_KEY missing in {ENV_FILE}")
    url = env.get("KEEP_API_URL", KEEP_URL_DEFAULT)

    if args.cmd in ("fire", "resolve"):
        items = pick(args.ids)
        status = "firing" if args.cmd == "fire" else "resolved"
    else:
        pack = args.pack
        items = SCENARIOS if pack == "all" else [s for s in SCENARIOS if s["pack"] == pack]
        status = "firing" if args.cmd.startswith("fire") else "resolved"

    for s in items:
        print(f"{status:9} {s['id']} {s['alertname']}")
        post(url, key, am_payload(s, status))


if __name__ == "__main__":
    main()
