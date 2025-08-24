# Monitoring Guide

Comprehensive monitoring and maintenance guide for Claude AI Agent deployment.

## Overview

The Claude AI Agent includes built-in monitoring capabilities for system health, performance metrics, API usage tracking, and operational maintenance.

## Built-in Monitoring Features

### System Metrics
- **CPU Usage**: Real-time processor utilization
- **Memory Usage**: RAM consumption and availability
- **Disk Usage**: Storage utilization and free space
- **Network Activity**: Request rates and response times
- **Process Health**: Application uptime and status

### Application Metrics
- **Request Volume**: Requests per minute/hour/day
- **Response Times**: Average and individual response latencies
- **Error Rates**: Failed requests and error types
- **Session Activity**: Active sessions and user engagement
- **API Usage**: Token consumption and cost estimation

### Database Metrics
- **Query Performance**: Database response times
- **Storage Growth**: Database size and growth rate
- **Connection Health**: Database connectivity status
- **Backup Status**: Backup success and frequency

## Health Check Endpoints

### Primary Health Check
```bash
# Basic health status
curl http://your-server-ip:8000/health

# Response
{
  "status": "healthy",
  "api_connection": true,
  "session_active": true,
  "conversation_length": 15,
  "server_info": "CPU: 12.5%, RAM: 34.8%, Disk: 18.9%",
  "timestamp": "2024-01-01T12:00:00Z",
  "uptime": "3 days, 8:15:42"
}
```

### Detailed System Metrics
```bash
# Comprehensive metrics
curl http://your-server-ip:8000/metrics

# Response includes system, application, and API usage metrics
```

### Database Health
```bash
# Check database connectivity
curl http://your-server-ip:8000/db-health

# Response
{
  "database_connected": true,
  "total_conversations": 1250,
  "total_sessions": 89,
  "database_size_mb": 15.7,
  "last_backup": "2024-01-01T06:00:00Z"
}
```

## Log Management

### Log Locations
```bash
# Application logs
/home/ubuntu/claude-ai-agent/logs/app.log

# Nginx logs
/var/log/nginx/access.log
/var/log/nginx/error.log

# PM2 logs
~/.pm2/logs/claude-backend-out.log
~/.pm2/logs/claude-backend-error.log
~/.pm2/logs/claude-frontend-out.log
~/.pm2/logs/claude-frontend-error.log

# System logs
/var/log/syslog
```

### Log Monitoring Commands
```bash
# Real-time application logs
tail -f /home/ubuntu/claude-ai-agent/logs/app.log

# Real-time PM2 logs
pm2 logs --follow

# Search for errors
grep -i error /home/ubuntu/claude-ai-agent/logs/app.log

# View last 100 lines
tail -n 100 /home/ubuntu/claude-ai-agent/logs/app.log

# Monitor Nginx access patterns
tail -f /var/log/nginx/access.log | grep -v health
```

### Log Rotation Configuration
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/claude-agent

# Content:
/home/ubuntu/claude-ai-agent/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    copytruncate
    notifempty
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
```

## Performance Monitoring

### System Performance Script
Create a monitoring script:

```bash
# Create monitoring script
cat > /home/ubuntu/claude-ai-agent/scripts/monitor.sh << 'EOF'
#!/bin/bash

echo "=== Claude AI Agent System Monitor ==="
echo "Time: $(date)"
echo

# System resources
echo "SYSTEM RESOURCES:"
echo "CPU Usage: $(top -bn1 | grep load | awk '{printf "%.2f%%\n", $(NF-2)*100}')"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.2f%%\n", ($3/$2) * 100.0}')"
echo "Disk Usage: $(df / | awk 'NR==2 {print $5}')"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo

# Process status
echo "PROCESS STATUS:"
pm2 status

# API status
echo
echo "API STATUS:"
if curl -s --max-time 5 http://localhost:8000/health > /dev/null; then
    echo "✅ API responding"
    curl -s http://localhost:8000/health | jq '.server_info' 2>/dev/null || echo "Health info available"
else
    echo "❌ API not responding"
fi

# Database status
echo
echo "DATABASE STATUS:"
if [ -f "/home/ubuntu/claude-ai-agent/data/agent_database.db" ]; then
    DB_SIZE=$(du -h /home/ubuntu/claude-ai-agent/data/agent_database.db | cut -f1)
    echo "✅ Database online (Size: $DB_SIZE)"
