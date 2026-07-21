#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/.env"

BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +%F_%H-%M-%S)
RETENTION_DAYS=7
LOG_FILE="${BACKUP_DIR}/backup.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}

# Faz o dump, comprime e verifica a integridade do .gz gerado.
# Em caso de falha, remove o arquivo incompleto/corrompido.
dump_and_verify() {
  local file="$1"
  shift
  if ! docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql \
      mysqldump -u root --single-transaction --routines --events --triggers "$@" \
      | gzip > "${file}"; then
    log "ERRO: falha ao gerar dump: $(basename "${file}")"
    rm -f "${file}"
    return 1
  fi

  if ! gzip -t "${file}" 2>/dev/null; then
    log "ERRO: backup corrompido (falhou gzip -t), removido: $(basename "${file}")"
    rm -f "${file}"
    return 1
  fi
}

mkdir -p "${BACKUP_DIR}/all"

# Backup completo de todos os bancos — usado para disaster recovery da instância inteira.
ALL_FILE="${BACKUP_DIR}/all/mysql-all-${DATE}.sql.gz"
if dump_and_verify "${ALL_FILE}" --all-databases; then
  log "Backup completo criado: all/$(basename "${ALL_FILE}") ($(du -h "${ALL_FILE}" | cut -f1))"
fi

# Backup individual por banco — permite restaurar um projeto Laravel sem tocar nos demais.
DATABASES=$(docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql \
  mysql -u root -N -e "SHOW DATABASES;" | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' || true)

for DB in ${DATABASES}; do
  mkdir -p "${BACKUP_DIR}/${DB}"
  DB_FILE="${BACKUP_DIR}/${DB}/${DB}-${DATE}.sql.gz"
  if dump_and_verify "${DB_FILE}" --databases "${DB}"; then
    log "Backup criado: ${DB}/$(basename "${DB_FILE}") ($(du -h "${DB_FILE}" | cut -f1))"
  fi
done

# Retenção: remove backups (completos e por banco) com mais de RETENTION_DAYS dias.
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime "+${RETENTION_DAYS}" -delete
