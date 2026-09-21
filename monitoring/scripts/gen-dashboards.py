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


def gauge_bar(pid, title, expr, x, y, w, h, unit="percentunit", maxv=1, legend="{{vm}}", thresh=None):
    steps = thresh or [
        {"color": "green", "value": None},
        {"color": "yellow", "value": 0.7},
        {"color": "red", "value": 0.9},
    ]
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
                    "steps": steps,
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
            {"asDropdown": True, "icon": "dashboard", "includeVars": True, "keepTime": True, "tags": ["kvm"], "title": "KVM dashboards", "type": "dashboards"},
            {"asDropdown": True, "icon": "dashboard", "includeVars": True, "keepTime": True, "tags": ["physical"], "title": "Physical hosts", "type": "dashboards"},
            {"asDropdown": True, "icon": "dashboard", "includeVars": True, "keepTime": True, "tags": ["aibox"], "title": "AI Box", "type": "dashboards"},
            {"asDropdown": True, "icon": "dashboard", "includeVars": True, "keepTime": True, "tags": ["oraybox"], "title": "Oraybox", "type": "dashboards"},
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


def host_var():
    return {
        "name": "host",
        "type": "query",
        "label": "Host",
        "datasource": DS,
        "query": 'label_values(up{job="physical"}, host)',
        "refresh": 2,
        "includeAll": False,
        "multi": False,
        "sort": 1,
        "current": {},
        "hide": 0,
        "regex": "",
        "definition": 'label_values(up{job="physical"}, host)',
    }


def aibox_var():
    return {
        "name": "host",
        "type": "query",
        "label": "AI Box",
        "datasource": DS,
        "query": 'label_values(up{job="aibox"}, host)',
        "refresh": 2,
        "includeAll": True,
        "multi": True,
        "sort": 1,
        "current": {"text": "All", "value": "$__all"},
        "hide": 0,
        "regex": "",
        "allValue": ".*",
        "definition": 'label_values(up{job="aibox"}, host)',
    }


def oraybox_var():
    return {
        "name": "host",
        "type": "query",
        "label": "Oraybox",
        "datasource": DS,
        "query": 'label_values(up{job="oraybox"}, host)',
        "refresh": 2,
        "includeAll": True,
        "multi": True,
        "sort": 1,
        "current": {"text": "All", "value": "$__all"},
        "hide": 0,
        "regex": "",
        "allValue": ".*",
        "definition": 'label_values(up{job="oraybox"}, host)',
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
        row(10, "Temperature", 33),
        stat(11, "CPU / package",
             'physical:cpu_temp_celsius{role="hypervisor"}',
             0, 34, 8, 4, unit="celsius", legend="cpu",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 75}, {"color": "red", "value": 85}]),
        stat(12, "NVMe",
             'physical:nvme_temp_celsius{role="hypervisor"}',
             8, 34, 8, 4, unit="celsius", legend="nvme",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 65}, {"color": "red", "value": 75}]),
        stat(13, "Hottest hwmon",
             'physical:temp_max_celsius{role="hypervisor"}',
             16, 34, 8, 4, unit="celsius", legend="max",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 75}, {"color": "red", "value": 85}]),
        timeseries(
            14, "hwmon sensors",
            'node_hwmon_temp_celsius{role="hypervisor"}',
            0, 38, 12, 8, unit="celsius", legend="{{chip}} {{sensor}}",
        ),
        timeseries(
            15, "Thermal zones",
            'node_thermal_zone_temp{role="hypervisor"}',
            12, 38, 12, 8, unit="celsius", legend="{{type}} zone{{zone}}",
        ),
    ]
    return dashboard(
        "KVM Host",
        "kvm-host",
        panels,
        tags=["kvm", "host"],
        description="Hypervisor node_exporter + overcommit vs running domains.",
    )


