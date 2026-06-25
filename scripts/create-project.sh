#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Uso: ./scripts/create-project.sh <nome_do_projeto> <senha_do_usuario>"
  echo "Exemplo: ./scripts/create-project.sh meu_projeto senha_segura_aqui"
  exit 1
fi

PROJECT="$1"
DB_PASSWORD="$2"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../.env"

docker compose -f "${SCRIPT_DIR}/../compose.yml" exec -T mysql \
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${PROJECT}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${PROJECT}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${PROJECT}\`.* TO '${PROJECT}'@'%';
FLUSH PRIVILEGES;
EOF

echo "Banco '${PROJECT}' e usuario '${PROJECT}' criados com sucesso."
echo ""
echo "Variaveis para o .env do projeto Laravel:"
echo "  DB_HOST=mysql"
echo "  DB_PORT=3306"
echo "  DB_DATABASE=${PROJECT}"
echo "  DB_USERNAME=${PROJECT}"
echo "  DB_PASSWORD=${DB_PASSWORD}"
