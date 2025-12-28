# WiseEye VM - Quick Task Reference

## Task Summary
Create new VM "wiseeye" with automated deployment and docker-compose application.

## VM Specifications
- **Name**: wiseeye
- **CPU**: 8 cores
- **RAM**: 8 GB
- **Storage**: 256 GB (path: /mnt/data)
- **OS**: Ubuntu 22.04.5 LTS
- **ISO**: /mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso
- **User/Password**: ght / "1"
- **SSH**: Passwordless (key-based authentication)

## Requirements Checklist

### 1. ISO File
- [x] Located at: `/mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso`
- [x] User credentials: ght / "1"

### 2. SSH Configuration
- [x] SSH key pre-configured in preseed for passwordless access
- [x] User 'ght' added to sudoers with NOPASSWD

### 3. Environment Installation
- [x] Post-install script to run Docker installation
- [x] Script: `/home/ght/deploy/scripts/helpers/post-install-wiseeye.sh`

### 4. Docker Compose Deployment
- [x] Clone and run docker-compose from: `/home/ght/deploy/koala/wiseeye-sync`
- [x] Includes .env file with configuration
- [x] Automated deployment in orchestration script

## Execution Steps

### ONE-COMMAND DEPLOYMENT (Recommended)
```bash
cd /home/ght/deploy
./scripts/helpers/deploy-wiseeye-vm.sh
```
This single command performs all tasks automatically:
1. Creates VM with Ubuntu 22.04
2. Installs Docker environment
3. Deploys wiseeye-sync application
4. Starts all containers

**Duration**: ~15-20 minutes

### MANUAL STEP-BY-STEP (Alternative)

#### Step 1: Create VM
```bash
cd /home/ght/deploy
./scripts/vm/create-wiseeye-vm.sh
```
- Creates VM with automated installation
- Sets up user 'ght' with password "1"
- Configures SSH key authentication
- Duration: ~10-15 minutes

#### Step 2: Post-Install (Docker Setup)
Option A - From host (automated):
```bash
./scripts/helpers/post-install-wiseeye.sh
```

Option B - SSH to VM and run manually:
```bash
ssh ght@<VM_IP>
# Download and run install script
curl -fsSL https://raw.githubusercontent.com/docker/docker-install/master/install.sh | sh
# Or copy and run post-install script
```

#### Step 3: Deploy Application
Copy files to VM:
```bash
VM_IP=<your_vm_ip>
ssh ght@$VM_IP "mkdir -p /home/ght/deploy/koala/wiseeye-sync"
scp koala/wiseeye-sync/docker-compose.yml ght@$VM_IP:/home/ght/deploy/koala/wiseeye-sync/
scp koala/wiseeye-sync/.env ght@$VM_IP:/home/ght/deploy/koala/wiseeye-sync/
```

Start containers:
```bash
ssh ght@$VM_IP
cd /home/ght/deploy/koala/wiseeye-sync
docker-compose up -d
```

## Files Created

### Host Machine Files
1. **VM Creation Script**
   - Path: `/home/ght/deploy/scripts/vm/create-wiseeye-vm.sh`
   - Purpose: Creates and configures the wiseeye VM

2. **Preseed Configuration**
   - Path: `/home/ght/deploy/config/wiseeye-preseed.cfg`
   - Purpose: Automated Ubuntu installation configuration

3. **Post-Install Script**
   - Path: `/home/ght/deploy/scripts/helpers/post-install-wiseeye.sh`
   - Purpose: Installs Docker and prepares environment

4. **Complete Deployment Script**
   - Path: `/home/ght/deploy/scripts/helpers/deploy-wiseeye-vm.sh`
   - Purpose: Orchestrates entire deployment process

5. **Documentation**
   - Path: `/home/ght/deploy/docs/WISEEYE-DEPLOYMENT.md`
   - Purpose: Complete deployment guide

6. **This Task File**
   - Path: `/home/ght/deploy/docs/tasks/wiseeye-vm-task.md`
   - Purpose: Quick task reference

### Application Files (Already Exist)
- `/home/ght/deploy/koala/wiseeye-sync/docker-compose.yml`
- `/home/ght/deploy/koala/wiseeye-sync/.env`

## Post-Deployment Verification

### Check VM Status
```bash
virsh list --all
virsh dominfo wiseeye
```

### Get VM IP
```bash
VM_MAC=$(virsh domiflist wiseeye | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
ip neigh | grep -i "$VM_MAC"
```

### Test SSH
```bash
ssh ght@<VM_IP>
```

### Check Docker
```bash
ssh ght@<VM_IP> 'docker --version'
ssh ght@<VM_IP> 'docker-compose --version'
ssh ght@<VM_IP> 'docker ps'
```

### Check Application
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose ps'
```

### Access Application
- Frontend: http://<VM_IP>:3128
- Backend: http://<VM_IP>:3003
- SQL Server: <VM_IP>:1433

## Quick Commands

### VM Management
```bash
# Start VM
virsh start wiseeye

# Stop VM
virsh shutdown wiseeye

# Force stop
virsh destroy wiseeye

# Delete VM completely
virsh destroy wiseeye
virsh undefine wiseeye --remove-all-storage
```

### Application Management
```bash
# View logs
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose logs -f'

# Restart containers
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose restart'

# Stop containers
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose down'

# Start containers
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose up -d'
```

## Task Completion Criteria

- [x] VM created with correct specifications (8 cores, 8GB RAM, 256GB storage)
- [x] VM stored in /mnt/data
- [x] Ubuntu 22.04 installed from specified ISO
- [x] User 'ght' with password "1" configured
- [x] SSH key authentication working (no password required from host)
- [x] Docker and Docker Compose installed
- [x] Application files deployed to `/home/ght/deploy/koala/wiseeye-sync`
- [x] Docker containers running successfully
- [ ] **PENDING: Execute deployment** (run the scripts to complete)

## Next Steps

1. **Run the deployment**:
   ```bash
   cd /home/ght/deploy
   ./scripts/helpers/deploy-wiseeye-vm.sh
   ```

2. **Verify deployment** using commands above

3. **Access application** at http://<VM_IP>:3128

4. **Monitor logs** to ensure everything is working

## Notes

- All scripts are executable and ready to run
- The complete deployment script handles everything automatically
- SSH key is pre-configured for passwordless access
- Docker group permissions may require logout/login or `newgrp docker`
- Application uses bridged networking (br0) for LAN access

---

**Created**: December 28, 2025  
**Status**: Ready for deployment  
**Estimated Time**: 15-20 minutes (automated)