def physical_fleet():
    cpu = '100 * (1 - avg by (host) (rate(node_cpu_seconds_total{role="physical",mode="idle"}[2m])))'
    tbl_targets = [
        target('up{job="physical"}', "{{host}}", "A", instant=True, fmt="table"),
        target('probe_success{job="blackbox-icmp",role="physical"}', "{{host}}", "B", instant=True, fmt="table"),
        target('probe_success{job="blackbox-ssh",role="physical"}', "{{host}}", "C", instant=True, fmt="table"),
        target('min by (host) (probe_success{job="blackbox-http",role="physical"})', "{{host}}", "J", instant=True, fmt="table"),
        target(cpu, "{{host}}", "D", instant=True, fmt="table"),
        target("physical:mem_used_ratio", "{{host}}", "E", instant=True, fmt="table"),
        target("physical:root_disk_used_ratio", "{{host}}", "F", instant=True, fmt="table"),
        target('node_memory_MemTotal_bytes{role="physical"}', "{{host}}", "G", instant=True, fmt="table"),
        target('count without(cpu,mode) (node_cpu_seconds_total{role="physical",mode="idle"})', "{{host}}", "H", instant=True, fmt="table"),
        target('node_uname_info{role="physical"}', "{{host}}", "I", instant=True, fmt="table"),
        target('physical:cpu_temp_celsius{role="physical"}', "{{host}}", "K", instant=True, fmt="table"),
        target('physical:nvme_temp_celsius{role="physical"}', "{{host}}", "L", instant=True, fmt="table"),
    ]
    transforms = [
        {"id": "labelsToFields", "options": {"mode": "columns"}},
        {"id": "joinByField", "options": {"byField": "host", "mode": "outer"}},
        {
            "id": "organize",
            "options": {
                "excludeByName": {
                    "Time": True, "Time 1": True, "Time 2": True, "Time 3": True,
                    "Time 4": True, "Time 5": True, "Time 6": True, "Time 7": True,
                    "Time 8": True, "__name__": True, "job": True, "instance": True,
                    "role": True, "ip": True, "machine": True, "nodename": True,
                    "release": True, "sysname": True, "version": True, "domainname": True,
                },
                "renameByName": {
                    "host": "host",
                    "Value #A": "exporter",
                    "Value #B": "ICMP",
                    "Value #C": "SSH",
                    "Value #J": "HTTP",
                    "Value #D": "CPU %",
                    "Value #E": "RAM",
                    "Value #F": "disk /",
                    "Value #G": "RAM total",
                    "Value #H": "CPUs",
                    "Value #I": "uname",
                    "Value #K": "CPU °C",
                    "Value #L": "NVMe °C",
                },
                "indexByName": {
                    "host": 0, "exporter": 1, "ICMP": 2, "SSH": 3, "HTTP": 4,
                    "CPUs": 5, "CPU %": 6, "RAM total": 7, "RAM": 8, "disk /": 9,
                    "CPU °C": 10, "NVMe °C": 11,
                },
            },
        },
    ]
    panels = [
        row(1, "Physical hosts (excl. KVM hypervisor 10.168.1.2)", 0),
        stat(2, "Hosts up (exporter)",
             'count(up{job="physical"} == 1) or vector(0)',
             0, 1, 6, 4, legend="up",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 4}, {"color": "green", "value": 5}]),
        stat(3, "ICMP OK",
             'count(probe_success{job="blackbox-icmp",role="physical"} == 1) or vector(0)',
             6, 1, 6, 4, legend="ping",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 4}, {"color": "green", "value": 5}]),
        stat(4, "SSH OK",
             'count(probe_success{job="blackbox-ssh",role="physical"} == 1) or vector(0)',
             12, 1, 6, 4, legend="ssh",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 4}, {"color": "green", "value": 5}]),
        stat(5, "Max RAM used",
             'max(physical:mem_used_ratio) or vector(0)',
             18, 1, 6, 4, unit="percentunit", legend="ram",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.8}, {"color": "red", "value": 0.9}]),
        table(6, "All physical hosts — CPU, RAM, disk, temp, probes", tbl_targets, 0, 5, 24, 10, transforms),
        row(7, "Resources", 15),
        gauge_bar(8, "CPU used",
                  '1 - avg by (host) (rate(node_cpu_seconds_total{role="physical",mode="idle"}[2m]))',
                  0, 16, 8, 10, legend="{{host}}"),
        gauge_bar(9, "RAM used", "physical:mem_used_ratio", 8, 16, 8, 10, legend="{{host}}"),
        gauge_bar(10, "Root disk used", "physical:root_disk_used_ratio", 16, 16, 8, 10, legend="{{host}}"),
        row(11, "Trends", 26),
        timeseries(12, "CPU %", cpu, 0, 27, 12, 8, unit="percent", legend="{{host}}"),
        timeseries(13, "RAM used %", "physical:mem_used_ratio * 100", 12, 27, 12, 8, unit="percent", legend="{{host}}"),
        timeseries(14, "Root disk used %", "physical:root_disk_used_ratio * 100", 0, 35, 12, 8, unit="percent", legend="{{host}}"),
        timeseries(
            15, "Network RX+TX (non-virtual NICs)",
            'sum by (host) (rate(node_network_receive_bytes_total{role="physical",device!~"lo|docker.*|br-.*|veth.*|cni.*|tun.*"}[2m]) + rate(node_network_transmit_bytes_total{role="physical",device!~"lo|docker.*|br-.*|veth.*|cni.*|tun.*"}[2m]))',
            12, 35, 12, 8, unit="Bps", legend="{{host}}",
        ),
        state_timeline(16, "Exporter up", 'up{job="physical"}', 0, 43, 12, 6, legend="{{host}}"),
        state_timeline(17, "ICMP", 'probe_success{job="blackbox-icmp",role="physical"}', 12, 43, 12, 6, legend="{{host}}"),
        row(27, "Temperature", 49),
        gauge_bar(
            28, "CPU / package °C",
            'physical:cpu_temp_celsius{role="physical"}',
            0, 50, 12, 8, unit="celsius", maxv=100, legend="{{host}}",
            thresh=[
                {"color": "green", "value": None},
                {"color": "yellow", "value": 75},
                {"color": "red", "value": 85},
            ],
        ),
        gauge_bar(
            29, "NVMe °C",
            'physical:nvme_temp_celsius{role="physical"}',
            12, 50, 12, 8, unit="celsius", maxv=100, legend="{{host}}",
            thresh=[
                {"color": "green", "value": None},
                {"color": "yellow", "value": 65},
                {"color": "red", "value": 75},
            ],
        ),
        timeseries(30, "CPU temperature",
                   'physical:cpu_temp_celsius{role="physical"}',
                   0, 58, 12, 8, unit="celsius", legend="{{host}}"),
        timeseries(31, "NVMe temperature",
                   'physical:nvme_temp_celsius{role="physical"}',
                   12, 58, 12, 8, unit="celsius", legend="{{host}}"),
        row(18, "Firing alerts", 66),
        table(
            19,
            "Prometheus ALERTS (physical)",
            [target('ALERTS{alertstate="firing",host=~".+"}', "{{alertname}} {{host}}", "A", instant=True, fmt="table")],
            0, 67, 24, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {
                    "id": "organize",
                    "options": {
                        "excludeByName": {"Time": True, "__name__": True, "prometheus": True, "monitor": True},
                        "indexByName": {"alertname": 0, "severity": 1, "host": 2, "alertstate": 3},
                    },
                },
            ],
        ),
    ]
    return dashboard(
        "Physical Hosts Overview",
        "physical-fleet",
        panels,
        tags=["physical", "overview"],
        description="LAN bare-metal Ubuntu hosts (not the KVM hypervisor). CPU/RAM/disk + ICMP/SSH. Refresh 10s.",
    )