else
    echo "❌ Database not found"
fi

# Recent activity
echo
echo "RECENT ACTIVITY (last hour):"
if [ -f "/home/ubuntu/claude-ai-agent/logs/app.log" ]; then
    REQUESTS=$(grep "$(date +'%Y-%m-%d %H')" /home/ubuntu/claude-ai-agent/logs/app.log | wc -l)
    echo "Requests: $REQUESTS"
    ERRORS=$(grep -i error /home/ubuntu/claude-ai-agent/logs/app.log | grep "$(date +'%Y-%m-%d %H')" | wc -l)
    echo "Errors: $ERRORS"
else
    echo "No activity logs found"
fi

echo "=================================================="

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/monitor.sh
```

## Automated Monitoring

### System Health Monitoring
```bash
# Create comprehensive health check script
cat > /home/ubuntu/claude-ai-agent/scripts/health-check.sh << 'EOF'
#!/bin/bash

echo "=== COMPREHENSIVE HEALTH CHECK ==="
echo "Time: $(date)"
echo

HEALTH_SCORE=0
TOTAL_CHECKS=10

# 1. System Resources Check
echo "1. SYSTEM RESOURCES:"
CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.1f", $(NF-2)*100}')
if (( $(echo "$CPU_USAGE < 80" | bc -l) )); then
    echo "   ✅ CPU Usage: ${CPU_USAGE}%"
    ((HEALTH_SCORE++))
else
    echo "   ⚠️ CPU Usage: ${CPU_USAGE}% (High)"
fi

MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
if (( $(echo "$MEM_USAGE < 85" | bc -l) )); then
    echo "   ✅ Memory Usage: ${MEM_USAGE}%"
    ((HEALTH_SCORE++))
else
    echo "   ⚠️ Memory Usage: ${MEM_USAGE}% (High)"
fi

DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 85 ]; then
    echo "   ✅ Disk Usage: ${DISK_USAGE}%"
    ((HEALTH_SCORE++))
else
    echo "   ⚠️ Disk Usage: ${DISK_USAGE}% (High)"
fi

# 2. Process Health Check
echo
echo "2. PROCESS STATUS:"
if pm2 list | grep -q "online"; then
    echo "   ✅ PM2 processes running"
    ((HEALTH_SCORE++))
else
    echo "   ❌ PM2 processes not running"
fi

if systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx running"
    ((HEALTH_SCORE++))
else
    echo "   ❌ Nginx not running"
fi

# 3. API Health Check
echo
echo "3. API CONNECTIVITY:"
if curl -s --max-time 5 http://localhost:8000/health > /dev/null; then
    echo "   ✅ API responding"
    ((HEALTH_SCORE++))
else
    echo "   ❌ API not responding"
fi

# 4. Database Check
echo
echo "4. DATABASE:"
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
if [ -f "$DB_PATH" ]; then
    echo "   ✅ Database file exists"
    ((HEALTH_SCORE++))
    
    if sqlite3 "$DB_PATH" "SELECT 1;" > /dev/null 2>&1; then
        echo "   ✅ Database accessible"
        ((HEALTH_SCORE++))
    else
        echo "   ❌ Database not accessible"
    fi
else
    echo "   ❌ Database file missing"
fi

# 5. Configuration Check
echo
echo "5. CONFIGURATION:"
if [ -f "/home/ubuntu/claude-ai-agent/.env" ]; then
    if grep -q "ANTHROPIC_API_KEY=sk-ant-" "/home/ubuntu/claude-ai-agent/.env"; then
        echo "   ✅ API key configured"
        ((HEALTH_SCORE++))
    else
        echo "   ⚠️ API key not properly configured"
    fi
else
    echo "   ❌ Environment file missing"
fi

# 6. Security Check
echo
echo "6. SECURITY STATUS:"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
    echo "   ✅ Firewall active"
    ((HEALTH_SCORE++))
else
    echo "   ⚠️ Firewall not active"
fi

# Calculate health percentage
HEALTH_PERCENTAGE=$(echo "scale=1; $HEALTH_SCORE * 100 / $TOTAL_CHECKS" | bc -l)

echo
echo "=== HEALTH SUMMARY ==="
echo "Health Score: $HEALTH_SCORE/$TOTAL_CHECKS (${HEALTH_PERCENTAGE}%)"

if (( $(echo "$HEALTH_PERCENTAGE >= 80" | bc -l) )); then
    echo "System Status: ✅ HEALTHY"
