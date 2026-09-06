#!/usr/bin/env python3
"""Generate provisioned Grafana dashboards for KVM fleet monitoring."""
from __future__ import annotations

import json
from pathlib import Path

DS = {"type": "prometheus", "uid": "prometheus"}
OUT = Path(__file__).resolve().parent.parent / "grafana" / "dashboards"


def panel_base(pid, title, ptype, x, y, w, h, **extra):
    p = {
        "id": pid,
        "title": title,
        "type": ptype,
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "datasource": DS,
    }
    p.update(extra)
    return p


def target(expr, legend="{{vm}}", ref="A", instant=False, fmt=None):
    t = {
        "datasource": DS,
        "expr": expr,
        "legendFormat": legend,
        "refId": ref,
        "editorMode": "code",
        "range": not instant,
        "instant": instant,
    }
    if fmt:
        t["format"] = fmt
    if instant:
        t["range"] = False
    return t


def stat(pid, title, expr, x, y, w=6, h=4, unit="none", legend="{{vm}}", thresholds=None, instant=True):
    steps = thresholds or [
        {"color": "green", "value": None},
        {"color": "red", "value": 0},
    ]
    return panel_base(
        pid,
        title,
        "stat",
        x,
        y,
        w,
        h,
        targets=[target(expr, legend, instant=instant)],
        fieldConfig={
            "defaults": {
                "unit": unit,
                "color": {"mode": "thresholds"},
                "thresholds": {"mode": "absolute", "steps": steps},
                "mappings": [],
            },
            "overrides": [],
        },
        options={
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "orientation": "auto",
            "textMode": "auto",
            "colorMode": "background",
            "graphMode": "none",
            "justifyMode": "center",
        },
    )


def gauge_bar(pid, title, expr, x, y, w, h, unit="percentunit", maxv=1, legend="{{vm}}"):
    return panel_base(
        pid,
        title,
        "bargauge",
        x,
        y,
        w,
        h,
        targets=[target(expr, legend, instant=True)],
        fieldConfig={
            "defaults": {
                "unit": unit,
                "min": 0,
                "max": maxv,
                "color": {"mode": "thresholds"},
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": "green", "value": None},
                        {"color": "yellow", "value": 0.7},
                        {"color": "red", "value": 0.9},
                    ],
                },
            },
            "overrides": [],
        },
        options={
            "orientation": "horizontal",
            "displayMode": "gradient",
            "valueMode": "color",
            "showUnfilled": True,
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
        },
    )


def timeseries(pid, title, expr, x, y, w, h, unit="percent", legend="{{vm}}", extra_targets=None):
    targets = [target(expr, legend)]
    if extra_targets:
        targets.extend(extra_targets)
    return panel_base(
        pid,
        title,
        "timeseries",
        x,
        y,
        w,
        h,
        targets=targets,
        fieldConfig={
            "defaults": {
                "unit": unit,
                "custom": {
                    "drawStyle": "line",
                    "lineInterpolation": "smooth",
                    "fillOpacity": 10,
                    "pointSize": 5,
                    "showPoints": "never",
                    "spanNulls": False,
                    "axisBorderShow": False,
                    "gradientMode": "none",
                },
            },
            "overrides": [],
        },
        options={
            "legend": {
                "displayMode": "table",
                "placement": "right",
                "calcs": ["mean", "lastNotNull"],
                "showLegend": True,
            },
            "tooltip": {"mode": "multi", "sort": "desc"},
        },
    )


def table(pid, title, targets, x, y, w, h, transformations):
    return panel_base(
        pid,
        title,
        "table",
        x,
        y,
        w,
        h,
        targets=targets,
        transformations=transformations,
        fieldConfig={
            "defaults": {
                "custom": {"align": "auto", "filterable": True},
                "mappings": [],
            },
            "overrides": [],
        },
        options={"showHeader": True, "cellHeight": "sm", "footer": {"show": False}},
    )


def state_timeline(pid, title, expr, x, y, w, h, legend="{{vm}}"):
    return panel_base(
        pid,
        title,
        "state-timeline",
        x,
        y,
        w,
        h,
        targets=[target(expr, legend)],
        fieldConfig={
            "defaults": {
                "color": {"mode": "thresholds"},
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": "red", "value": None},
                        {"color": "green", "value": 1},
                    ],
                },
                "custom": {"fillOpacity": 70, "lineWidth": 0},
            },
            "overrides": [],
        },
        options={
            "mergeValues": True,
            "showValue": "never",
            "alignValue": "center",
            "rowHeight": 0.9,
            "legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
        },
    )


