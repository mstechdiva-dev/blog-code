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
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
echo

# Process status
echo "PROCESS STATUS:"
pm2 status

echo
# Active connections
echo "ACTIVE CONNECTIONS:"
netstat -an | grep :80 | wc -l | awk '{print "HTTP: " $1}'
netstat -an | grep :8000 | wc -l | awk '{print "Backend: " $1}'
netstat -an | grep :3000 | wc -l | awk '{print "Frontend: " $1}'

echo
# Recent errors
echo "RECENT ERRORS (last 10):"
tail -n 100 /home/ubuntu/claude-ai-agent/logs/app.log | grep -i error | tail -n 10

echo
# API health check
echo "API HEALTH:"
curl -s http://localhost:8000/health | jq '.status' 2>/dev/null || echo "API not responding"

EOF

# Make executable
chmod +x /home/ubuntu/claude-ai-agent/scripts/monitor.sh

# Run monitoring
./scripts/monitor.sh
```

### Automated Performance Alerts
```bash
# Create alert script
cat > /home/ubuntu/claude-ai-agent/scripts/alert.sh << 'EOF'
#!/bin/bash

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90

# Get current usage
CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.0f\n", $(NF-2)*100}')
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f\n", ($3/$2) * 100.0}')
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//g')

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/alerts.log"

# Check CPU
if [ $CPU_USAGE -gt $CPU_THRESHOLD ]; then
    echo "$(date): HIGH CPU USAGE - $CPU_USAGE%" >> $LOG_FILE
fi

# Check Memory
if [ $MEMORY_USAGE -gt $MEMORY_THRESHOLD ]; then
    echo "$(date): HIGH MEMORY USAGE - $MEMORY_USAGE%" >> $LOG_FILE
fi

# Check Disk
if [ $DISK_USAGE -gt $DISK_THRESHOLD ]; then
    echo "$(date): HIGH DISK USAGE - $DISK_USAGE%" >> $LOG_FILE
fi

# Check API health
if ! curl -s http://localhost:8000/health > /dev/null; then
    echo "$(date): API NOT RESPONDING" >> $LOG_FILE
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
find /home/ubuntu/claude-ai-agent/backups -name "*.db" -mtime +30 -delete

echo "$(date): Cleanup process finished" >> $LOG_FILE

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/cleanup.sh
```

## API Usage Monitoring

### Cost Tracking Script
```bash
# Create cost monitoring script
cat > /home/ubuntu/claude-ai-agent/scripts/cost-monitor.sh << 'EOF'
#!/bin/bash

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"

echo "=== API Usage & Cost Monitor ==="
echo "Time: $(date)"
echo

# Current month usage
sqlite3 $DB_PATH << SQL
.mode column
.headers on

-- Daily usage this month
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as requests,
    SUM(tokens_used) as tokens,
    ROUND(SUM(tokens_used) * 0.000015, 4) as estimated_cost_usd
FROM conversation_logs 
WHERE timestamp >= date('now', 'start of month')
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- Monthly totals
SELECT 
    'THIS MONTH' as period,
    COUNT(*) as total_requests,
    SUM(tokens_used) as total_tokens,
    ROUND(SUM(tokens_used) * 0.000015, 2) as estimated_cost_usd
FROM conversation_logs 
WHERE timestamp >= date('now', 'start of month');

.quit
SQL

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/cost-monitor.sh
```

### Usage Alerts
```bash
# Create usage alert script
cat > /home/ubuntu/claude-ai-agent/scripts/usage-alert.sh << 'EOF'
#!/bin/bash

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
ALERT_LOG="/home/ubuntu/claude-ai-agent/logs/usage-alerts.log"

# Monthly token limit (adjust as needed)
MONTHLY_TOKEN_LIMIT=100000
COST_ALERT_THRESHOLD=50.00

