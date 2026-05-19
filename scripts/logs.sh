#!/usr/bin/env bash
set -euo pipefail
docker compose logs -f --tail=200 cbackup-web cbackup-daemon cbackup-db
