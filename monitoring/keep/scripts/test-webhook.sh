#!/usr/bin/env bash
# Gửi alert giả vào Keep (không đi qua Alertmanager). Phase 0.
set -euo pipefail
KEY="${KEEP_WEBHOOK_API_KEY:?export KEEP_WEBHOOK_API_KEY}"
URL="${KEEP_API_URL:-http://127.0.0.1:8080}/alerts/event/prometheus"
curl -fsS -X POST "$URL" \
  -u "api_key:${KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "receiver": "keep",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "KeepWebhookTest",
        "severity": "warning",
        "keep_test": "true",
        "vm": "hypervisor",
        "job": "host",
        "monitor": "ght-faceid-server"
      },
      "annotations": {
        "summary": "Keep webhook test",
        "description": "Synthetic alert from keep/scripts/test-webhook.sh"
      },
      "startsAt": "2026-01-01T00:00:00Z",
      "generatorURL": "http://10.168.1.2:9091/alerts"
    }]
  }'
echo
echo "OK posted KeepWebhookTest — kiểm tra UI http://10.168.1.2:3001"