def row(pid, title, y):
    return {
        "id": pid,
        "title": title,
        "type": "row",
        "gridPos": {"h": 1, "w": 24, "x": 0, "y": y},
        "collapsed": False,
        "panels": [],
    }


def dashboard(title, uid, panels, templating=None, tags=None, description=""):
    return {
        "annotations": {"list": []},
        "description": description,
        "editable": True,
        "fiscalYearStartMonth": 0,
        "graphTooltip": 1,
        "id": None,
        "links": [
            {"asDropdown": True, "icon": "dashboard", "includeVars": True, "keepTime": True, "tags": ["kvm"], "title": "KVM dashboards", "type": "dashboards"}
        ],
        "liveNow": True,
        "panels": panels,
        "refresh": "10s",
        "schemaVersion": 39,
        "style": "dark",
        "tags": tags or ["kvm"],
        "templating": {"list": templating or []},
        "time": {"from": "now-1h", "to": "now"},
        "timepicker": {"refresh_intervals": ["5s", "10s", "30s", "1m", "5m"]},
        "timezone": "browser",
        "title": title,
        "uid": uid,
        "version": 1,
        "weekStart": "",
    }


def vm_var():
    return {
        "name": "vm",
        "type": "query",
        "label": "VM",
        "datasource": DS,
        "query": 'label_values(libvirt_domain_info_state, vm)',
        "refresh": 2,
        "includeAll": False,
        "multi": False,
        "sort": 1,
        "current": {},
        "hide": 0,
        "regex": "",
        "definition": "label_values(libvirt_domain_info_state, vm)",
    }


