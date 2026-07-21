-- Roda automaticamente só na primeira inicialização (data dir vazio).
-- Em instâncias já existentes, execute este arquivo manualmente uma vez:
--   docker exec -i mysql mysql -u root -p < init/01-slow-log-retention.sql
USE mysql;

CREATE EVENT IF NOT EXISTS slow_log_retention
ON SCHEDULE EVERY 1 DAY
DO
  DELETE FROM mysql.slow_log WHERE start_time < NOW() - INTERVAL 7 DAY;
