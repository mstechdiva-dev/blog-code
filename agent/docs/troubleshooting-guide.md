# Troubleshooting Guide

Comprehensive troubleshooting guide for resolving common issues with Claude AI Agent deployment.

## Quick Diagnosis

### First Steps for Any Issue
```bash
# 1. Check overall system health
./scripts/health-check.sh

# 2. Check service status
pm2 status

# 3. Check recent logs for errors
tail -n 50 /home/ubuntu/claude-ai-agent/logs/app.log | grep -i error

# 4. Test API connectivity
curl http://localhost:8000/health
```

## Common Issues and Solutions

### 1. API Not Responding

**Symptoms:**
- Browser shows "connection refused" or timeout
- `curl http://localhost:8000/health` fails
- PM2 shows backend as stopped or errored

**Diagnosis:**
```bash
# Check if backend process is running
pm2 status

# Check backend logs
pm2 logs claude-backend

# Check port usage
sudo netstat -tlnp | grep :8000
```

**Solutions:**

**A. Restart Backend Service:**
```bash
pm2 restart claude-backend

# If that fails, stop and start
pm2 stop claude-backend
pm2 start claude-backend
```

**B. Check Environment Configuration:**
```bash
# Verify .env file exists and is readable
ls -la /home/ubuntu/claude-ai-agent/.env

# Check API key is set
grep ANTHROPIC_API_KEY /home/ubuntu/claude-ai-agent/.env

# Test API key validity
cd /home/ubuntu/claude-ai-agent/backend
source venv/bin/activate
python -c "
import anthropic
import os
from dotenv import load_dotenv
load_dotenv()
try:
    client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
    response = client.messages.create(
        model='claude-3-sonnet-20240229',
        max_tokens=10,
        messages=[{'role': 'user', 'content': 'test'}]
    )
    print('✅ API key is valid')
except Exception as e:
    print(f'❌ API key error: {e}')
"
```

**C. Port Conflict Resolution:**
```bash
# Check what's using port 8000
sudo lsof -i :8000

# Kill conflicting process if needed
sudo kill -9 PID_NUMBER

# Restart backend
pm2 restart claude-backend
```

### 2. Frontend Not Loading

**Symptoms:**
- Browser shows blank page or loading indefinitely
- 502 Bad Gateway error
- Frontend files not found

**Diagnosis:**
```bash
# Check frontend process
pm2 status | grep claude-frontend

# Check frontend logs
pm2 logs claude-frontend

# Check if build exists
ls -la /home/ubuntu/claude-ai-agent/frontend/build/

# Test direct frontend access
curl http://localhost:3000
```

**Solutions:**

**A. Rebuild and Restart Frontend:**
```bash
cd /home/ubuntu/claude-ai-agent/frontend

# Install dependencies
npm install

# Rebuild application
npm run build

# Restart frontend service
pm2 restart claude-frontend
```

**B. Fix Build Issues:**
```bash
# Check Node.js version
node --version  # Should be 16+ for React 18

# Clear cache and rebuild
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
npm run build
```

### 3. Database Connection Issues

**Symptoms:**
- Error messages about database connection
- Cannot save conversations
- Metrics not updating

**Diagnosis:**
```bash
# Check if database file exists
ls -la /home/ubuntu/claude-ai-agent/data/agent_database.db

# Check database file permissions
ls -la /home/ubuntu/claude-ai-agent/data/

# Test database connectivity
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db ".tables"
```

**Solutions:**

**A. Fix Database Permissions:**
```bash
# Ensure proper ownership
sudo chown -R ubuntu:ubuntu /home/ubuntu/claude-ai-agent/data/

# Set proper permissions
chmod 755 /home/ubuntu/claude-ai-agent/data/
chmod 664 /home/ubuntu/claude-ai-agent/data/agent_database.db
```

**B. Recreate Database:**
```bash
cd /home/ubuntu/claude-ai-agent/backend
source venv/bin/activate

# Backup existing database (if it exists)
cp /home/ubuntu/claude-ai-agent/data/agent_database.db \
   /home/ubuntu/claude-ai-agent/backups/database_backup_$(date +%Y%m%d).db

# Recreate database
python -c "
from database import init_database
init_database()
print('✅ Database initialized')
"
```

### 4. Nginx Configuration Problems

**Symptoms:**
- 502 Bad Gateway errors
- Cannot access site from browser
- Nginx won't start