def fleet():
    # table: libvirt state + vcpu + mem + cpu + ping + ssh + http + guest disk + guest mem
    tbl_targets = [
        target('libvirt_domain_info_state', "{{vm}}", "A", instant=True, fmt="table"),
        target("libvirt_domain_info_virtual_cpus", "{{vm}}", "B", instant=True, fmt="table"),
        target("libvirt_domain_info_maximum_memory_bytes", "{{vm}}", "C", instant=True, fmt="table"),
        target("vm:cpu_usage_ratio", "{{vm}}", "D", instant=True, fmt="table"),
        target("libvirt_domain_memory_stats_rss_bytes", "{{vm}}", "E", instant=True, fmt="table"),
        target('probe_success{job="blackbox-icmp",role="guest"}', "{{vm}}", "F", instant=True, fmt="table"),
        target('probe_success{job="blackbox-ssh"}', "{{vm}}", "G", instant=True, fmt="table"),
        target('min by (vm) (probe_success{job="blackbox-http"})', "{{vm}}", "H", instant=True, fmt="table"),
        target("guest:root_disk_used_ratio", "{{vm}}", "I", instant=True, fmt="table"),
        target("guest:mem_used_ratio", "{{vm}}", "J", instant=True, fmt="table"),
        target('up{job="nodes"}', "{{vm}}", "K", instant=True, fmt="table"),
    ]
    transforms = [
        {"id": "labelsToFields", "options": {"mode": "columns"}},
        {"id": "joinByField", "options": {"byField": "vm", "mode": "outer"}},
        {
            "id": "organize",
            "options": {
                "excludeByName": {
                    "Time": True,
                    "Time 1": True,
                    "Time 2": True,
                    "Time 3": True,
                    "Time 4": True,
                    "Time 5": True,
                    "Time 6": True,
                    "Time 7": True,
                    "Time 8": True,
                    "Time 9": True,
                    "Time 10": True,
                    "__name__": True,
                    "__name__ 1": True,
                    "job": True,
                    "instance": True,
                    "role": True,
                    "domain": True,
                    "state_desc": True,
                    "ip": True,
                },
                "renameByName": {
                    "vm": "VM",
                    "Value": "libvirt_state",
                    "Value #A": "state",
                    "Value #B": "vCPU",
                    "Value #C": "RAM alloc",
                    "Value #D": "CPU",
                    "Value #E": "RSS",
                    "Value #F": "ICMP",
                    "Value #G": "SSH",
                    "Value #H": "HTTP",
                    "Value #I": "disk /",
                    "Value #J": "RAM guest",
                    "Value #K": "node_exporter",
                },
                "indexByName": {
                    "VM": 0,
                    "state": 1,
                    "ICMP": 2,
                    "SSH": 3,
                    "HTTP": 4,
                    "node_exporter": 5,
                    "vCPU": 6,
                    "CPU": 7,
                    "RAM alloc": 8,
                    "RSS": 9,
                    "RAM guest": 10,
                    "disk /": 11,
                },
            },
        },
    ]

    host_cpu = (
        '100 * (1 - avg without (cpu,mode) (rate(node_cpu_seconds_total{role="hypervisor",mode="idle"}[2m])))'
    )
    host_ram = (
        '1 - (node_memory_MemAvailable_bytes{role="hypervisor"} / node_memory_MemTotal_bytes{role="hypervisor"})'
    )
    host_swap = (
        '(node_memory_SwapTotal_bytes{role="hypervisor"} - node_memory_SwapFree_bytes{role="hypervisor"})'
        ' / clamp_min(node_memory_SwapTotal_bytes{role="hypervisor"}, 1)'
    )
    host_data = (
        '1 - (node_filesystem_avail_bytes{role="hypervisor",mountpoint="/mnt/data"}'
        ' / node_filesystem_size_bytes{role="hypervisor",mountpoint="/mnt/data"})'
    )

    panels = [
        row(1, "Host (ght-faceid-server)", 0),
        stat(2, "Host CPU", host_cpu, 0, 1, 6, 4, unit="percent", legend="CPU",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]),
        stat(3, "Host RAM", host_ram, 6, 1, 6, 4, unit="percentunit", legend="RAM",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.75}, {"color": "red", "value": 0.9}]),
        stat(4, "Host swap", host_swap, 12, 1, 6, 4, unit="percentunit", legend="swap",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.2}, {"color": "red", "value": 0.5}]),
        stat(5, "/mnt/data used", host_data, 18, 1, 6, 4, unit="percentunit", legend="disk",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.8}, {"color": "red", "value": 0.9}]),
        row(6, "Fleet health", 5),
        stat(7, "VMs running (libvirt state=1)",
             'count(libvirt_domain_info_state == 1) or vector(0)',
             0, 6, 6, 4, legend="running",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 5}, {"color": "green", "value": 6}]),
        stat(8, "ICMP OK",
             'count(probe_success{job="blackbox-icmp",role="guest"} == 1) or vector(0)',
             6, 6, 6, 4, legend="ping",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 4}, {"color": "green", "value": 5}]),
        stat(9, "SSH OK",
             'count(probe_success{job="blackbox-ssh"} == 1) or vector(0)',
             12, 6, 6, 4, legend="ssh",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 4}, {"color": "green", "value": 5}]),
        stat(10, "HTTP apps OK",
             'count(probe_success{job="blackbox-http"} == 1) or vector(0)',
             18, 6, 6, 4, legend="http",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 5}, {"color": "green", "value": 7}]),
        table(11, "All guests — state, resources, probes (real-time)", tbl_targets, 0, 10, 24, 10, transforms),
        row(12, "Per-VM resources", 20),
        gauge_bar(13, "vCPU usage (libvirt CPU time / vCPU)", "vm:cpu_usage_ratio", 0, 21, 8, 10),
        gauge_bar(14, "Guest RAM used (node_exporter)", "guest:mem_used_ratio", 8, 21, 8, 10),
        gauge_bar(15, "Guest root disk used", "guest:root_disk_used_ratio", 16, 21, 8, 10),
        row(16, "Probes over time", 31),
        state_timeline(17, "Libvirt running (1=up)",
                       '(libvirt_domain_info_state == 1)', 0, 32, 8, 8),
        state_timeline(18, "ICMP",
                       'probe_success{job="blackbox-icmp",role="guest"}', 8, 32, 8, 8),
        state_timeline(19, "HTTP apps",
                       'probe_success{job="blackbox-http"}', 16, 32, 8, 8, legend="{{vm}} {{app}}"),
        row(20, "Trends", 40),
        timeseries(21, "VM CPU % (libvirt)", "vm:cpu_usage_ratio * 100", 0, 41, 12, 8, unit="percent"),
        timeseries(22, "VM RSS (host view)", "libvirt_domain_memory_stats_rss_bytes", 12, 41, 12, 8, unit="bytes"),
        timeseries(23, "Guest disk / used %", "guest:root_disk_used_ratio * 100", 0, 49, 12, 8, unit="percent"),
        timeseries(
            24,
            "VM network RX+TX",
            'sum by (vm) (rate(libvirt_domain_interface_stats_receive_bytes_total[2m]) + rate(libvirt_domain_interface_stats_transmit_bytes_total[2m]))',
            12, 49, 12, 8, unit="Bps",
        ),
        row(25, "Firing alerts", 57),
        table(
            26,
            "Prometheus ALERTS (firing)",
            [target('ALERTS{alertstate="firing"}', "{{alertname}} {{vm}}", "A", instant=True, fmt="table")],
            0, 58, 24, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {
                    "id": "organize",
                    "options": {
                        "excludeByName": {"Time": True, "__name__": True, "prometheus": True, "monitor": True},
                        "indexByName": {"alertname": 0, "severity": 1, "vm": 2, "alertstate": 3, "app": 4},
                    },
                },
            ],
        ),
    ]
    return dashboard(
        "KVM Fleet Overview",
        "kvm-fleet",
        panels,
        tags=["kvm", "overview"],
        description="All guests + hypervisor: libvirt, node_exporter, ICMP/SSH/HTTP. Refresh 10s.",
    )


