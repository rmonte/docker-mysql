#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/.env"

BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +%F_%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/mysql-${DATE}.sql.gz"
RETENTION_DAYS=7
LOG_FILE="${BACKUP_DIR}/backup.log"

mkdir -p "${BACKUP_DIR}"

docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql \
  mysqldump -u root \
    --all-databases \
    --single-transaction \
    --routines \
    --events \
    --triggers \
  | gzip > "${BACKUP_FILE}"

find "${BACKUP_DIR}" -name "mysql-*.sql.gz" -mtime +${RETENTION_DAYS} -delete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup criado: $(basename ${BACKUP_FILE}) ($(du -h ${BACKUP_FILE} | cut -f1))" >> "${LOG_FILE}"
