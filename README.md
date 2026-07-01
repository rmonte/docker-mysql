# docker-mysql

Container MySQL 9.7 para produção, configurado para servir múltiplos projetos Laravel em um servidor compartilhado.

## Estrutura

```
docker-mysql/
├── data/               # dados do MySQL (gerado automaticamente, não versionado)
├── logs/               # slow log e error log (gerado automaticamente, não versionado)
├── backups/            # dumps diários (gerado automaticamente, não versionado)
├── compose.yml
├── my.cnf
├── create-project.sh   # cria banco e usuário para um novo projeto Laravel
└── backup.sh           # gera dump comprimido de todos os bancos
```

## Requisitos

- Docker e Docker Compose instalados
- Rede externa `infra` criada:
  ```bash
  docker network create infra
  ```

## Instalação

**1. Copiar o arquivo de variáveis de ambiente:**
```bash
cp .env.example .env
```

**2. Definir a senha root no `.env`:**
```
MYSQL_ROOT_PASSWORD=senha_forte_aqui
```

**3. Subir o container:**
```bash
docker compose up -d
```

## Criar banco para um novo projeto Laravel

```bash
./create-project.sh nome_do_projeto
```

O script solicita a senha do novo usuário via prompt e imprime as variáveis prontas para o `.env` do projeto:

```
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=nome_do_projeto
DB_USERNAME=nome_do_projeto
DB_PASSWORD=...
```

Cada projeto recebe seu próprio banco e usuário com acesso restrito apenas ao banco correspondente.

## Backup

**Executar manualmente:**
```bash
./backup.sh
```

Gera um dump comprimido em `backups/mysql-YYYY-MM-DD_HH-MM-SS.sql.gz` e registra o resultado em `backups/backup.log`. Backups com mais de 7 dias são removidos automaticamente.

**Agendar via cron (recomendado — diariamente às 3h):**
```bash
crontab -e
```
```
0 3 * * * /caminho/para/docker-mysql/backup.sh
```

**Restaurar um backup:**
```bash
gunzip < backups/mysql-2026-01-01_03-00-00.sql.gz | docker exec -i mysql mysql -u root -p
```

## Acesso remoto

A porta 3306 não é exposta publicamente. Para conectar via MySQL Workbench ou TablePlus, use um túnel SSH a partir da sua máquina local:

```bash
ssh -L 3306:127.0.0.1:3306 usuario@ip-do-servidor
```

Em seguida conecte na ferramenta apontando para `127.0.0.1:3306`.

## Configuração

### Limites de recursos (`compose.yml`)

| Parâmetro | Valor | Critério |
|---|---|---|
| `memory` | `2G` | buffer pool (512M) + overhead de conexões + margem |
| `cpus` | `2` | metade dos cores do servidor para o banco principal |

Ajuste conforme o hardware disponível.

### InnoDB (`my.cnf`)

| Parâmetro | Valor | Quando ajustar |
|---|---|---|
| `innodb_buffer_pool_size` | `512M` | Aumentar se o servidor tiver mais RAM disponível |
| `innodb_buffer_pool_instances` | `2` | 1 por cada 256M de buffer pool |
| `innodb_io_capacity` | `1000` | Reduzir para `200` se os dados estiverem em HDD |
| `innodb_io_capacity_max` | `2000` | Reduzir para `400` se os dados estiverem em HDD |

### Conexões (`my.cnf`)

| Parâmetro | Valor | Quando ajustar |
|---|---|---|
| `max_connections` | `100` | Aumentar conforme `workers_php_fpm × num_projetos` |
| `wait_timeout` | `600` | Cobre jobs e migrations longas do Laravel |
| `max_allowed_packet` | `64M` | Aumentar se houver campos BLOB muito grandes |

## Rede

Todos os containers dos projetos Laravel devem estar na rede `infra` para se comunicar com o MySQL pelo nome `mysql`.