**Diagnosis:**
```bash
# Check Nginx status
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

**Solutions:**

**A. Fix Configuration Errors:**
```bash
# Test configuration syntax
sudo nginx -t

# If errors found, edit configuration
sudo nano /etc/nginx/sites-available/claude-agent

# Reload configuration
sudo nginx -s reload
```

**B. Restart Nginx:**
```bash
sudo systemctl stop nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

**C. Reset Nginx Configuration:**
```bash
# Backup current configuration
sudo cp /etc/nginx/sites-available/claude-agent \
       /etc/nginx/sites-available/claude-agent.backup

# Create fresh configuration
sudo nano /etc/nginx/sites-available/claude-agent

# Paste working configuration:
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /api {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Test and reload
sudo nginx -t && sudo nginx -s reload
```

### 5. High Memory Usage

**Symptoms:**
- System running slowly
- Out of memory errors
- Processes being killed

**Diagnosis:**
```bash
# Check memory usage
free -h

# Check which processes use most memory
ps aux --sort=-%mem | head -10

# Check for memory leaks
pm2 monit
```

**Solutions:**

**A. Restart High-Memory Processes:**
```bash
pm2 restart all
```

**B. Increase Swap Space:**
```bash
# Check current swap
swapon --show

# Create swap file if none exists
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**C. Optimize Memory Settings:**
```bash
# Configure PM2 with memory limits
pm2 delete all

pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" \
    --name claude-backend \
    --max-memory-restart 500M

pm2 start "npx serve -s build -l 3000" \
    --name claude-frontend \
    --max-memory-restart 200M

pm2 save
```

### 6. SSL/HTTPS Issues

**Symptoms:**
- SSL certificate warnings
- Mixed content errors
- HTTPS not working

**Diagnosis:**
```bash
# Check SSL certificate
openssl x509 -in /path/to/certificate.crt -text -noout

# Check SSL configuration
sudo nginx -t

# Test SSL connectivity
curl -I https://your-domain.com
```

**Solutions:**

**A. Generate Self-Signed Certificate (Development):**
```bash
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx-selfsigned.key \
    -out /etc/nginx/ssl/nginx-selfsigned.crt

# Update Nginx configuration for SSL
sudo nano /etc/nginx/sites-available/claude-agent
```

**B. Use Let's Encrypt (Production):**
```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

### 7. API Rate Limiting Issues

**Symptoms:**
- "Rate limit exceeded" errors
- Slow API responses
- 429 HTTP status codes

**Diagnosis:**
```bash
# Check recent API errors
grep -i "rate limit" /home/ubuntu/claude-ai-agent/logs/app.log | tail -10

# Check API usage
./scripts/cost-monitor.sh

# Check Anthropic API status
curl -s https://status.anthropic.com/api/v2/status.json | jq '.status.description'
```

**Solutions:**

**A. Implement Request Queuing:**
```bash
# Edit backend configuration to add delays
nano /home/ubuntu/claude-ai-agent/.env

# Add or adjust:
RATE_LIMIT_REQUESTS=50
RATE_LIMIT_WINDOW=3600
```

**B. Monitor and Optimize Usage:**
```bash
# Check token usage patterns
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as requests,
    SUM(tokens_used) as tokens,
    AVG(tokens_used) as avg_tokens
FROM conversation_logs 
WHERE timestamp > datetime('now', '-7 days')
GROUP BY DATE(timestamp)
ORDER BY date DESC;
SQL
```

### 8. Disk Space Issues

**Symptoms:**
- "No space left on device" errors
- Application crashes
- Cannot write logs or save data

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find large files
du -h /home/ubuntu/claude-ai-agent/ | sort -hr | head -20