# Get current month usage
MONTHLY_TOKENS=$(sqlite3 $DB_PATH "
SELECT COALESCE(SUM(tokens_used), 0) 
FROM conversation_logs 
WHERE timestamp >= date('now', 'start of month');
")

MONTHLY_COST=$(echo "$MONTHLY_TOKENS * 0.000015" | bc -l)

# Check token usage
if [ $MONTHLY_TOKENS -gt $MONTHLY_TOKEN_LIMIT ]; then
    echo "$(date): TOKEN LIMIT EXCEEDED - $MONTHLY_TOKENS tokens used this month" >> $ALERT_LOG
fi

# Check cost
if (( $(echo "$MONTHLY_COST > $COST_ALERT_THRESHOLD" | bc -l) )); then
    echo "$(date): COST ALERT - \$$MONTHLY_COST estimated cost this month" >> $ALERT_LOG
fi

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/usage-alert.sh
```

## Backup and Recovery

### Automated Backup Script
```bash
# Create comprehensive backup script
cat > /home/ubuntu/claude-ai-agent/scripts/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/claude-ai-agent/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/home/ubuntu/claude-ai-agent/logs/backup.log"

echo "$(date): Starting backup process" >> $LOG_FILE

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
if [ -f "/home/ubuntu/claude-ai-agent/data/agent_database.db" ]; then
    cp "/home/ubuntu/claude-ai-agent/data/agent_database.db" \
       "$BACKUP_DIR/database_$DATE.db"
    echo "$(date): Database backed up as database_$DATE.db" >> $LOG_FILE
fi

# Backup configuration
cp "/home/ubuntu/claude-ai-agent/.env" \
   "$BACKUP_DIR/env_$DATE.backup" 2>/dev/null

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

## Dashboard Creation

### Simple Status Dashboard
```bash
# Create simple status dashboard
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
echo "Dashboard refreshed every 30 seconds. Ctrl+C to exit."
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

### Email Alerts Setup (Optional)
```bash
# Install mail utilities
sudo apt-get install mailutils ssmtp

# Configure ssmtp for Gmail (example)
sudo nano /etc/ssmtp/ssmtp.conf

# Add:
# root=your-email@gmail.com
# mailhub=smtp.gmail.com:587
# AuthUser=your-email@gmail.com
# AuthPass=your-app-password
# useSTARTTLS=YES

# Create email alert script
cat > /home/ubuntu/claude-ai-agent/scripts/email-alert.sh << 'EOF'
#!/bin/bash

SUBJECT="Claude AI Agent Alert"
TO_EMAIL="your-email@example.com"
FROM_EMAIL="claude-agent@your-server.com"

# Function to send alert
send_alert() {
    local message="$1"
    echo "$message" | mail -s "$SUBJECT" -r "$FROM_EMAIL" "$TO_EMAIL"
}

# Check for critical issues
check_critical_issues() {
    # API down
    if ! curl -s http://localhost:8000/health > /dev/null; then
        send_alert "CRITICAL: API is not responding at $(date)"
    fi
    
    # High CPU usage
    CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.0f", $(NF-2)*100}')
    if [ $CPU_USAGE -gt 90 ]; then
        send_alert "WARNING: High CPU usage: ${CPU_USAGE}% at $(date)"
    fi
    
    # High memory usage
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
    if [ $MEMORY_USAGE -gt 90 ]; then
        send_alert "WARNING: High memory usage: ${MEMORY_USAGE}% at $(date)"
    fi
    
    # Disk space
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//g')
    if [ $DISK_USAGE -gt 85 ]; then
        send_alert "WARNING: High disk usage: ${DISK_USAGE}% at $(date)"
    fi
}

check_critical_issues

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/email-alert.sh

# Add to crontab for regular checks
# (crontab -l 2>/dev/null; echo "*/15 * * * * /home/ubuntu/claude-ai-agent/scripts/email-alert.sh") | crontab -
```

## Troubleshooting Common Issues

### Service Recovery Scripts
```bash
# Create service recovery script
cat > /home/ubuntu/claude-ai-agent/scripts/recover.sh << 'EOF'
#!/bin/bash

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/recovery.log"

echo "$(date): Starting recovery process" >> $LOG_FILE

# Restart PM2 processes
pm2 restart all
echo "$(date): PM2 processes restarted" >> $LOG_FILE

# Restart Nginx
sudo systemctl restart nginx
echo "$(date): Nginx restarted" >> $LOG_FILE

# Check API health
sleep 5
if curl -s http://localhost:8000/health > /dev/null; then
    echo "$(date): API recovered successfully" >> $LOG_FILE
else
    echo "$(date): API recovery failed" >> $LOG_FILE
fi

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/recover.sh
```

### System Health Check
```bash
# Comprehensive health check script
cat > /home/ubuntu/claude-ai-agent/scripts/health-check.sh << 'EOF'
#!/bin/bash

echo "=== COMPREHENSIVE HEALTH CHECK ==="
echo "Time: $(date)"
echo

# System resources check
echo "1. SYSTEM RESOURCES:"
CPU=$(top -bn1 | grep load | awk '{printf "%.1f", $(NF-2)*100}')
MEMORY=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

echo "   CPU: $CPU% $([ ${CPU%.*} -gt 80 ] && echo "⚠️ HIGH" || echo "✅ OK")"
echo "   Memory: $MEMORY% $([ ${MEMORY%.*} -gt 80 ] && echo "⚠️ HIGH" || echo "✅ OK")"
echo "   Disk: $DISK% $([ $DISK -gt 80 ] && echo "⚠️ HIGH" || echo "✅ OK")"

# Process status check
echo
echo "2. PROCESS STATUS:"
pm2 jlist | jq -r '.[] | "   \(.name): \(.pm2_env.status) \(if .pm2_env.status == "online" then "✅" else "❌" end)"' 2>/dev/null

# Network connectivity check
echo
echo "3. NETWORK CONNECTIVITY:"
if curl -s --connect-timeout 5 http://localhost:8000/health > /dev/null; then
    echo "   API Endpoint: ✅ Responding"
else
    echo "   API Endpoint: ❌ Not responding"
fi

if curl -s --connect-timeout 5 https://api.anthropic.com > /dev/null; then
    echo "   Anthropic API: ✅ Reachable"
else
    echo "   Anthropic API: ❌ Unreachable"
fi

# Database check
echo
echo "4. DATABASE STATUS:"
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
if [ -f "$DB_PATH" ] && [ -r "$DB_PATH" ]; then
    echo "   Database File: ✅ Accessible"
    TABLES=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null | wc -w)
    echo "   Tables: $TABLES $([ $TABLES -ge 4 ] && echo "✅ OK" || echo "❌ MISSING")"
