#!/bin/bash

# Claude AI Agent - Emergency Recovery Script
# Comprehensive system recovery and repair

echo "=== EMERGENCY RECOVERY SYSTEM ==="
echo "Time: $(date)"
echo

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/recovery.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date): Starting emergency recovery process" >> "$LOG_FILE"

# Function for colored output
print_status() {
    echo "🔧 $1"
    echo "$(date): $1" >> "$LOG_FILE"
}

print_success() {
    echo "✅ $1"
    echo "$(date): SUCCESS - $1" >> "$LOG_FILE"
}

print_error() {
    echo "❌ $1"
    echo "$(date): ERROR - $1" >> "$LOG_FILE"
}

print_status "Step 1: Stopping all services"
pm2 kill
sudo systemctl stop nginx
sleep 5

print_status "Step 2: Checking system resources"
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')

if [ "$DISK_USAGE" -gt 90 ]; then
    print_status "Cleaning up disk space..."
    # Clean PM2 logs
    pm2 flush
    # Clean old log files
    find /home/ubuntu/claude-ai-agent/logs -name "*.log" -mtime +7 -delete 2>/dev/null
    # Clean system logs
    sudo journalctl --vacuum-time=7d
    print_success "Disk cleanup completed"
fi

print_status "Step 3: Repairing database"
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
if [ -f "$DB_PATH" ]; then
    # Check database integrity
    if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
        print_success "Database integrity check passed"
    else
        print_error "Database corruption detected"
        # Backup corrupted database
        cp "$DB_PATH" "$DB_PATH.corrupted.$(date +%Y%m%d_%H%M%S)"
        print_status "Attempting database repair..."
        sqlite3 "$DB_PATH" ".recover" > "$DB_PATH.recovered"
        mv "$DB_PATH.recovered" "$DB_PATH"
        print_success "Database recovery attempted"
    fi
else
    print_error "Database file not found, will be recreated on startup"
fi

print_status "Step 4: Checking configuration"
if [ ! -f "/home/ubuntu/claude-ai-agent/.env" ]; then
    print_error "Environment file missing!"
    echo "Creating basic .env template..."
    cat > "/home/ubuntu/claude-ai-agent/.env" << 'EOF'
# REQUIRED: Add your Anthropic API key
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Application settings
NODE_ENV=production
PORT=8000
DATABASE_URL=sqlite:///home/ubuntu/claude-ai-agent/data/agent_database.db

# Security settings
SECRET_KEY=generate_a_secure_secret_key
CORS_ORIGINS=http://localhost:3000

# Model settings
MODEL_NAME=claude-3-sonnet-20240229
MAX_TOKENS=1000
EOF
    print_error "CRITICAL: You must edit .env and add your API key!"
else
    print_success "Environment file exists"
fi

print_status "Step 5: Restarting Nginx"
sudo systemctl start nginx
if systemctl is-active --quiet nginx; then
    print_success "Nginx started successfully"
else
    print_error "Nginx failed to start"
    # Try to restart with default config
    sudo nginx -t
fi

print_status "Step 6: Starting application services"
cd /home/ubuntu/claude-ai-agent
pm2 start backend/main.py --name claude-backend --interpreter python3
pm2 start "npm start --prefix frontend" --name claude-frontend
sleep 10

print_status "Step 7: Health verification"
API_HEALTHY=false
for i in {1..6}; do
    if curl -s --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
        API_HEALTHY=true
        break
    fi
    print_status "Waiting for API to respond... (attempt $i/6)"
    sleep 5
done

if [ "$API_HEALTHY" = true ]; then
    print_success "API health check passed"
else
    print_error "API health check failed after recovery"
    print_status "Checking PM2 process status:"
    pm2 status
    print_status "Checking recent logs:"
    pm2 logs --lines 20
fi

print_status "Step 8: Final system check"
pm2 save
sudo systemctl enable nginx

echo
echo "=== RECOVERY SUMMARY ==="
echo "Recovery completed at: $(date)"
echo "API Status: $(curl -s --max-time 5 http://localhost:8000/health >/dev/null 2>&1 && echo "✅ Healthy" || echo "❌ Unhealthy")"
echo "Nginx Status: $(systemctl is-active nginx && echo "✅ Running" || echo "❌ Stopped")"
echo "PM2 Processes:"
pm2 status

echo
echo "Next steps:"
echo "1. Check status: ./scripts/status.sh"
echo "2. Monitor system: ./scripts/monitor.sh"  
echo "3. View logs: ./scripts/logs.sh"
echo "4. If API key not configured: nano .env"

echo "$(date): Recovery process completed" >> "$LOG_FILE"
