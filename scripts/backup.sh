# BACKUP SCRIPT
# This script creates a compressed backup of the /data directory,
# suppressing error messages and displaying a progress bar.
sudo tar -czf - /data 2>/dev/null | pv -s 22G > /tmp/data-backup-$(date +%Y%m%d-%H%M%S).tar.gz

# OPTIONAL: To copy the backup to a remote server, uncomment and modify the following line:
rsync -avh --progress 10.168.1.52:/tmp/data-backup-20251226-005314.tar.gz ./

# RESTORE SCRIPT
# This script restores the /data directory from a compressed backup file,
# displaying a progress bar during the extraction.
pv /data/data-backup-20251226-005314.tar.gz | tar -xzf - --strip-components=1 data/

# ALTERNATIVE RESTORE COMMAND
# If the backup file is local, use the following command:
pv ./data-backup-20251226-005314.tar.gz | tar -xzf - --strip-components=1 data/
// ...existing code...

pv ./archive_2025-12-25.tar.gz | tar -xzf - --strip-components=1 ./

// ...existing code...

# MYSQL CREATE DATABASE
# Connect to MySQL and create database
mysql -u root -proot -e "CREATE DATABASE koala_online_tdc;"

# MYSQL RESTORE SCRIPT
# This script restores a MySQL database from a SQL dump file with progress monitoring.
pv koala_online_2025-12-11.sql | mysql -u root -proot koala_online_tdc


# Cleanup old backups - keep only the last 3 backups
cd /mnt/data/snapshot && ls -t faceid-backup-*.qcow2 | tail -n +4 | xargs -r rm -f && ls -t faceid-backup-*.xml | tail -n +4 | xargs -r rm -f