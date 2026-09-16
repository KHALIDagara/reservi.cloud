#!/bin/bash
# deploy-remote.sh — run on the VPS after git pull
# This script is triggered by the GitHub Actions deploy workflow.
set -e

APP_NAME="reservi_cloud"
cd /opt/reservi.cloud

echo "=== Building Docker image ==="
docker build --build-arg RUBY_VERSION=3.4.4 -t ${APP_NAME}:latest .

echo "=== Stopping old container ==="
docker stop ${APP_NAME} 2>/dev/null || true
docker rm ${APP_NAME} 2>/dev/null || true

echo "=== Starting new container ==="
docker run -d \
  --name ${APP_NAME} \
  --network host \
  --restart unless-stopped \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e RAILS_ENV=production \
  -e RAILS_SERVE_STATIC_FILES=true \
  -e RESERVI_DATABASE_URL="postgresql://opc:reservi_prod_2026@localhost:5432/reservi_cloud_production" \
  ${APP_NAME}:latest ./bin/rails server -p 3000

echo "=== Running migrations ==="
sleep 3
docker exec -e RESERVI_DATABASE_URL="postgresql://opc:reservi_prod_2026@localhost:5432/reservi_cloud_production" ${APP_NAME} bin/rails db:migrate 2>/dev/null || echo "Migration skipped or failed — check logs"

echo "=== Verifying health ==="
sleep 2
curl -fsS http://localhost:3000/up >/dev/null 2>&1 && echo "OK: health check passed" || echo "WARN: health check failed"

echo "=== Reloading Caddy ==="
sudo systemctl reload caddy 2>/dev/null || echo "Caddy not found — skip reload"

echo "=== Deploy complete ==="