elif (( $(echo "$HEALTH_PERCENTAGE >= 60" | bc -l) )); then
    echo "System Status: ⚠️ WARNING"
else
    echo "System Status: ❌ CRITICAL"
fi

echo "Generated: $(date)"

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/health-check.sh
```

## Real-time Monitoring Dashboard

### Create Dashboard Script
```bash
# Create system dashboard
cat > /home/ubuntu/claude-ai-agent/scripts/dashboard.sh << 'EOF'
#!/bin/bash

clear
echo "=================================================="
echo "          CLAUDE AI AGENT DASHBOARD"
echo "=================================================="
echo "Time: $(date)"
echo

# System Status
echo "📊 SYSTEM STATUS:"
echo "  CPU: $(top -bn1 | grep load | awk '{printf "%.1f%%", $(NF-2)*100}')"
echo "  RAM: $(free | grep Mem | awk '{printf "%.1f%%", ($3/$2) * 100.0}')"
echo "  Disk: $(df -h / | awk 'NR==2 {print $5}')"
echo "  Uptime: $(uptime -p)"
echo

# Service Status  
echo "🚀 SERVICES:"
pm2 jlist | jq -r '.[] | "  \(.name): \(.pm2_env.status)"' 2>/dev/null || echo "  PM2 not available"

