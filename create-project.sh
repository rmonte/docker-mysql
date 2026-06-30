#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Uso: ./create-project.sh <nome_do_projeto>"
  echo "Exemplo: ./create-project.sh meu_projeto"
  exit 1
fi

PROJECT="$1"

read -rsp "Senha para o usuario '${PROJECT}': " DB_PASSWORD
echo

if [ -z "$DB_PASSWORD" ]; then
  echo "Erro: a senha nao pode ser vazia."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/.env"

docker compose -f "${SCRIPT_DIR}/compose.yml" exec -T \
  -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql \
  mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${PROJECT}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${PROJECT}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
      CREATE TEMPORARY TABLES, LOCK TABLES, REFERENCES
      ON \`${PROJECT}\`.* TO '${PROJECT}'@'%';
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