def guest_detail():
    vm = '$vm'
    panels = [
        row(1, f"Status — {vm}", 0),
        stat(2, "Libvirt state (1=running)",
             f'libvirt_domain_info_state{{vm="{vm}"}}',
             0, 1, 4, 4, legend="state",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(3, "ICMP",
             f'probe_success{{job="blackbox-icmp",vm="{vm}"}}',
             4, 1, 4, 4, legend="ping",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(4, "SSH :22",
             f'probe_success{{job="blackbox-ssh",vm="{vm}"}}',
             8, 1, 4, 4, legend="ssh",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(5, "HTTP (min of apps)",
             f'min(probe_success{{job="blackbox-http",vm="{vm}"}}) or vector(0)',
             12, 1, 4, 4, legend="http",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(6, "vCPU count",
             f'libvirt_domain_info_virtual_cpus{{vm="{vm}"}}',
             16, 1, 4, 4, legend="vcpu",
             thresholds=[{"color": "blue", "value": None}]),
        stat(7, "RAM allocated",
             f'libvirt_domain_info_maximum_memory_bytes{{vm="{vm}"}}',
             20, 1, 4, 4, unit="bytes", legend="alloc",
             thresholds=[{"color": "blue", "value": None}]),
        stat(8, "Guest CPU (node)",
             f'100 * (1 - avg without (cpu,mode) (rate(node_cpu_seconds_total{{vm="{vm}",mode="idle"}}[2m])))',
             0, 5, 6, 4, unit="percent", legend="cpu",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]),
        stat(9, "Guest RAM used",
             f'guest:mem_used_ratio{{vm="{vm}"}}',
             6, 5, 6, 4, unit="percentunit", legend="ram",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.8}, {"color": "red", "value": 0.9}]),
        stat(10, "Guest / used",
             f'guest:root_disk_used_ratio{{vm="{vm}"}}',
             12, 5, 6, 4, unit="percentunit", legend="disk",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.85}, {"color": "red", "value": 0.95}]),
        stat(11, "Load 1m",
             f'node_load1{{vm="{vm}"}}',
             18, 5, 6, 4, legend="load",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 4}, {"color": "red", "value": 12}]),
        row(12, "CPU / RAM / disk", 9),
        timeseries(13, "CPU % (guest node_exporter + libvirt)",
                   f'100 * (1 - avg without (cpu,mode) (rate(node_cpu_seconds_total{{vm="{vm}",mode="idle"}}[2m])))',
                   0, 10, 12, 8, unit="percent", legend="guest OS",
                   extra_targets=[
                       target(f'vm:cpu_usage_ratio{{vm="{vm}"}} * 100', "libvirt vCPU", "B"),
                       target(f'100 * rate(node_cpu_seconds_total{{vm="{vm}",mode="iowait"}}[2m])', "iowait", "C"),
                       target(f'100 * rate(node_cpu_seconds_total{{vm="{vm}",mode="steal"}}[2m])', "steal", "D"),
                   ]),
        timeseries(14, "Memory",
                   f'node_memory_MemTotal_bytes{{vm="{vm}"}}',
                   12, 10, 12, 8, unit="bytes", legend="total",
                   extra_targets=[
                       target(f'node_memory_MemTotal_bytes{{vm="{vm}"}} - node_memory_MemAvailable_bytes{{vm="{vm}"}}', "used (guest)", "B"),
                       target(f'libvirt_domain_memory_stats_rss_bytes{{vm="{vm}"}}', "RSS (host)", "C"),
                       target(f'node_memory_SwapTotal_bytes{{vm="{vm}"}} - node_memory_SwapFree_bytes{{vm="{vm}"}}', "swap used", "D"),
                   ]),
        timeseries(15, "Filesystems used %",
                   f'1 - (node_filesystem_avail_bytes{{vm="{vm}",fstype!~"tmpfs|overlay|squashfs|nsfs"}} / node_filesystem_size_bytes{{vm="{vm}",fstype!~"tmpfs|overlay|squashfs|nsfs"}})',
                   0, 18, 12, 8, unit="percentunit", legend="{{mountpoint}}"),
        timeseries(
            16,
            "Disk I/O (libvirt)",
            f'rate(libvirt_domain_block_stats_read_bytes_total{{vm="{vm}"}}[2m])',
            12, 18, 12, 8, unit="Bps", legend="read {{target_device}}",
            extra_targets=[
                target(f'rate(libvirt_domain_block_stats_write_bytes_total{{vm="{vm}"}}[2m])', "write {{target_device}}", "B"),
            ],
        ),
        row(17, "Network & HTTP", 26),
        timeseries(
            18,
            "Network (libvirt)",
            f'rate(libvirt_domain_interface_stats_receive_bytes_total{{vm="{vm}"}}[2m])',
            0, 27, 12, 8, unit="Bps", legend="RX {{target_device}}",
            extra_targets=[
                target(f'rate(libvirt_domain_interface_stats_transmit_bytes_total{{vm="{vm}"}}[2m])', "TX {{target_device}}", "B"),
            ],
        ),
        timeseries(19, "HTTP probe duration",
                   f'probe_duration_seconds{{job="blackbox-http",vm="{vm}"}}',
                   12, 27, 12, 8, unit="s", legend="{{app}}"),
        table(
            20,
            "HTTP apps",
            [
                target(f'probe_success{{job="blackbox-http",vm="{vm}"}}', "{{app}}", "A", instant=True, fmt="table"),
                target(f'probe_http_status_code{{job="blackbox-http",vm="{vm}"}}', "{{app}}", "B", instant=True, fmt="table"),
                target(f'probe_duration_seconds{{job="blackbox-http",vm="{vm}"}}', "{{app}}", "C", instant=True, fmt="table"),
            ],
            0, 35, 12, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {"id": "joinByField", "options": {"byField": "app", "mode": "outer"}},
                {"id": "organize", "options": {
                    "excludeByName": {"Time": True, "Time 1": True, "Time 2": True, "job": True, "instance": True, "role": True, "vm": True},
                    "renameByName": {"Value #A": "success", "Value #B": "status", "Value #C": "duration_s"},
                }},
            ],
        ),
        table(
            21,
            "Guest filesystems",
            [
                target(
                    f'node_filesystem_size_bytes{{vm="{vm}",fstype!~"tmpfs|overlay|squashfs|nsfs"}}',
                    "{{mountpoint}}", "A", instant=True, fmt="table",
                ),
                target(
                    f'node_filesystem_avail_bytes{{vm="{vm}",fstype!~"tmpfs|overlay|squashfs|nsfs"}}',
                    "{{mountpoint}}", "B", instant=True, fmt="table",
                ),
                target(
                    f'1 - (node_filesystem_avail_bytes{{vm="{vm}",fstype!~"tmpfs|overlay|squashfs|nsfs"}} / node_filesystem_size_bytes{{vm="{vm}",fstype!~"tmpfs|overlay|squashfs|nsfs"}})',
                    "{{mountpoint}}", "C", instant=True, fmt="table",
                ),
            ],
            12, 35, 12, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {"id": "joinByField", "options": {"byField": "mountpoint", "mode": "outer"}},
                {"id": "organize", "options": {
                    "excludeByName": {"Time": True, "Time 1": True, "Time 2": True, "job": True, "instance": True, "role": True, "vm": True, "device": True, "fstype": True},
                    "renameByName": {"Value #A": "size", "Value #B": "avail", "Value #C": "used_ratio"},
                }},
            ],
        ),
    ]
    return dashboard(
        "Guest VM Detail",
        "kvm-guest",
        panels,
        templating=[vm_var()],
        tags=["kvm", "guest"],
        description="One guest: libvirt + OS (CPU/RAM/disk/steal) + ICMP/SSH/HTTP. Pick VM at the top.",
    )