# API Status
echo
echo "🔌 API STATUS:"
if curl -s http://localhost:8000/health > /dev/null; then
    echo "  API: ✅ Online"
    HEALTH=$(curl -s http://localhost:8000/health | jq -r '.server_info' 2>/dev/null)
    echo "  Health: $HEALTH"
else
    echo "  API: ❌ Offline"
fi

# Database Status
echo
echo "💾 DATABASE:"
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
if [ -f "$DB_PATH" ]; then
    SIZE=$(du -h "$DB_PATH" | cut -f1)
    CONVERSATIONS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM conversation_logs;" 2>/dev/null || echo "0")
    echo "  Database: ✅ Connected ($SIZE)"
    echo "  Conversations: $CONVERSATIONS"
else
    echo "  Database: ❌ Not found"
fi

# Recent Activity
echo
echo "📈 RECENT ACTIVITY (last 24h):"
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" << SQL 2>/dev/null || echo "  Unable to query database"
.mode list
SELECT 
    '  Requests: ' || COUNT(*) || ' | Tokens: ' || COALESCE(SUM(tokens_used), 0) || ' | Avg Response: ' || ROUND(AVG(processing_time), 2) || 's'
FROM conversation_logs 
WHERE timestamp > datetime('now', '-1 day');
SQL
fi

# Error Summary
echo
echo "⚠️  RECENT ERRORS:"
ERROR_COUNT=$(tail -n 1000 /home/ubuntu/claude-ai-agent/logs/app.log 2>/dev/null | grep -i error | wc -l)
echo "  Last 1000 log entries: $ERROR_COUNT errors"

echo
echo "=================================================="
echo "Dashboard refreshed every 30 seconds. Press Ctrl+C to exit."
echo "=================================================="

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/dashboard.sh
```

### Real-time Dashboard
```bash
# Create real-time monitoring dashboard
cat > /home/ubuntu/claude-ai-agent/scripts/live-dashboard.sh << 'EOF'
#!/bin/bash

# Function to display dashboard
show_dashboard() {
    /home/ubuntu/claude-ai-agent/scripts/dashboard.sh
}

# Function to handle cleanup on exit
cleanup() {
    echo
    echo "Dashboard stopped."
    exit 0
}

# Set trap for clean exit
trap cleanup INT TERM

# Main loop
while true; do
    show_dashboard
    sleep 30
done

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/live-dashboard.sh

# Usage: ./scripts/live-dashboard.sh
```

## Alerting System

### Basic Alert Script
```bash
# Create basic alerting script
cat > /home/ubuntu/claude-ai-agent/scripts/alert.sh << 'EOF'
#!/bin/bash

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/alerts.log"

# Function to log alert
log_alert() {
    local message="$1"
    echo "$(date): ALERT - $message" >> $LOG_FILE
    echo "ALERT: $message"
}

# Check system resources
CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.0f", $(NF-2)*100}')
if [ "$CPU_USAGE" -gt 90 ]; then
    log_alert "HIGH CPU USAGE: ${CPU_USAGE}%"
fi

MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
if [ "$MEMORY_USAGE" -gt 90 ]; then
    log_alert "HIGH MEMORY USAGE: ${MEMORY_USAGE}%"
fi

DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    log_alert "HIGH DISK USAGE: ${DISK_USAGE}%"
fi

# Check API status
if ! curl -s --max-time 5 http://localhost:8000/health > /dev/null; then
    log_alert "API NOT RESPONDING"
fi

# Check database
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
if [ ! -f "$DB_PATH" ]; then
    log_alert "DATABASE FILE MISSING"
fi

# Check for recent errors
ERROR_COUNT=$(tail -n 100 /home/ubuntu/claude-ai-agent/logs/app.log 2>/dev/null | grep -i error | wc -l)
if [ "$ERROR_COUNT" -gt 10 ]; then
    log_alert "HIGH ERROR RATE: $ERROR_COUNT errors in last 100 log entries"
fi

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/alert.sh
```

### Cron Jobs for Monitoring
```bash
# Edit crontab
crontab -e

# Add monitoring jobs
# Check system every 5 minutes
*/5 * * * * /home/ubuntu/claude-ai-agent/scripts/alert.sh

# Generate daily report at 6 AM
0 6 * * * /home/ubuntu/claude-ai-agent/scripts/daily-report.sh

# Clean old logs weekly
0 2 * * 0 find /home/ubuntu/claude-ai-agent/logs -name "*.log" -mtime +30 -delete
```

## Database Monitoring

### Database Performance Script
```bash
# Create database monitoring script
cat > /home/ubuntu/claude-ai-agent/scripts/db-monitor.sh << 'EOF'
#!/bin/bash

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
echo "=== Database Monitor ==="
echo "Time: $(date)"
echo

if [ -f "$DB_PATH" ]; then
    echo "Database Size: $(du -h $DB_PATH | cut -f1)"
    echo "Database exists: Yes"
    
    # Table statistics
    echo
    echo "TABLE STATISTICS:"
    sqlite3 $DB_PATH << SQL
.mode column
.headers on

SELECT 'conversation_logs' as table_name, COUNT(*) as record_count
FROM conversation_logs
UNION ALL
SELECT 'user_sessions', COUNT(*) FROM user_sessions
UNION ALL  
SELECT 'system_metrics', COUNT(*) FROM system_metrics
UNION ALL
SELECT 'api_usage', COUNT(*) FROM api_usage;

.quit
SQL

    # Recent activity
    echo
    echo "RECENT ACTIVITY (last 24 hours):"
    sqlite3 $DB_PATH << SQL
.mode column
.headers on

SELECT 
    DATE(timestamp) as date,
    COUNT(*) as conversations,
    SUM(tokens_used) as total_tokens,
    AVG(processing_time) as avg_response_time
FROM conversation_logs 
WHERE timestamp > datetime('now', '-1 day')
GROUP BY DATE(timestamp)
ORDER BY date DESC;

.quit
SQL

else
    echo "Database not found at $DB_PATH"
fi

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/db-monitor.sh
```

### Database Cleanup Script
```bash
# Create cleanup script
cat > /home/ubuntu/claude-ai-agent/scripts/cleanup.sh << 'EOF'
#!/bin/bash

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
BACKUP_DIR="/home/ubuntu/claude-ai-agent/backups"
LOG_FILE="/home/ubuntu/claude-ai-agent/logs/cleanup.log"

echo "$(date): Starting cleanup process" >> $LOG_FILE

# Create backup before cleanup
if [ -f "$DB_PATH" ]; then
    BACKUP_NAME="database_backup_$(date +%Y%m%d_%H%M%S).db"
    cp "$DB_PATH" "$BACKUP_DIR/$BACKUP_NAME"
    echo "$(date): Created backup: $BACKUP_NAME" >> $LOG_FILE
    
    # Clean old metrics (keep last 30 days)
    sqlite3 $DB_PATH << SQL
DELETE FROM system_metrics 
WHERE timestamp < datetime('now', '-30 days');

DELETE FROM api_usage 
WHERE date < datetime('now', '-90 days');

VACUUM;
SQL
    
    echo "$(date): Database cleanup completed" >> $LOG_FILE
fi

# Clean old log files
find /home/ubuntu/claude-ai-agent/logs -name "*.log.*" -mtime +7 -delete
find /home/ubuntu/claude-ai-agent/backups -name "database_backup_*.db" -mtime +30 -delete

echo "$(date): Cleanup process completed" >> $LOG_FILE

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/cleanup.sh
```

## Cost Monitoring

### API Usage Tracking
```bash
# Create cost monitoring script
cat > /home/ubuntu/claude-ai-agent/scripts/cost-monitor.sh << 'EOF'
#!/bin/bash

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
echo "=== API Usage & Cost Monitor ==="
echo "Time: $(date)"
echo

if [ -f "$DB_PATH" ]; then
    # Today's usage
    echo "TODAY'S USAGE:"
    sqlite3 $DB_PATH << SQL
.mode column
.headers on

SELECT 
    COUNT(*) as requests,
    SUM(tokens_used) as total_tokens,
    AVG(tokens_used) as avg_tokens,
    ROUND(SUM(tokens_used) * 0.000003, 4) as estimated_cost_usd
FROM conversation_logs 
WHERE DATE(timestamp) = DATE('now');

.quit
SQL

    echo
    echo "WEEKLY USAGE:"
    sqlite3 $DB_PATH << SQL
.mode column
.headers on

SELECT 
    DATE(timestamp) as date,
    COUNT(*) as requests,
    SUM(tokens_used) as tokens,
    ROUND(SUM(tokens_used) * 0.000003, 4) as cost_usd
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days')
GROUP BY DATE(timestamp)
ORDER BY date DESC;

.quit
SQL

    echo
    echo "MONTHLY SUMMARY:"
    sqlite3 $DB_PATH << SQL
.mode column
.headers on

SELECT 
    COUNT(*) as total_requests,
    SUM(tokens_used) as total_tokens,
    ROUND(SUM(tokens_used) * 0.000003, 2) as estimated_monthly_cost_usd,
    MIN(timestamp) as first_request,
    MAX(timestamp) as last_request
FROM conversation_logs 
WHERE timestamp > datetime('now', '-30 days');

.quit
SQL

else
    echo "Database not found at $DB_PATH"
fi

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/cost-monitor.sh
```

## Backup Monitoring

### Automated Backup Script
```bash
# Create automated backup script
cat > /home/ubuntu/claude-ai-agent/scripts/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/claude-ai-agent/backups"
LOG_FILE="/home/ubuntu/claude-ai-agent/logs/backup.log"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "$(date): Starting backup process" >> $LOG_FILE

# Backup database
if [ -f "/home/ubuntu/claude-ai-agent/data/agent_database.db" ]; then
    cp "/home/ubuntu/claude-ai-agent/data/agent_database.db" "$BACKUP_DIR/database_$DATE.db"
    echo "$(date): Database backup created: database_$DATE.db" >> $LOG_FILE
fi

# Backup configuration
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" \
    /home/ubuntu/claude-ai-agent/.env \
    /etc/nginx/sites-available/claude-agent 2>/dev/null

# Backup logs (compress)
tar -czf "$BACKUP_DIR/logs_$DATE.tar.gz" \
    /home/ubuntu/claude-ai-agent/logs/*.log 2>/dev/null

# Backup application code
tar -czf "$BACKUP_DIR/code_$DATE.tar.gz" \
    --exclude="node_modules" \
    --exclude="venv" \
    --exclude="*.pyc" \
    --exclude="logs" \
    --exclude="data" \
    /home/ubuntu/claude-ai-agent/ 2>/dev/null

# Clean old backups (keep 30 days)
find $BACKUP_DIR -name "*.db" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.backup" -mtime +30 -delete

echo "$(date): Backup process completed" >> $LOG_FILE

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/backup.sh

# Schedule daily backups
(crontab -l 2>/dev/null; echo "0 3 * * * /home/ubuntu/claude-ai-agent/scripts/backup.sh") | crontab -
```

## Maintenance Schedules

### Daily Maintenance Tasks
```bash
# Create daily maintenance script
cat > /home/ubuntu/claude-ai-agent/scripts/daily-maintenance.sh << 'EOF'
#!/bin/bash

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/maintenance.log"
echo "$(date): Starting daily maintenance" >> $LOG_FILE

# Update system packages (security updates only)
sudo apt-get update -qq
sudo apt-get upgrade -y --only-upgrade $(apt list --upgradable 2>/dev/null | grep -i security | cut -d/ -f1)

# Clean temporary files
sudo apt-get autoremove -y
sudo apt-get autoclean

# Rotate logs if needed
if [ $(du /home/ubuntu/claude-ai-agent/logs/app.log | cut -f1) -gt 100000 ]; then
    cp /home/ubuntu/claude-ai-agent/logs/app.log /home/ubuntu/claude-ai-agent/logs/app.log.$(date +%Y%m%d)
    echo "" > /home/ubuntu/claude-ai-agent/logs/app.log
fi

# Database maintenance
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db "VACUUM;"

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "$(date): WARNING - Disk usage at ${DISK_USAGE}%" >> $LOG_FILE
fi

echo "$(date): Daily maintenance completed" >> $LOG_FILE

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/daily-maintenance.sh

# Schedule for 2 AM daily
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/claude-ai-agent/scripts/daily-maintenance.sh") | crontab -
```

### Weekly Reports
```bash
# Create weekly report script
cat > /home/ubuntu/claude-ai-agent/scripts/weekly-report.sh << 'EOF'
#!/bin/bash

REPORT_FILE="/home/ubuntu/claude-ai-agent/reports/weekly_$(date +%Y%m%d).txt"
mkdir -p /home/ubuntu/claude-ai-agent/reports

echo "=== CLAUDE AI AGENT WEEKLY REPORT ===" > $REPORT_FILE
echo "Report Date: $(date)" >> $REPORT_FILE
echo "Report Period: Last 7 days" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# System Summary
echo "SYSTEM SUMMARY:" >> $REPORT_FILE
echo "Uptime: $(uptime -p)" >> $REPORT_FILE
echo "Current Load: $(uptime | awk -F'load average:' '{print $2}')" >> $REPORT_FILE
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Database Statistics
if [ -f "/home/ubuntu/claude-ai-agent/data/agent_database.db" ]; then
    echo "DATABASE STATISTICS:" >> $REPORT_FILE
    sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL >> $REPORT_FILE
SELECT 'Total Conversations: ' || COUNT(*) FROM conversation_logs;
SELECT 'This Week: ' || COUNT(*) FROM conversation_logs WHERE timestamp > datetime('now', '-7 days');
SELECT 'Total Sessions: ' || COUNT(*) FROM user_sessions;
SELECT 'Active Sessions: ' || COUNT(*) FROM user_sessions WHERE last_activity > datetime('now', '-7 days');
SQL
    echo "" >> $REPORT_FILE
fi

# Performance Metrics
echo "PERFORMANCE METRICS:" >> $REPORT_FILE
echo "Average CPU Usage: $(tail -n 10080 /home/ubuntu/claude-ai-agent/logs/performance.log 2>/dev/null | awk -F',' '{print $2}' | awk -F':' '{sum+=$2; count++} END {printf "%.2f%%\n", sum/count}' 2>/dev/null || echo "N/A")" >> $REPORT_FILE

echo >> $REPORT_FILE
echo "Report saved to: $REPORT_FILE"

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/weekly-report.sh

# Schedule for Sunday at 6 AM
(crontab -l 2>/dev/null; echo "0 6 * * 0 /home/ubuntu/claude-ai-agent/scripts/weekly-report.sh") | crontab -
```

## Quick Reference Commands

### Essential Monitoring Commands
```bash
# Quick system status
./scripts/monitor.sh

# Real-time dashboard
./scripts/live-dashboard.sh

# Health check
./scripts/health-check.sh

# View recent logs
tail -f /home/ubuntu/claude-ai-agent/logs/app.log

# Check PM2 processes
pm2 status
pm2 logs

# Check API health
curl http://localhost:8000/health

# Database quick stats
./scripts/db-monitor.sh

# Cost monitoring
./scripts/cost-monitor.sh

# Create backup
./scripts/backup.sh

# Recovery from issues
./scripts/recover.sh
```

### Log Analysis Commands
```bash
# Search for errors
grep -i error /home/ubuntu/claude-ai-agent/logs/app.log | tail -10

# Count requests by hour
grep "$(date +%Y-%m-%d)" /var/log/nginx/access.log | cut -d[ -f2 | cut -d] -f1 | awk '{print $2}' | cut -d: -f1-2 | sort | uniq -c

# Monitor real-time API calls
tail -f /var/log/nginx/access.log | grep -v health

# Check for API errors
grep -i "anthropic\|claude\|api" /home/ubuntu/claude-ai-agent/logs/app.log | tail -20
```

This monitoring setup provides comprehensive oversight of your Claude AI Agent deployment, ensuring optimal performance and quick issue resolution.
