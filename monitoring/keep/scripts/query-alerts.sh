#!/usr/bin/env bash
# Snapshot alert Prometheus (firing/pending) trước khi gắn Keep.
set -euo pipefail
python3 - <<'PY'
import json, urllib.request
from collections import Counter
with urllib.request.urlopen("http://127.0.0.1:9091/api/v1/alerts") as r:
    d = json.load(r)
alerts = d.get("data", {}).get("alerts", [])
print("count", len(alerts), "states", dict(Counter(a.get("state") for a in alerts)))
for a in sorted(alerts, key=lambda x: (x.get("state", ""), x.get("labels", {}).get("alertname", ""))):
    L = a.get("labels", {})
    print("%-8s %-8s %-32s vm=%-16s host=%-20s job=%s" % (
        a.get("state"), L.get("severity", "?"), L.get("alertname", ""),
        L.get("vm", "-"), L.get("host", "-"), L.get("job", "-")))
PY
