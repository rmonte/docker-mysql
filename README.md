# docker-mysql

Container MySQL 9.7 para produção, configurado para servir múltiplos projetos Laravel em um servidor compartilhado.

## Estrutura

```
docker-mysql/
├── data/                  # dados do MySQL (gerado automaticamente, não versionado)
├── backups/               # dumps diários (gerado automaticamente, não versionado)
│   ├── all/               # dump completo (--all-databases), para disaster recovery
│   └── <projeto>/         # dump individual de cada banco, para restore granular
├── init/                  # scripts SQL executados só na primeira inicialização
│   └── 01-slow-log-retention.sql
├── compose.yml
├── my.cnf
├── create-project.sh      # cria banco e usuário para um novo projeto Laravel
├── backup.sh              # gera dump completo + por banco, com verificação de integridade
└── restore.sh             # restaura um backup (completo ou de um projeto específico)
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

Gera dois tipos de dump, ambos comprimidos e com integridade verificada (`gzip -t`) antes de serem aceitos:

- `backups/all/mysql-all-YYYY-MM-DD_HH-MM-SS.sql.gz` — todos os bancos, para disaster recovery da instância inteira.
- `backups/<projeto>/<projeto>-YYYY-MM-DD_HH-MM-SS.sql.gz` — um dump por banco, para restaurar um único projeto sem afetar os demais.

O resultado é registrado em `backups/backup.log`. Backups (completos e por banco) com mais de 7 dias são removidos automaticamente. Se um dump falhar ou sair corrompido, o arquivo é descartado e o erro fica registrado no log.

**Agendar via cron (recomendado — diariamente às 3h):**
```bash
crontab -e
```
```
0 3 * * * /caminho/para/docker-mysql/backup.sh
```

**Restaurar um backup:**
```bash
./restore.sh backups/all/mysql-all-2026-01-01_03-00-00.sql.gz        # restaura tudo
./restore.sh backups/meuprojeto/meuprojeto-2026-01-01_03-00-00.sql.gz # restaura só 1 projeto
```

O script valida o `.gz`, pede confirmação explícita (`sim`) antes de sobrescrever qualquer dado e usa a senha root do `.env` automaticamente.

## Logs

Não há arquivos de log em disco (sem bind mount, sem logrotate, sem depender de permissão/UID do host):

- **Error log** → vai para stderr do container, veja com `docker logs mysql` (ou `docker logs -f mysql` para acompanhar em tempo real). A rotação é feita pelo próprio Docker (`compose.yml`, driver `json-file`, `max-size: 20m`, `max-file: 10` → até 200MB, sem exigir passo nenhum no host).
- **Slow query log** → grava em uma tabela (`log_output = TABLE` no `my.cnf`), consulte com:
  ```sql
  SELECT * FROM mysql.slow_log ORDER BY start_time DESC;
  ```
  A retenção de 7 dias é garantida por um `EVENT` do próprio MySQL (agendamento interno, sem cron/script externo) (`init/01-slow-log-retention.sql`), que roda diariamente dentro do banco e viaja junto com os dados para qualquer servidor novo. Ele é criado automaticamente só na **primeira inicialização** (data dir vazio). Em uma instância já existente, rode uma vez:
  ```bash
  docker exec -i mysql mysql -u root -p < init/01-slow-log-retention.sql
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
| `memory` | `2G` | buffer pool (1G) + overhead de conexões + margem |
| `cpus` | `2` | metade dos cores do servidor para o banco principal |

Ajuste conforme o hardware disponível e o que mais divide a RAM do host (Nginx, Redis, PHP-FPM por projeto, containers Python, etc.) — não considere só a RAM total, considere quanto sobra depois dos outros serviços.

### InnoDB (`my.cnf`)

| Parâmetro | Valor | Quando ajustar |
|---|---|---|
| `innodb_buffer_pool_size` | `1G` | Acompanhe `SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%'` antes de aumentar — só vale a pena quando o volume de dados realmente pressionar o cache |
| `innodb_buffer_pool_instances` | `1` | Só compensa dividir a partir de vários GB de buffer pool (1 instância por GB, aproximadamente) |
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