# Check log file sizes
ls -lah /home/ubuntu/claude-ai-agent/logs/
ls -lah /var/log/nginx/
```

**Solutions:**

**A. Clean Up Log Files:**
```bash
# Compress old logs
gzip /home/ubuntu/claude-ai-agent/logs/*.log.202*

# Clear Nginx logs
sudo truncate -s 0 /var/log/nginx/access.log
sudo truncate -s 0 /var/log/nginx/error.log

# Clean PM2 logs
pm2 flush
```

**B. Clean System Files:**
```bash
# Clean package cache
sudo apt-get clean
sudo apt-get autoremove

# Clean temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
```

**C. Set Up Log Rotation:**
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/claude-agent

# Add:
/home/ubuntu/claude-ai-agent/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
}
```

### 9. Performance Issues

**Symptoms:**
- Slow response times
- High CPU usage
- Timeouts

**Diagnosis:**
```bash
# Check system load
top -bn1 | head -20

# Check response times
curl -w "%{time_total}\n" -o /dev/null -s http://localhost:8000/health

# Check database performance
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL
.timer on
SELECT COUNT(*) FROM conversation_logs;
SQL
```

**Solutions:**

**A. Optimize Database:**
```bash
# Vacuum database
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db "VACUUM;"

# Add indexes if missing
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL
CREATE INDEX IF NOT EXISTS idx_conversation_session ON conversation_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_conversation_timestamp ON conversation_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_session_activity ON user_sessions(last_activity);
SQL
```

**B. Increase System Resources:**
```bash
# Upgrade Lightsail instance to higher plan
# Go to AWS Lightsail console -> Instance -> Upgrade

# Or optimize current resources
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**C. Optimize Application Settings:**
```bash
# Reduce token limits to improve speed
nano /home/ubuntu/claude-ai-agent/.env

# Adjust:
MAX_TOKENS=500  # Reduce from 1000 for faster responses
```

## Error Code Reference

### HTTP Error Codes

**500 Internal Server Error**
```bash
# Check backend logs for Python errors
pm2 logs claude-backend | tail -20

# Common causes:
# - Missing environment variables
# - Database connection issues
# - API key problems
```

**502 Bad Gateway**
```bash
# Check if backend is running
curl http://localhost:8000/health

# Check Nginx configuration
sudo nginx -t

# Restart services
pm2 restart claude-backend
sudo systemctl restart nginx
```

**503 Service Unavailable**
```bash
# Usually indicates overload or maintenance
# Check system resources
free -h
top -bn1

# Check for rate limiting
grep -i "rate limit" /home/ubuntu/claude-ai-agent/logs/app.log
```

### Application Error Types

**connection_error**
- **Cause**: Cannot reach Anthropic API
- **Solution**: Check internet connectivity, API status
- **Command**: `curl -s https://api.anthropic.com`

**auth_error**
- **Cause**: Invalid or missing API key
- **Solution**: Verify API key in .env file
- **Command**: `grep ANTHROPIC_API_KEY /home/ubuntu/claude-ai-agent/.env`

**rate_limit**
- **Cause**: Too many API requests
- **Solution**: Implement delays, reduce usage
- **Command**: `./scripts/cost-monitor.sh`

**general_error**
- **Cause**: Unexpected application error
- **Solution**: Check logs, restart services
- **Command**: `pm2 logs claude-backend`

## Emergency Recovery Procedures

### Complete System Recovery
```bash
#!/bin/bash
# Emergency recovery script

echo "=== EMERGENCY RECOVERY PROCEDURE ==="

# 1. Stop all services
pm2 stop all
sudo systemctl stop nginx

# 2. Check system resources
echo "Checking system resources..."
df -h
free -h

# 3. Clean up if low on space
if [ $(df / | awk 'NR==2 {print $5}' | sed 's/%//') -gt 90 ]; then
    echo "Cleaning up disk space..."
    sudo apt-get clean
    pm2 flush
    find /home/ubuntu/claude-ai-agent/logs -name "*.log.*" -delete
fi

# 4. Reset database if corrupted
if ! sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db ".tables" &>/dev/null; then
    echo "Database appears corrupted, backing up and recreating..."
    mv /home/ubuntu/claude-ai-agent/data/agent_database.db \
       /home/ubuntu/claude-ai-agent/backups/corrupted_$(date +%Y%m%d_%H%M%S).db
    
    cd /home/ubuntu/claude-ai-agent/backend
    source venv/bin/activate
    python -c "from database import init_database; init_database()"
fi

# 5. Restart services
echo "Restarting services..."
pm2 start all
sudo systemctl start nginx

# 6. Wait and test
sleep 10
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Recovery successful - API responding"
else
    echo "❌ Recovery failed - API not responding"
fi

echo "=== RECOVERY PROCEDURE COMPLETE ==="
```

### Database Recovery
```bash
# Create database recovery script
cat > /home/ubuntu/claude-ai-agent/scripts/db-recovery.sh << 'EOF'
#!/bin/bash

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
BACKUP_DIR="/home/ubuntu/claude-ai-agent/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== DATABASE RECOVERY ==="

# 1. Check database integrity
echo "Checking database integrity..."
if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
    echo "✅ Database integrity OK"
else
    echo "❌ Database corruption detected"
    
    # 2. Create backup of corrupted database
    echo "Creating backup of corrupted database..."
    cp "$DB_PATH" "$BACKUP_DIR/corrupted_$TIMESTAMP.db"
    
    # 3. Attempt repair
    echo "Attempting database repair..."
    sqlite3 "$DB_PATH" << SQL
.recover /tmp/recovered_database.db
SQL
    
    if [ -f "/tmp/recovered_database.db" ]; then
        mv "/tmp/recovered_database.db" "$DB_PATH"
        echo "✅ Database recovery attempted"
    else
        # 4. Recreate from scratch if repair fails
        echo "Repair failed, recreating database..."
        rm "$DB_PATH"
        cd /home/ubuntu/claude-ai-agent/backend
        source venv/bin/activate
        python -c "from database import init_database; init_database()"
        echo "✅ Database recreated"
    fi
fi

# 5. Set proper permissions
chmod 664 "$DB_PATH"
chown ubuntu:ubuntu "$DB_PATH"

echo "=== DATABASE RECOVERY COMPLETE ==="
EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/db-recovery.sh
```

## Advanced Troubleshooting

### Network Connectivity Issues
```bash
# Test network connectivity
ping -c 4 8.8.8.8

# Test DNS resolution
nslookup api.anthropic.com

# Check firewall status
sudo ufw status

# Test specific ports
telnet localhost 8000
telnet localhost 3000

# Check routing
traceroute api.anthropic.com
```

### Memory Leak Detection
```bash
# Monitor memory usage over time
cat > /home/ubuntu/claude-ai-agent/scripts/memory-monitor.sh << 'EOF'
#!/bin/bash

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/memory-monitor.log"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    BACKEND_MEM=$(ps aux | grep "uvicorn main:app" | grep -v grep | awk '{print $6}')
    FRONTEND_MEM=$(ps aux | grep "serve -s build" | grep -v grep | awk '{print $6}')
    TOTAL_MEM=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
    
    echo "$TIMESTAMP,Backend:$BACKEND_MEM,Frontend:$FRONTEND_MEM,Total:$TOTAL_MEM%" >> $LOG_FILE
    sleep 60
done
EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/memory-monitor.sh

# Run in background
nohup ./scripts/memory-monitor.sh &
```

### Process Debugging
```bash
# Debug hanging processes
ps aux | grep claude

# Check process details
sudo lsof -p PID_NUMBER

# Monitor system calls
sudo strace -p PID_NUMBER

# Check for zombie processes
ps aux | grep defunct
```

## Preventive Maintenance

### Automated Health Monitoring
```bash
# Create comprehensive health monitor
cat > /home/ubuntu/claude-ai-agent/scripts/health-monitor.sh << 'EOF'
#!/bin/bash

ALERT_LOG="/home/ubuntu/claude-ai-agent/logs/health-alerts.log"
THRESHOLD_CPU=80
THRESHOLD_MEMORY=85
THRESHOLD_DISK=90

# Function to log alerts
log_alert() {
    echo "$(date): $1" >> $ALERT_LOG
}

# Check CPU
CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.0f", $(NF-2)*100}')
if [ $CPU_USAGE -gt $THRESHOLD_CPU ]; then
    log_alert "HIGH CPU: ${CPU_USAGE}%"
fi

# Check Memory
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
if [ $MEMORY_USAGE -gt $THRESHOLD_MEMORY ]; then
    log_alert "HIGH MEMORY: ${MEMORY_USAGE}%"
fi

# Check Disk
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt $THRESHOLD_DISK ]; then
    log_alert "HIGH DISK: ${DISK_USAGE}%"
fi

# Check API Health
if ! curl -s --max-time 10 http://localhost:8000/health > /dev/null; then
    log_alert "API NOT RESPONDING"
    # Attempt automatic recovery
    pm2 restart claude-backend
    sleep 5
    if curl -s --max-time 10 http://localhost:8000/health > /dev/null; then
        log_alert "API RECOVERED AUTOMATICALLY"
    else
        log_alert "API RECOVERY FAILED"
    fi
fi

# Check Database
if ! sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db ".tables" &>/dev/null; then
    log_alert "DATABASE CONNECTIVITY ISSUE"
fi

# Check Error Rates
ERROR_COUNT=$(tail -n 100 /home/ubuntu/claude-ai-agent/logs/app.log | grep -i error | wc -l)
if [ $ERROR_COUNT -gt 10 ]; then
    log_alert "HIGH ERROR RATE: $ERROR_COUNT errors in last 100 log entries"
fi

EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/health-monitor.sh

# Run every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/ubuntu/claude-ai-agent/scripts/health-monitor.sh") | crontab -
```

### System Hardening Checklist
```bash
# Create hardening script
cat > /home/ubuntu/claude-ai-agent/scripts/harden-system.sh << 'EOF'
#!/bin/bash

echo "=== SYSTEM HARDENING ==="

# 1. Update system
sudo apt-get update
sudo apt-get upgrade -y

# 2. Configure firewall
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 3. Secure SSH (if not already done)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 4. Install fail2ban
sudo apt-get install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 5. Secure file permissions
chmod 600 /home/ubuntu/claude-ai-agent/.env
chmod 755 /home/ubuntu/claude-ai-agent/scripts/*.sh
sudo chown -R ubuntu:ubuntu /home/ubuntu/claude-ai-agent/

# 6. Configure automatic security updates
sudo apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades

echo "✅ System hardening completed"
EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/harden-system.sh
```

## Support Resources

### Log Collection for Support
```bash
# Create support log collection script
cat > /home/ubuntu/claude-ai-agent/scripts/collect-support-logs.sh << 'EOF'
#!/bin/bash

SUPPORT_DIR="/home/ubuntu/claude-ai-agent/support-logs-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SUPPORT_DIR"

echo "Collecting support logs..."

# System information
uname -a > "$SUPPORT_DIR/system-info.txt"
lsb_release -a >> "$SUPPORT_DIR/system-info.txt"
free -h >> "$SUPPORT_DIR/system-info.txt"
df -h >> "$SUPPORT_DIR/system-info.txt"

# Service status
pm2 status > "$SUPPORT_DIR/pm2-status.txt"
sudo systemctl status nginx > "$SUPPORT_DIR/nginx-status.txt"

# Configuration files (sanitized)
cp /home/ubuntu/claude-ai-agent/.env "$SUPPORT_DIR/env-config.txt"
sed -i 's/ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=***REDACTED***/' "$SUPPORT_DIR/env-config.txt"

