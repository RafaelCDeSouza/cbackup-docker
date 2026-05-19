#!/usr/bin/env bash
set -euo pipefail
docker compose build --no-cache cbackup-web cbackup-daemon
docker compose up -d
