#!/bin/bash

# Claude AI Agent - Graceful Restart Script
# Restarts all services in proper order

echo "=== Claude AI Agent Restart ==="
echo "Time: $(date)"
echo

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/restart.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date): Starting graceful restart" >> "$LOG_FILE"

echo "1. Stopping PM2 processes..."
pm2 stop all
echo "$(date): PM2 processes stopped" >> "$LOG_FILE"

echo "2. Restarting Nginx..."
sudo systemctl restart nginx
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx restarted successfully"
    echo "$(date): Nginx restarted successfully" >> "$LOG_FILE"
else
    echo "❌ Nginx restart failed"
    echo "$(date): Nginx restart failed" >> "$LOG_FILE"
fi

echo "3. Starting PM2 processes..."
pm2 start all
echo "$(date): PM2 processes started" >> "$LOG_FILE"

echo "4. Waiting for services to initialize..."
sleep 10

echo "5. Health check..."
if curl -s --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ API health check passed"
    echo "$(date): API health check passed" >> "$LOG_FILE"
else
    echo "❌ API health check failed"
    echo "$(date): API health check failed" >> "$LOG_FILE"
fi

echo
echo "Restart completed at $(date)"
echo "$(date): Restart completed" >> "$LOG_FILE"

echo
echo "Run './scripts/status.sh' to check current status"