def physical_detail():
    h = "$host"
    panels = [
        row(1, f"Status — {h}", 0),
        stat(2, "node_exporter",
             f'up{{job="physical",host="{h}"}}',
             0, 1, 4, 4, legend="up",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(3, "ICMP",
             f'probe_success{{job="blackbox-icmp",role="physical",host="{h}"}}',
             4, 1, 4, 4, legend="ping",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(4, "SSH :22",
             f'probe_success{{job="blackbox-ssh",role="physical",host="{h}"}}',
             8, 1, 4, 4, legend="ssh",
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat(5, "CPU count",
             f'count without(cpu,mode) (node_cpu_seconds_total{{role="physical",host="{h}",mode="idle"}})',
             12, 1, 4, 4, legend="cpus",
             thresholds=[{"color": "blue", "value": None}]),
        stat(6, "RAM total",
             f'node_memory_MemTotal_bytes{{role="physical",host="{h}"}}',
             16, 1, 4, 4, unit="bytes", legend="ram",
             thresholds=[{"color": "blue", "value": None}]),
        stat(7, "Load 1m",
             f'node_load1{{role="physical",host="{h}"}}',
             20, 1, 4, 4, legend="load",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 4}, {"color": "red", "value": 16}]),
        stat(8, "CPU used",
             f'100 * (1 - avg without (cpu,mode) (rate(node_cpu_seconds_total{{role="physical",host="{h}",mode="idle"}}[2m])))',
             0, 5, 6, 4, unit="percent", legend="cpu",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]),
        stat(9, "RAM used",
             f'physical:mem_used_ratio{{host="{h}"}}',
             6, 5, 6, 4, unit="percentunit", legend="ram",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.8}, {"color": "red", "value": 0.9}]),
        stat(10, "Root disk used",
             f'physical:root_disk_used_ratio{{host="{h}"}}',
             12, 5, 6, 4, unit="percentunit", legend="disk",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.85}, {"color": "red", "value": 0.95}]),
        stat(11, "Swap used",
             f'(node_memory_SwapTotal_bytes{{role="physical",host="{h}"}} - node_memory_SwapFree_bytes{{role="physical",host="{h}"}}) / clamp_min(node_memory_SwapTotal_bytes{{role="physical",host="{h}"}}, 1)',
             18, 5, 6, 4, unit="percentunit", legend="swap",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 0.2}, {"color": "red", "value": 0.5}]),
        row(12, "CPU / RAM / disk", 9),
        timeseries(13, "CPU by mode",
                   f'rate(node_cpu_seconds_total{{role="physical",host="{h}"}}[2m])',
                   0, 10, 12, 8, unit="percentunit", legend="{{mode}}"),
        timeseries(14, "Memory",
                   f'node_memory_MemTotal_bytes{{role="physical",host="{h}"}}',
                   12, 10, 12, 8, unit="bytes", legend="total",
                   extra_targets=[
                       target(f'node_memory_MemAvailable_bytes{{role="physical",host="{h}"}}', "available", "B"),
                       target(f'node_memory_MemTotal_bytes{{role="physical",host="{h}"}} - node_memory_MemAvailable_bytes{{role="physical",host="{h}"}}', "used", "C"),
                       target(f'node_memory_SwapTotal_bytes{{role="physical",host="{h}"}} - node_memory_SwapFree_bytes{{role="physical",host="{h}"}}', "swap used", "D"),
                   ]),
        timeseries(15, "Load",
                   f'node_load1{{role="physical",host="{h}"}}',
                   0, 18, 12, 8, unit="short", legend="load1",
                   extra_targets=[
                       target(f'node_load5{{role="physical",host="{h}"}}', "load5", "B"),
                       target(f'node_load15{{role="physical",host="{h}"}}', "load15", "C"),
                   ]),
        timeseries(16, "Filesystems used %",
                   f'1 - (node_filesystem_avail_bytes{{role="physical",host="{h}",fstype!~"tmpfs|overlay|squashfs|nsfs"}} / node_filesystem_size_bytes{{role="physical",host="{h}",fstype!~"tmpfs|overlay|squashfs|nsfs"}})',
                   12, 18, 12, 8, unit="percentunit", legend="{{mountpoint}}"),
        timeseries(17, "Disk I/O",
                   f'rate(node_disk_read_bytes_total{{role="physical",host="{h}"}}[2m])',
                   0, 26, 12, 8, unit="Bps", legend="read {{device}}",
                   extra_targets=[
                       target(f'rate(node_disk_written_bytes_total{{role="physical",host="{h}"}}[2m])', "write {{device}}", "B"),
                   ]),
        timeseries(18, "Network",
                   f'rate(node_network_receive_bytes_total{{role="physical",host="{h}",device!~"lo|docker.*|br-.*|veth.*|cni.*|tun.*"}}[2m])',
                   12, 26, 12, 8, unit="Bps", legend="RX {{device}}",
                   extra_targets=[
                       target(f'rate(node_network_transmit_bytes_total{{role="physical",host="{h}",device!~"lo|docker.*|br-.*|veth.*|cni.*|tun.*"}}[2m])', "TX {{device}}", "B"),
                   ]),
        table(
            19,
            "Filesystems",
            [
                target(
                    f'node_filesystem_size_bytes{{role="physical",host="{h}",fstype!~"tmpfs|overlay|squashfs|nsfs"}}',
                    "{{mountpoint}}", "A", instant=True, fmt="table",
                ),
                target(
                    f'node_filesystem_avail_bytes{{role="physical",host="{h}",fstype!~"tmpfs|overlay|squashfs|nsfs"}}',
                    "{{mountpoint}}", "B", instant=True, fmt="table",
                ),
                target(
                    f'1 - (node_filesystem_avail_bytes{{role="physical",host="{h}",fstype!~"tmpfs|overlay|squashfs|nsfs"}} / node_filesystem_size_bytes{{role="physical",host="{h}",fstype!~"tmpfs|overlay|squashfs|nsfs"}})',
                    "{{mountpoint}}", "C", instant=True, fmt="table",
                ),
            ],
            0, 34, 24, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {"id": "joinByField", "options": {"byField": "mountpoint", "mode": "outer"}},
                {"id": "organize", "options": {
                    "excludeByName": {"Time": True, "Time 1": True, "Time 2": True, "job": True, "instance": True, "role": True, "host": True, "device": True, "fstype": True},
                    "renameByName": {"Value #A": "size", "Value #B": "avail", "Value #C": "used_ratio"},
                }},
            ],
        ),
        row(30, "Temperature", 42),
        stat(31, "CPU / package",
             f'physical:cpu_temp_celsius{{host="{h}"}}',
             0, 43, 8, 4, unit="celsius", legend="cpu",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 75}, {"color": "red", "value": 85}]),
        stat(32, "NVMe",
             f'physical:nvme_temp_celsius{{host="{h}"}}',
             8, 43, 8, 4, unit="celsius", legend="nvme",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 65}, {"color": "red", "value": 75}]),
        stat(33, "Hottest hwmon",
             f'physical:temp_max_celsius{{host="{h}"}}',
             16, 43, 8, 4, unit="celsius", legend="max",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 75}, {"color": "red", "value": 85}]),
        timeseries(
            34, "hwmon sensors",
            f'node_hwmon_temp_celsius{{host="{h}"}}',
            0, 47, 12, 8, unit="celsius", legend="{{chip}} {{sensor}}",
        ),
        timeseries(
            35, "Thermal zones",
            f'node_thermal_zone_temp{{host="{h}"}}',
            12, 47, 12, 8, unit="celsius", legend="{{type}} zone{{zone}}",
        ),
    ]
    return dashboard(
        "Physical Host Detail",
        "physical-host",
        panels,
        templating=[host_var()],
        tags=["physical", "host"],
        description="One bare-metal host: CPU, RAM, disk, network, temperature, ICMP/SSH. Pick host at the top.",
    )


