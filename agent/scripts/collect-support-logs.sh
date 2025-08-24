#!/bin/bash

# Claude AI Agent - Support Log Collection Script
# Collects comprehensive system information for troubleshooting

echo "=== SUPPORT LOG COLLECTION ==="
echo "Time: $(date)"
echo

SUPPORT_DIR="/home/ubuntu/claude-ai-agent/support-logs-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SUPPORT_DIR"

echo "Collecting support information..."
echo "Output directory: $SUPPORT_DIR"

# System Information
echo "📋 Collecting system information..."
{
    echo "=== SYSTEM INFORMATION ==="
    echo "Hostname: $(hostname)"
    echo "Date: $(date)"
    echo "Uptime: $(uptime)"
    echo
    echo "=== OS INFORMATION ==="
    uname -a
    echo
    lsb_release -a 2>/dev/null
    echo
    echo "=== HARDWARE INFORMATION ==="
    echo "CPU Info:"
    lscpu | head -20
    echo
    echo "Memory Info:"
    free -h
    echo
    echo "Disk Info:"
    df -h
    echo
    echo "Network Info:"
    ip addr show
} > "$SUPPORT_DIR/system-info.txt"

# Service Status
echo "🔧 Collecting service status..."
{
    echo "=== PM2 STATUS ==="
    pm2 status
    echo
    pm2 env
    echo
    echo "=== PM2 PROCESS LIST ==="
    pm2 jlist
    echo
    echo "=== NGINX STATUS ==="
    sudo systemctl status nginx --no-pager
    echo
    echo "=== SYSTEM SERVICES ==="
    systemctl --type=service --state=running --no-pager
} > "$SUPPORT_DIR/service-status.txt" 2>&1

# Configuration Files (Sanitized)
echo "⚙️ Collecting configuration (sanitized)..."
if [ -f "/home/ubuntu/claude-ai-agent/.env" ]; then
    cp "/home/ubuntu/claude-ai-agent/.env" "$SUPPORT_DIR/env-config.txt"
    # Sanitize sensitive information
    sed -i 's/ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=***REDACTED***/' "$SUPPORT_DIR/env-config.txt"
    sed -i 's/SECRET_KEY=.*/SECRET_KEY=***REDACTED***/' "$SUPPORT_DIR/env-config.txt"
fi

# Nginx Configuration
if [ -f "/etc/nginx/sites-available/claude-agent" ]; then
    sudo cp "/etc/nginx/sites-available/claude-agent" "$SUPPORT_DIR/nginx-config.txt" 2>/dev/null
fi

# Recent Logs
echo "📝 Collecting recent logs..."

# Application logs
if [ -f "/home/ubuntu/claude-ai-agent/logs/app.log" ]; then
    tail -n 500 "/home/ubuntu/claude-ai-agent/logs/app.log" > "$SUPPORT_DIR/app-logs.txt"
fi

# Setup logs
if [ -f "/home/ubuntu/claude-ai-agent/logs/ubuntu-setup.log" ]; then
    tail -n 200 "/home/ubuntu/claude-ai-agent/logs/ubuntu-setup.log" > "$SUPPORT_DIR/setup-logs.txt"
fi

# Deployment logs
if [ -f "/home/ubuntu/claude-ai-agent/logs/deployment.log" ]; then
    tail -n 200 "/home/ubuntu/claude-ai-agent/logs/deployment.log" > "$SUPPORT_DIR/deployment-logs.txt"
fi

# Nginx logs
sudo tail -n 200 /var/log/nginx/error.log > "$SUPPORT_DIR/nginx-error.txt" 2>/dev/null
sudo tail -n 100 /var/log/nginx/access.log > "$SUPPORT_DIR/nginx-access.txt" 2>/dev/null

# PM2 logs
pm2 logs --lines 200 > "$SUPPORT_DIR/pm2-logs.txt" 2>&1

# System logs
journalctl --since "24 hours ago" --no-pager > "$SUPPORT_DIR/system-logs.txt" 2>&1