else
    echo "   Database File: ❌ Not accessible"
fi

# Log file check
echo
echo "5. LOG FILES:"
APP_LOG="/home/ubuntu/claude-ai-agent/logs/app.log"
if [ -f "$APP_LOG" ] && [ -w "$APP_LOG" ]; then
    echo "   Application Log: ✅ Writable"
    RECENT_ERRORS=$(tail -n 100 "$APP_LOG" | grep -i error | wc -l)
    echo "   Recent Errors: $RECENT_ERRORS $([ $RECENT_ERRORS -gt 10 ] && echo "⚠️ HIGH" || echo "✅ OK")"
else
    echo "   Application Log: ❌ Not writable"
fi

# Configuration check
echo
echo "6. CONFIGURATION:"
ENV_FILE="/home/ubuntu/claude-ai-agent/.env"
if [ -f "$ENV_FILE" ]; then
    echo "   Environment File: ✅ Present"
    if grep -q "ANTHROPIC_API_KEY=sk-ant-" "$ENV_FILE"; then
        echo "   API Key: ✅ Configured"
    else
        echo "   API Key: ❌ Not configured"
    fi
else
    echo "   Environment File: ❌ Missing"
fi

echo
echo "=== HEALTH CHECK COMPLETE ==="

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/health-check.sh
```

## Performance Optimization Monitoring

### Performance Metrics Collection
```bash
# Create performance monitoring script
cat > /home/ubuntu/claude-ai-agent/scripts/perf-monitor.sh << 'EOF'
#!/bin/bash

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/performance.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# System metrics
CPU=$(top -bn1 | grep load | awk '{printf "%.2f", $(NF-2)*100}')
MEMORY=$(free | grep Mem | awk '{printf "%.2f", ($3/$2) * 100.0}')
DISK_IO=$(iostat -d 1 2 | tail -n +4 | awk '{print $4}' | tail -1)

# Application metrics
BACKEND_MEMORY=$(ps aux | grep "uvicorn main:app" | grep -v grep | awk '{print $6}')
FRONTEND_MEMORY=$(ps aux | grep "serve -s build" | grep -v grep | awk '{print $6}')

# Network metrics
CONNECTIONS=$(netstat -an | grep :80 | wc -l)

# API performance test
API_RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null http://localhost:8000/health 2>/dev/null || echo "0")

# Log metrics
echo "$TIMESTAMP,CPU:$CPU,Memory:$MEMORY,DiskIO:$DISK_IO,BackendMem:$BACKEND_MEMORY,FrontendMem:$FRONTEND_MEMORY,Connections:$CONNECTIONS,APIResponse:$API_RESPONSE_TIME" >> $LOG_FILE

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/perf-monitor.sh

# Run every minute
(crontab -l 2>/dev/null; echo "* * * * * /home/ubuntu/claude-ai-agent/scripts/perf-monitor.sh") | crontab -
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

echo "CLAUDE AI AGENT - WEEKLY REPORT" > $REPORT_FILE
echo "Generated: $(date)" >> $REPORT_FILE
echo "Period: $(date -d '7 days ago' +%Y-%m-%d) to $(date +%Y-%m-%d)" >> $REPORT_FILE
echo "========================================" >> $REPORT_FILE

# System uptime
echo >> $REPORT_FILE
echo "SYSTEM UPTIME:" >> $REPORT_FILE
uptime >> $REPORT_FILE

# Usage statistics
echo >> $REPORT_FILE
echo "USAGE STATISTICS:" >> $REPORT_FILE
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL >> $REPORT_FILE
SELECT 
    'Total Conversations: ' || COUNT(*)
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days');

SELECT 
    'Total Tokens Used: ' || COALESCE(SUM(tokens_used), 0)
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days');

SELECT 
    'Average Response Time: ' || ROUND(AVG(processing_time), 2) || ' seconds'
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days');

SELECT 
    'Error Rate: ' || ROUND((SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2) || '%'
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days');
SQL

# Top error types
echo >> $REPORT_FILE
echo "TOP ERROR TYPES:" >> $REPORT_FILE
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL >> $REPORT_FILE
SELECT 
    error_type || ': ' || COUNT(*) || ' occurrences'
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days') 
    AND success = 0 
    AND error_type IS NOT NULL
GROUP BY error_type
ORDER BY COUNT(*) DESC
LIMIT 5;
SQL

# Performance summary
echo >> $REPORT_FILE
echo "PERFORMANCE SUMMARY:" >> $REPORT_FILE
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