def physical_temp():
    cpu_all = 'physical:cpu_temp_celsius'
    nvme_all = 'physical:nvme_temp_celsius'
    thresh_cpu = [
        {"color": "green", "value": None},
        {"color": "yellow", "value": 75},
        {"color": "red", "value": 85},
    ]
    thresh_nvme = [
        {"color": "green", "value": None},
        {"color": "yellow", "value": 65},
        {"color": "red", "value": 75},
    ]
    panels = [
        row(1, "All physical machines (incl. KVM hypervisor)", 0),
        stat(2, "Hottest CPU",
             f'max({cpu_all})',
             0, 1, 6, 4, unit="celsius", legend="max",
             thresholds=thresh_cpu),
        stat(3, "Hottest NVMe",
             f'max({nvme_all}) or vector(0)',
             6, 1, 6, 4, unit="celsius", legend="nvme",
             thresholds=thresh_nvme),
        stat(4, "Hosts with CPU sensor",
             f'count({cpu_all}) or vector(0)',
             12, 1, 6, 4, legend="sensors",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 4}, {"color": "green", "value": 5}]),
        stat(5, "Hosts missing CPU temp",
             'count(up{job=~"host|physical"} == 1 unless on(host) physical:cpu_temp_celsius) or vector(0)',
             18, 1, 6, 4, legend="missing",
             thresholds=[{"color": "green", "value": None}, {"color": "red", "value": 1}]),
        gauge_bar(
            6, "CPU / package °C",
            cpu_all, 0, 5, 12, 10, unit="celsius", maxv=100, legend="{{host}}",
            thresh=thresh_cpu,
        ),
        gauge_bar(
            7, "NVMe °C",
            nvme_all, 12, 5, 12, 10, unit="celsius", maxv=100, legend="{{host}}",
            thresh=thresh_nvme,
        ),
        timeseries(8, "CPU temperature", cpu_all, 0, 15, 12, 8, unit="celsius", legend="{{host}}"),
        timeseries(9, "NVMe temperature", nvme_all, 12, 15, 12, 8, unit="celsius", legend="{{host}}"),
        timeseries(
            10, "All hwmon sensors",
            'node_hwmon_temp_celsius{job=~"host|physical"}',
            0, 23, 24, 10, unit="celsius", legend="{{host}} {{chip}} {{sensor}}",
        ),
        timeseries(
            11, "Thermal zones (skip bogus < 0°C)",
            'node_thermal_zone_temp{job=~"host|physical"} > 0',
            0, 33, 24, 8, unit="celsius", legend="{{host}} {{type}}",
        ),
    ]
    return dashboard(
        "Physical Temperature",
        "physical-temp",
        panels,
        tags=["physical", "temperature"],
        description="CPU package, NVMe and hwmon/thermal-zone temperatures for every bare-metal host including the KVM hypervisor.",
    )


