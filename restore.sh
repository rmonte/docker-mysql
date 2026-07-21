#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/.env"

usage() {
  echo "Uso: ./restore.sh <arquivo.sql.gz>"
  echo
  echo "Exemplos:"
  echo "  ./restore.sh backups/all/mysql-all-2026-07-21_03-00-00.sql.gz     # restaura TODOS os bancos"
  echo "  ./restore.sh backups/meuprojeto/meuprojeto-2026-07-21_03-00-00.sql.gz  # restaura só 1 banco"
  exit 1
}

[ -z "${1:-}" ] && usage
FILE="$1"

[ -f "${FILE}" ] || { echo "Erro: arquivo não encontrado: ${FILE}"; exit 1; }

if ! gzip -t "${FILE}" 2>/dev/null; then
  echo "Erro: arquivo corrompido ou não é um .gz válido: ${FILE}"
  exit 1
fi

echo "Este backup vai SOBRESCREVER dados existentes com o conteúdo de:"
echo "  ${FILE}"
read -rp "Confirma? Digite 'sim' para continuar: " CONFIRM
[ "${CONFIRM}" = "sim" ] || { echo "Cancelado."; exit 1; }

gunzip < "${FILE}" | docker exec -i -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root

echo "Restauração concluída."
