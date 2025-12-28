# Sync Koala Docker Compose Deployment

## Deployment Status: ✅ SUCCESSFUL

The thaiduongco-hrm service is now running on the FaceID VM with host network mode.

## Configuration

- **Location**: `/home/koala/sync_koala/` on FaceID VM
- **Network Mode**: host (allows 127.0.0.1 connectivity to MySQL and Redis)
- **Container Name**: sync_koala_thaiduongco-hrm_1
- **Image**: giahungtechnology/ght-sync-hrm:lastest
- **Application Port**: 5609

## Verified Connectivity

✅ MySQL: 127.0.0.1:3306 (root/root)
✅ Redis: 127.0.0.1:6379
✅ Application: 127.0.0.1:5609
✅ Host Network: Fully functional

## Environment Variables

```yaml
MYSQL_HOST=127.0.0.1
MYSQL_USER=root
MYSQL_PASSWORD=root
MYSQL_DATABASE=koala_online_tdc
MYSQL_PORT=3306
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
THAIDUONG_HRM_URL=https://hronline.thaiduongco.com/webhooks/v2box?owner=HRONLINE&hash=84f386bacaa5a69c08c32d5870c3cd28
FACEID_URL=http://127.0.0.1
APP_ID=infiwk322l2nknfdsnfjksd23
```

## Management Scripts

### Deploy/Update Service
```bash
./scripts/helpers/deploy-sync-koala.sh
```

### Verify Health
```bash
./scripts/helpers/verify-sync-koala.sh
```

### Manual Management
```bash
# SSH to VM
ssh koala@10.168.1.55

# Navigate to directory
cd /home/koala/sync_koala

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Restart service
docker-compose restart

# Stop service
docker-compose down

# Start service
docker-compose up -d

# View container details
docker ps
docker inspect sync_koala_thaiduongco-hrm_1
```

## Health Check

The container includes an optimized health check that verifies the application is responding on port 5609:
- **Test**: `curl -s http://127.0.0.1:5609/` (checks if application responds)
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Retries**: 3
- **Start period**: 40 seconds
- **Status**: ✅ **healthy**

The healthcheck accepts any HTTP response (including 404) as healthy, since the application's root endpoint returns 404 but specific endpoints like `/auth/login` and `/sync_data` work correctly.

## Logs Verification

Recent logs show successful operation:
```
[INFO] Listening at: http://0.0.0.0:5609
[INFO] Application startup complete
Connection to MySQL DB successful
```

## Troubleshooting

### Container keeps restarting
Check logs: `docker-compose logs --tail=50`

### MySQL connection failed
1. Verify MySQL is running: `systemctl status mysql`
2. Check credentials: `mysql -u root -proot -e "SELECT 1;"`
3. Verify host network: `docker inspect sync_koala_thaiduongco-hrm_1 | grep NetworkMode`

### Redis connection failed
1. Verify Redis is running: `systemctl status redis`
2. Test connection: `redis-cli ping`

### Port 5609 not accessible
Check if application is listening: `netstat -tlnp | grep 5609`

## Next Steps

The service is fully operational and ready for use. Monitor the logs regularly:
```bash
ssh koala@10.168.1.55 "docker-compose -f /home/koala/sync_koala/docker-compose.yml logs -f"
```