def aibox_overview():
    h = "$host"
    tbl_targets = [
        target('up{job="aibox"}', "{{host}}", "A", instant=True, fmt="table"),
        target('probe_success{job="blackbox-icmp",role="aibox"}', "{{host}}", "B", instant=True, fmt="table"),
        target('probe_success{job="blackbox-http",role="aibox"}', "{{host}}", "C", instant=True, fmt="table"),
        target("megbox_api_code", "{{host}}", "D", instant=True, fmt="table"),
        target("megbox_info", "{{host}}", "E", instant=True, fmt="table"),
        target("megbox_cpu_usage_percent", "{{host}}", "F", instant=True, fmt="table"),
        target("megbox_cpu_temp_celsius", "{{host}}", "G", instant=True, fmt="table"),
        target("megbox_gpu_temp_celsius", "{{host}}", "H", instant=True, fmt="table"),
        target("megbox_case_temp_celsius", "{{host}}", "I", instant=True, fmt="table"),
        target("aibox:mem_used_ratio", "{{host}}", "J", instant=True, fmt="table"),
        target("aibox:storage_used_ratio", "{{host}}", "K", instant=True, fmt="table"),
        target("megbox_channels", "{{host}}", "L", instant=True, fmt="table"),
    ]
    transforms = [
        {"id": "labelsToFields", "options": {"mode": "columns"}},
        {"id": "joinByField", "options": {"byField": "host", "mode": "outer"}},
        {
            "id": "organize",
            "options": {
                "excludeByName": {
                    "Time": True, "Time 1": True, "Time 2": True, "Time 3": True,
                    "Time 4": True, "Time 5": True, "Time 6": True, "Time 7": True,
                    "Time 8": True, "Time 9": True, "Time 10": True, "Time 11": True,
                    "__name__": True, "job": True, "instance": True, "role": True,
                    "ip": True, "vendor": True, "Value #E": True,
                    "hardware_ver": True, "license_key": True, "megconnect_version": True,
                },
                "renameByName": {
                    "host": "host",
                    "Value #A": "scrape",
                    "Value #B": "ICMP",
                    "Value #C": "API",
                    "Value #D": "api code",
                    "device_model": "model",
                    "device_id": "device id",
                    "serial_number": "serial",
                    "firmware_ver": "firmware",
                    "Value #F": "CPU %",
                    "Value #G": "CPU °C",
                    "Value #H": "GPU °C",
                    "Value #I": "case °C",
                    "Value #J": "RAM",
                    "Value #K": "storage",
                    "Value #L": "channels",
                },
                "indexByName": {
                    "host": 0, "scrape": 1, "ICMP": 2, "API": 3, "api code": 4,
                    "model": 5, "firmware": 6, "serial": 7,
                    "CPU %": 8, "CPU °C": 9, "GPU °C": 10, "case °C": 11,
                    "RAM": 12, "storage": 13, "channels": 14,
                },
            },
        },
    ]
    panels = [
        row(1, "Megvii AI Box (MEGBOX /v1/MEGBOX/devices)", 0),
        stat(2, "Boxes up (scrape)",
             f'count(up{{job="aibox",host=~"{h}"}} == 1) or vector(0)',
             0, 1, 6, 4, legend="up",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 2}]),
        stat(3, "ICMP OK",
             f'count(probe_success{{job="blackbox-icmp",role="aibox",host=~"{h}"}} == 1) or vector(0)',
             6, 1, 6, 4, legend="ping",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 2}]),
        stat(4, "API HTTP 200",
             f'count(probe_success{{job="blackbox-http",role="aibox",host=~"{h}"}} == 1) or vector(0)',
             12, 1, 6, 4, legend="api",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 2}]),
        stat(5, "Max CPU temp",
             f'max(megbox_cpu_temp_celsius{{host=~"{h}"}}) or vector(0)',
             18, 1, 6, 4, unit="celsius", legend="cpu",
             thresholds=[{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 80}]),
        table(6, "AI Box inventory — API, hardwareStatus, identity", tbl_targets, 0, 5, 24, 8, transforms),
        row(7, "Resources", 13),
        gauge_bar(8, "CPU used",
                  f'megbox_cpu_usage_percent{{host=~"{h}"}} / 100',
                  0, 14, 8, 8, legend="{{host}}"),
        gauge_bar(9, "RAM used",
                  f'aibox:mem_used_ratio{{host=~"{h}"}}',
                  8, 14, 8, 8, legend="{{host}}"),
        gauge_bar(10, "Storage used",
                  f'aibox:storage_used_ratio{{host=~"{h}"}}',
                  16, 14, 8, 8, legend="{{host}}"),
        row(11, "Trends (scrape 1m)", 22),
        timeseries(12, "CPU %",
                   f'megbox_cpu_usage_percent{{host=~"{h}"}}',
                   0, 23, 12, 8, unit="percent", legend="{{host}}"),
        timeseries(13, "Temperature °C",
                   f'megbox_cpu_temp_celsius{{host=~"{h}"}}',
                   12, 23, 12, 8, unit="celsius", legend="{{host}} CPU",
                   extra_targets=[
                       target(f'megbox_gpu_temp_celsius{{host=~"{h}"}}', "{{host}} GPU", "B"),
                       target(f'megbox_case_temp_celsius{{host=~"{h}"}}', "{{host}} case", "C"),
                   ]),
        timeseries(14, "RAM used %",
                   f'aibox:mem_used_ratio{{host=~"{h}"}} * 100',
                   0, 31, 12, 8, unit="percent", legend="{{host}}"),
        timeseries(15, "Storage used %",
                   f'aibox:storage_used_ratio{{host=~"{h}"}} * 100',
                   12, 31, 12, 8, unit="percent", legend="{{host}}"),
        timeseries(16, "Memory MiB",
                   f'megbox_memory_used_mib{{host=~"{h}"}}',
                   0, 39, 12, 8, unit="mbytes", legend="{{host}} used",
                   extra_targets=[
                       target(f'megbox_memory_size_mib{{host=~"{h}"}}', "{{host}} size", "B"),
                   ]),
        timeseries(17, "Storage MiB",
                   f'megbox_storage_used_mib{{host=~"{h}"}}',
                   12, 39, 12, 8, unit="mbytes", legend="{{host}} used",
                   extra_targets=[
                       target(f'megbox_storage_size_mib{{host=~"{h}"}}', "{{host}} size", "B"),
                   ]),
        row(18, "Availability", 47),
        state_timeline(19, "JSON scrape",
                       f'up{{job="aibox",host=~"{h}"}}',
                       0, 48, 8, 6, legend="{{host}}"),
        state_timeline(20, "ICMP",
                       f'probe_success{{job="blackbox-icmp",role="aibox",host=~"{h}"}}',
                       8, 48, 8, 6, legend="{{host}}"),
        state_timeline(21, "HTTP API",
                       f'probe_success{{job="blackbox-http",role="aibox",host=~"{h}"}}',
                       16, 48, 8, 6, legend="{{host}}"),
        row(22, "Firing alerts", 54),
        table(
            23,
            "Prometheus ALERTS (aibox)",
            [target('ALERTS{alertstate="firing",alertname=~"AiBox.*"}', "{{alertname}} {{host}}", "A", instant=True, fmt="table")],
            0, 55, 24, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {
                    "id": "organize",
                    "options": {
                        "excludeByName": {"Time": True, "__name__": True, "prometheus": True, "monitor": True},
                        "indexByName": {"alertname": 0, "severity": 1, "host": 2, "alertstate": 3},
                    },
                },
            ],
        ),
    ]
    return dashboard(
        "Megvii AI Box",
        "aibox-megvii",
        panels,
        templating=[aibox_var()],
        tags=["aibox", "physical"],
        description="Megvii MegCube AI Box hardwareStatus from GET /v1/MEGBOX/devices. Inventory: monitoring/aibox/devices.json. Scrape 1m.",
    )