def host():
    panels = [
        row(1, "Hypervisor", 0),
        timeseries(
            2, "CPU by mode",
            'rate(node_cpu_seconds_total{role="hypervisor"}[2m])',
            0, 1, 12, 8, unit="percentunit", legend="{{mode}}",
        ),
        timeseries(
            3, "Memory",
            'node_memory_MemTotal_bytes{role="hypervisor"}',
            12, 1, 12, 8, unit="bytes", legend="total",
            extra_targets=[
                target('node_memory_MemAvailable_bytes{role="hypervisor"}', "available", "B"),
                target('node_memory_MemTotal_bytes{role="hypervisor"} - node_memory_MemAvailable_bytes{role="hypervisor"}', "used", "C"),
                target('node_memory_SwapTotal_bytes{role="hypervisor"} - node_memory_SwapFree_bytes{role="hypervisor"}', "swap used", "D"),
            ],
        ),
        timeseries(
            4, "Load",
            'node_load1{role="hypervisor"}',
            0, 9, 12, 8, unit="short", legend="load1",
            extra_targets=[
                target('node_load5{role="hypervisor"}', "load5", "B"),
                target('node_load15{role="hypervisor"}', "load15", "C"),
                target('count without(cpu,mode) (node_cpu_seconds_total{role="hypervisor",mode="idle"})', "CPU count", "D"),
            ],
        ),
        timeseries(
            5, "Filesystems",
            '1 - (node_filesystem_avail_bytes{role="hypervisor",fstype!~"tmpfs|overlay|squashfs"} / node_filesystem_size_bytes{role="hypervisor",fstype!~"tmpfs|overlay|squashfs"})',
            12, 9, 12, 8, unit="percentunit", legend="{{mountpoint}}",
        ),
        timeseries(
            6, "Disk I/O bytes",
            'rate(node_disk_read_bytes_total{role="hypervisor"}[2m])',
            0, 17, 12, 8, unit="Bps", legend="read {{device}}",
            extra_targets=[
                target('rate(node_disk_written_bytes_total{role="hypervisor"}[2m])', "write {{device}}", "B"),
            ],
        ),
        timeseries(
            7, "Host NICs",
            'rate(node_network_receive_bytes_total{role="hypervisor",device=~"br0|br1|enp.*"}[2m])',
            12, 17, 12, 8, unit="Bps", legend="RX {{device}}",
            extra_targets=[
                target('rate(node_network_transmit_bytes_total{role="hypervisor",device=~"br0|br1|enp.*"}[2m])', "TX {{device}}", "B"),
            ],
        ),
        timeseries(
            8, "Allocated vCPU vs host threads (sum of running domains)",
            'sum(libvirt_domain_info_virtual_cpus) / count without(cpu,mode) (node_cpu_seconds_total{role="hypervisor",mode="idle"})',
            0, 25, 12, 8, unit="short", legend="vCPU / host CPU",
        ),
        timeseries(
            9, "Allocated RAM vs host",
            'sum(libvirt_domain_info_maximum_memory_bytes) / node_memory_MemTotal_bytes{role="hypervisor"}',
            12, 25, 12, 8, unit="percentunit", legend="RAM overcommit ratio",
        ),
    ]
    return dashboard(
        "KVM Host",
        "kvm-host",
        panels,
        tags=["kvm", "host"],
        description="Hypervisor node_exporter + overcommit vs running domains.",
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in (
        ("kvm-fleet-overview.json", fleet()),
        ("guest-vm-detail.json", guest_detail()),
        ("kvm-host.json", host()),
    ):
        path = OUT / name
        path.write_text(json.dumps(data, indent=2) + "\n")
        print("wrote", path)


if __name__ == "__main__":
    main()
