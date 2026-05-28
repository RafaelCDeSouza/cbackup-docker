#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Criado .env a partir de .env.example. Edite as senhas antes de produção."
fi

docker compose up -d
docker compose ps