def oraybox_overview():
    h = "$host"
    sw_targets = [
        target(f'up{{job="oraybox",host=~"{h}"}}', "{{host}}", "A", instant=True, fmt="table"),
        target(f'probe_success{{job="blackbox-icmp",role="oraybox",host=~"{h}"}}', "{{host}}", "B", instant=True, fmt="table"),
        target(f'probe_success{{job="blackbox-http",role="oraybox",host=~"{h}"}}', "{{host}}", "C", instant=True, fmt="table"),
        target(f'oraybox_api_code{{host=~"{h}"}}', "{{host}}", "D", instant=True, fmt="table"),
        target(f'sum by (host, ip) (oraybox:lan_link_up{{host=~"{h}"}})', "{{host}}", "E", instant=True, fmt="table"),
        target(f'count by (host, ip) (oraybox_lan_info{{host=~"{h}"}})', "{{host}}", "F", instant=True, fmt="table"),
    ]
    sw_transforms = [
        {"id": "labelsToFields", "options": {"mode": "columns"}},
        {"id": "joinByField", "options": {"byField": "host", "mode": "outer"}},
        {
            "id": "organize",
            "options": {
                "excludeByName": {
                    "Time": True, "Time 1": True, "Time 2": True, "Time 3": True,
                    "Time 4": True, "Time 5": True,
                    "__name__": True, "job": True, "instance": True, "role": True,
                    "vendor": True, "mac": True,
                },
                "renameByName": {
                    "host": "host",
                    "ip": "ip",
                    "Value #A": "scrape",
                    "Value #B": "ICMP",
                    "Value #C": "API",
                    "Value #D": "api code",
                    "Value #E": "LAN up",
                    "Value #F": "LAN ports",
                },
                "indexByName": {
                    "host": 0, "ip": 1, "scrape": 2, "ICMP": 3, "API": 4,
                    "api code": 5, "LAN up": 6, "LAN ports": 7,
                },
            },
        },
    ]
    port_targets = [
        target(f'oraybox_lan_info{{host=~"{h}"}}', "{{host}} {{port}}", "A", instant=True, fmt="table"),
    ]
    port_transforms = [
        {"id": "labelsToFields", "options": {"mode": "columns"}},
        {
            "id": "organize",
            "options": {
                "excludeByName": {
                    "Time": True,
                    "__name__": True, "job": True, "instance": True, "role": True,
                    "vendor": True, "mac": True, "Value": True,
                },
                "renameByName": {
                    "host": "host",
                    "ip": "ip",
                    "port": "port",
                    "link": "link",
                    "speed": "speed",
                    "mode": "mode",
                },
                "indexByName": {
                    "host": 0, "ip": 1, "port": 2, "link": 3, "speed": 4, "mode": 5,
                },
            },
        },
    ]
    port_table = table(6, "LAN ports (WAN ignored)", port_targets, 0, 14, 24, 10, port_transforms)
    port_table["fieldConfig"]["overrides"] = [
        {
            "matcher": {"id": "byName", "options": "link"},
            "properties": [
                {
                    "id": "mappings",
                    "value": [
                        {"type": "value", "options": {"up": {"text": "up", "color": "green", "index": 0}, "down": {"text": "down", "color": "red", "index": 1}}},
                    ],
                },
                {"id": "custom.cellOptions", "value": {"type": "color-background"}},
            ],
        },
    ]
    sw_table = table(5, "Switch inventory — ping + ether_status_get", sw_targets, 0, 5, 24, 8, sw_transforms)
    sw_table["fieldConfig"]["overrides"] = [
        {
            "matcher": {"id": "byRegexp", "options": "scrape|ICMP|API"},
            "properties": [
                {
                    "id": "mappings",
                    "value": [
                        {"type": "value", "options": {"0": {"text": "down", "color": "red", "index": 0}, "1": {"text": "up", "color": "green", "index": 1}}},
                    ],
                },
                {"id": "custom.cellOptions", "value": {"type": "color-background"}},
            ],
        },
    ]
    panels = [
        row(1, "Oraybox switches (GET /cgi-bin/oraybox?_api=ether_status_get, LAN only)", 0),
        stat(2, "Switches up (scrape)",
             f'count(up{{job="oraybox",host=~"{h}"}} == 1) or vector(0)',
             0, 1, 6, 4, legend="up",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 4}]),
        stat(3, "ICMP OK",
             f'count(probe_success{{job="blackbox-icmp",role="oraybox",host=~"{h}"}} == 1) or vector(0)',
             6, 1, 6, 4, legend="ping",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 4}]),
        stat(4, "API HTTP 200",
             f'count(probe_success{{job="blackbox-http",role="oraybox",host=~"{h}"}} == 1) or vector(0)',
             12, 1, 6, 4, legend="api",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 4}]),
        stat(7, "LAN ports up",
             f'sum(oraybox:lan_link_up{{host=~"{h}"}}) or vector(0)',
             18, 1, 6, 4, legend="lan up",
             thresholds=[{"color": "red", "value": None}, {"color": "yellow", "value": 1}, {"color": "green", "value": 8}]),
        sw_table,
        port_table,
        row(8, "Availability", 24),
        state_timeline(9, "JSON scrape",
                       f'up{{job="oraybox",host=~"{h}"}}',
                       0, 25, 8, 6, legend="{{host}}"),
        state_timeline(10, "ICMP",
                       f'probe_success{{job="blackbox-icmp",role="oraybox",host=~"{h}"}}',
                       8, 25, 8, 6, legend="{{host}}"),
        state_timeline(11, "HTTP API",
                       f'probe_success{{job="blackbox-http",role="oraybox",host=~"{h}"}}',
                       16, 25, 8, 6, legend="{{host}}"),
        row(12, "LAN port link", 31),
        state_timeline(13, "LAN link up (1) / down (0)",
                       f'oraybox:lan_link_up{{host=~"{h}"}}',
                       0, 32, 24, 8, legend="{{host}} {{port}}"),
        row(14, "Firing alerts", 40),
        table(
            15,
            "Prometheus ALERTS (oraybox)",
            [target('ALERTS{alertstate="firing",alertname=~"Oraybox.*"}', "{{alertname}} {{host}}", "A", instant=True, fmt="table")],
            0, 41, 24, 8,
            [
                {"id": "labelsToFields", "options": {"mode": "columns"}},
                {
                    "id": "organize",
                    "options": {
                        "excludeByName": {"Time": True, "__name__": True, "prometheus": True, "monitor": True},
                        "indexByName": {"alertname": 0, "severity": 1, "host": 2, "alertstate": 3},
                    },
                },
            ],
        ),
    ]
    return dashboard(
        "Oraybox switches",
        "oraybox-lan",
        panels,
        templating=[oraybox_var()],
        tags=["oraybox", "physical"],
        description="Oraybox / 蒲公英 LAN port status from GET /cgi-bin/oraybox?_api=ether_status_get. WAN ignored. Inventory: monitoring/oraybox/devices.json. Scrape 1m.",
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in (
        ("kvm-fleet-overview.json", fleet()),
        ("guest-vm-detail.json", guest_detail()),
        ("kvm-host.json", host()),
        ("physical-hosts-overview.json", physical_fleet()),
        ("physical-host-detail.json", physical_detail()),
        ("physical-temperature.json", physical_temp()),
        ("aibox-megvii.json", aibox_overview()),
        ("oraybox-lan.json", oraybox_overview()),
    ):
        path = OUT / name
        path.write_text(json.dumps(data, indent=2) + "\n")
        print("wrote", path)


if __name__ == "__main__":
    main()
