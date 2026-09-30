#!/usr/bin/env bash
# Runs ON an App-tier instance (through SSM Run Command, as root).
# Loads seed.sql into the Flashcard Quiz database (a no-op if the API already seeded it),
# then writes a dump, including every answer you've given in the quiz, to the uploads bucket.
# Usage: db-seed-and-dump.sh <uploads-bucket> [ssm-prefix]
set -euo pipefail
BUCKET="$1"
PREFIX="${2:-/tf-bootcamp/dev}"
REGION="${AWS_REGION:-ap-southeast-1}"
export DEBIAN_FRONTEND=noninteractive

command -v mysql >/dev/null || { apt-get update -y >/dev/null; apt-get install -y mysql-client >/dev/null; }

DB_HOST=$(aws ssm get-parameter --region "$REGION" --name "$PREFIX/db/endpoint" --query Parameter.Value --output text)
SECRET_ARN=$(aws ssm get-parameter --region "$REGION" --name "$PREFIX/db/secret_arn" --query Parameter.Value --output text)

# Credentials go into a 0600 option file, never onto the command line.
CNF=$(mktemp)
chmod 600 "$CNF"
trap 'rm -f "$CNF"' EXIT
aws secretsmanager get-secret-value --region "$REGION" --secret-id "$SECRET_ARN" \
  --query SecretString --output text |
  python3 -c 'import json,sys; s=json.load(sys.stdin); print("[client]\nuser=%s\npassword=%s" % (s["username"], s["password"]))' > "$CNF"

aws s3 cp --region "$REGION" "s3://$BUCKET/seed/seed.sql" /tmp/seed.sql
mysql --defaults-extra-file="$CNF" -h "$DB_HOST" app < /tmp/seed.sql
echo "FLASHCARDS $(mysql --defaults-extra-file="$CNF" -h "$DB_HOST" -N app -e 'SELECT COUNT(*) FROM flashcards;')"
echo "ANSWERS $(mysql --defaults-extra-file="$CNF" -h "$DB_HOST" -N app -e 'SELECT COUNT(*) FROM answers;')"

mysqldump --defaults-extra-file="$CNF" -h "$DB_HOST" --single-transaction --no-tablespaces --set-gtid-purged=OFF app > /tmp/app-dump.sql
aws s3 cp --region "$REGION" /tmp/app-dump.sql "s3://$BUCKET/backups/app-dump.sql"
echo "DUMP_OK $(wc -c < /tmp/app-dump.sql) bytes"
