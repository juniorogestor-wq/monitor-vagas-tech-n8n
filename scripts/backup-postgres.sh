#!/usr/bin/env bash
# Backup diario do Postgres do n8n (dump comprimido + retencao).
# Agendar no cron do VPS, ex: 0 3 * * *  /opt/monitor-vagas-tech-n8n/scripts/backup-postgres.sh
# NAO roda sozinho - precisa ser agendado.
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-/opt/monitor-vagas-tech-n8n}"
BACKUP_DIR="${BACKUP_DIR:-$COMPOSE_DIR/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
PG_SERVICE="${PG_SERVICE:-postgres}"

cd "$COMPOSE_DIR"
mkdir -p "$BACKUP_DIR"

# Carrega as credenciais do .env do proprio projeto.
set -a
# shellcheck disable=SC1091
[ -f .env ] && . ./.env
set +a
DB="${DB_POSTGRESDB_DATABASE:-n8n}"
PGUSER_="${DB_POSTGRESDB_USER:-n8n}"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/n8n-pg-$STAMP.sql.gz"

docker compose exec -T "$PG_SERVICE" pg_dump -U "$PGUSER_" "$DB" | gzip > "$OUT"
echo "Backup gerado: $OUT ($(du -h "$OUT" | cut -f1))"

# Retencao: remove dumps mais antigos que RETENTION_DAYS.
find "$BACKUP_DIR" -name 'n8n-pg-*.sql.gz' -mtime +"$RETENTION_DAYS" -delete
echo "Retencao aplicada: mantidos os ultimos $RETENTION_DAYS dias."