# Recent logs
tail -n 500 /home/ubuntu/claude-ai-agent/logs/app.log > "$SUPPORT_DIR/app-logs.txt"
sudo tail -n 200 /var/log/nginx/error.log > "$SUPPORT_DIR/nginx-error.txt"
pm2 logs --lines 200 > "$SUPPORT_DIR/pm2-logs.txt"

# Database info (no sensitive data)
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db << SQL > "$SUPPORT_DIR/database-info.txt"
.tables
SELECT 'conversation_logs: ' || COUNT(*) FROM conversation_logs;
SELECT 'user_sessions: ' || COUNT(*) FROM user_sessions;
SELECT 'system_metrics: ' || COUNT(*) FROM system_metrics;
SQL

# Create archive
tar -czf "$SUPPORT_DIR.tar.gz" "$SUPPORT_DIR"
rm -rf "$SUPPORT_DIR"

echo "Support logs collected: $SUPPORT_DIR.tar.gz"
echo "You can share this file for troubleshooting assistance."
EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/collect-support-logs.sh
```

### Quick Reference Commands
```bash
# Essential troubleshooting commands
alias claude-status='pm2 status && curl -s http://localhost:8000/health | jq .'
alias claude-logs='tail -f /home/ubuntu/claude-ai-agent/logs/app.log'
alias claude-restart='pm2 restart all && sudo systemctl restart nginx'
alias claude-health='./scripts/health-check.sh'
alias claude-monitor='./scripts/monitor.sh'

# Add to .bashrc for permanent aliases
echo "
# Claude AI Agent aliases
alias claude-status='pm2 status && curl -s http://localhost:8000/health | jq .'
alias claude-logs='tail -f /home/ubuntu/claude-ai-agent/logs/app.log'
alias claude-restart='pm2 restart all && sudo systemctl restart nginx'
alias claude-health='./scripts/health-check.sh'
alias claude-monitor='./scripts/monitor.sh'
" >> ~/.bashrc

source ~/.bashrc
```

For additional help with specific issues, refer to:
- [Installation Guide](INSTALLATION.md) for setup problems
- [Configuration Guide](CONFIGURATION.md) for configuration issues  
- [Monitoring Guide](MONITORING.md) for performance problems
- [API Documentation](API.md) for API-related issues

If problems persist, collect support logs using `./scripts/collect-support-logs.sh` and consult the Claude AI Agent community or documentation.