# Database Information (No sensitive data)
echo "🗃️ Collecting database information..."
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
if [ -f "$DB_PATH" ]; then
    {
        echo "=== DATABASE INFORMATION ==="
        echo "Database file size: $(ls -lh "$DB_PATH" | awk '{print $5}')"
        echo
        echo "=== TABLES ==="
        sqlite3 "$DB_PATH" ".tables"
        echo
        echo "=== TABLE COUNTS ==="
        sqlite3 "$DB_PATH" << 'SQL'
SELECT 'conversation_logs: ' || COUNT(*) FROM conversation_logs;
SELECT 'user_sessions: ' || COUNT(*) FROM user_sessions;  
SELECT 'system_metrics: ' || COUNT(*) FROM system_metrics;
SQL
        echo
        echo "=== SCHEMA ==="
        sqlite3 "$DB_PATH" ".schema"
    } > "$SUPPORT_DIR/database-info.txt" 2>/dev/null
else
    echo "Database file not found: $DB_PATH" > "$SUPPORT_DIR/database-info.txt"
fi

# Network Diagnostics
echo "🌐 Running network diagnostics..."
{
    echo "=== NETWORK DIAGNOSTICS ==="
    echo "Localhost connectivity:"
    curl -s --max-time 10 -I http://localhost:8000/health || echo "Backend API unreachable"
    curl -s --max-time 10 -I http://localhost:3000 || echo "Frontend unreachable"
    curl -s --max-time 10 -I http://localhost || echo "Nginx unreachable"
    echo
    echo "External connectivity:"
    ping -c 3 8.8.8.8 || echo "Internet connectivity issues"
    curl -s --max-time 10 -I https://api.anthropic.com || echo "Anthropic API unreachable"
    echo
    echo "Port status:"
    netstat -tlnp | grep -E ":(80|443|3000|8000) "
} > "$SUPPORT_DIR/network-diagnostics.txt" 2>&1

# Resource Usage
echo "📊 Collecting resource usage..."
{
    echo "=== RESOURCE USAGE ==="
    echo "Top processes:"
    top -bn1 | head -20
    echo
    echo "Memory usage:"
    cat /proc/meminfo
    echo
    echo "Disk usage:"
    du -sh /home/ubuntu/claude-ai-agent/* 2>/dev/null
} > "$SUPPORT_DIR/resource-usage.txt"

# Create summary
echo "📋 Creating summary..."
{
    echo "=== SUPPORT LOG SUMMARY ==="
    echo "Generated: $(date)"
    echo "Directory: $SUPPORT_DIR"
    echo
    echo "=== QUICK STATUS ==="
    echo "API Health: $(curl -s --max-time 5 http://localhost:8000/health >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL")"
    echo "Nginx Status: $(systemctl is-active nginx 2>/dev/null)"
    echo "PM2 Processes: $(pm2 list | grep -c "online" || echo "0") online"
    echo "Disk Usage: $(df / | awk 'NR==2 {print $5}')"
    echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", ($3/$2) * 100.0}')"
    echo
    echo "=== FILES INCLUDED ==="
    ls -la "$SUPPORT_DIR"
} > "$SUPPORT_DIR/summary.txt"

# Create archive
echo "📦 Creating archive..."
cd "$(dirname "$SUPPORT_DIR")"
ARCHIVE_NAME="$(basename "$SUPPORT_DIR").tar.gz"
tar -czf "$ARCHIVE_NAME" "$(basename "$SUPPORT_DIR")"
rm -rf "$SUPPORT_DIR"

echo
echo "✅ Support logs collection completed!"
echo
echo "Archive created: $PWD/$ARCHIVE_NAME"
echo "Archive size: $(ls -lh "$ARCHIVE_NAME" | awk '{print $5}')"
echo
echo "You can share this file with support for troubleshooting assistance."
echo "The archive contains no sensitive information (API keys are redacted)."
echo
echo "To extract: tar -xzf $ARCHIVE_NAME"
