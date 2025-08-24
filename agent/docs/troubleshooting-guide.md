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
- "Database connection failed" errors
- Unable to save conversations
- Data not persisting

**Diagnosis:**
```bash
# Check if database file exists
ls -la /home/ubuntu/claude-ai-agent/data/agent_database.db

# Check database permissions
stat /home/ubuntu/claude-ai-agent/data/agent_database.db

# Test database connectivity
sqlite3 /home/ubuntu/claude-ai-agent/data/agent_database.db ".tables"
```

**Solutions:**

**A. Fix Database Permissions:**
```bash
# Ensure correct ownership
sudo chown ubuntu:ubuntu /home/ubuntu/claude-ai-agent/data/agent_database.db

# Set proper permissions
chmod 664 /home/ubuntu/claude-ai-agent/data/agent_database.db

# Ensure data directory exists
mkdir -p /home/ubuntu/claude-ai-agent/data
```

**B. Recreate Database:**
```bash
cd /home/ubuntu/claude-ai-agent/backend
source venv/bin/activate

# Backup existing database if it exists
if [ -f "../data/agent_database.db" ]; then
    cp ../data/agent_database.db ../data/agent_database.db.backup
fi

# Recreate database
python -c "from database import init_database; init_database()"
```

### 4. High Resource Usage

**Symptoms:**
- System running slowly
- High CPU or memory usage
- Out of memory errors

**Diagnosis:**
```bash
# Check resource usage
top -bn1 | head -20

# Check specific process usage
ps aux | grep claude

# Check memory details
free -h

# Check disk usage
df -h
```

**Solutions:**

**A. Memory Optimization:**
```bash
# Restart services to free memory
pm2 restart all

# Increase swap if needed (temporary fix)
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**B. Process Limits:**
```bash
# Set PM2 memory limits
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" \
    --name claude-backend \
    --max-memory-restart 400M

pm2 start "npx serve -s build -l 3000" \
    --name claude-frontend \
    --max-memory-restart 200M
```

### 5. SSL/HTTPS Issues

**Symptoms:**
- Certificate warnings in browser
- HTTPS not working
- Mixed content errors

**Diagnosis:**
```bash
# Check nginx configuration
sudo nginx -t

# Check SSL certificates
sudo certbot certificates

# Check certificate expiration
openssl x509 -in /path/to/certificate.crt -text -noout | grep "Not After"
```

**Solutions:**

**A. Install Let's Encrypt Certificate:**
```bash
# Install certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Get certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

**B. Update Nginx Configuration:**
```bash
# Edit nginx configuration
sudo nano /etc/nginx/sites-available/claude-agent

# Add SSL configuration (example)
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # Your existing location blocks here
}

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

## Advanced Troubleshooting

### Database Recovery
```bash
# Create database recovery script
cat > /home/ubuntu/claude-ai-agent/scripts/db-recovery.sh << 'EOF'
#!/bin/bash

echo "=== DATABASE RECOVERY SCRIPT ==="
DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"
BACKUP_PATH="/home/ubuntu/claude-ai-agent/backups/db_recovery_$(date +%Y%m%d_%H%M%S).db"

# 1. Create backup of current database
if [ -f "$DB_PATH" ]; then
    echo "Creating backup of current database..."
    cp "$DB_PATH" "$BACKUP_PATH"
    echo "Backup created: $BACKUP_PATH"
fi

# 2. Check database integrity
if [ -f "$DB_PATH" ]; then
    echo "Checking database integrity..."
    INTEGRITY_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null)
    if [ "$INTEGRITY_CHECK" = "ok" ]; then
        echo "✅ Database integrity is OK"
    else
        echo "❌ Database integrity check failed"
        echo "Attempting to repair..."
        
        # 3. Attempt repair
        sqlite3 "$DB_PATH" ".recover" > /tmp/recovered.sql 2>/dev/null
        if [ $? -eq 0 ] && [ -s /tmp/recovered.sql ]; then
            mv "$DB_PATH" "${DB_PATH}.corrupted"
            sqlite3 "$DB_PATH" < /tmp/recovered.sql
            echo "✅ Database recovered from corruption"
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
fi

# 5. Set proper permissions
chmod 664 "$DB_PATH"
chown ubuntu:ubuntu "$DB_PATH"

echo "=== DATABASE RECOVERY COMPLETE ==="
EOF

chmod +x /home/ubuntu/claude-ai-agent/scripts/db-recovery.sh
```

### Performance Issues

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

# 3. Clean temporary files
sudo apt-get clean
sudo apt-get autoremove -y
rm -rf /tmp/*
pm2 flush

# 4. Restart services
sudo systemctl start nginx
pm2 restart all

# 5. Verify recovery
sleep 10
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ System recovered successfully"
else
    echo "❌ Recovery failed - manual intervention needed"
fi
```

## Preventive Maintenance

### Automated Health Monitoring
```bash
# Create comprehensive health monitor
cat > /home/ubuntu/claude-ai-agent/scripts/health-monitor.sh << 'EOF'
#!/bin/bash

ALERT_LOG="/home/ubuntu/claude-ai-agent/logs/health-alerts.log"

# Function to log alerts
log_alert() {
    echo "$(date): $1" >> $ALERT_LOG
}

# Check system resources
CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.0f", $(NF-2)*100}')
if [ $CPU_USAGE -gt 90 ]; then
    log_alert "CRITICAL: High CPU usage: ${CPU_USAGE}%"
fi

MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
if [ $MEMORY_USAGE -gt 90 ]; then
    log_alert "CRITICAL: High memory usage: ${MEMORY_USAGE}%"
fi

DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    log_alert "CRITICAL: High disk usage: ${DISK_USAGE}%"
fi

# Check API status
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

## Troubleshooting Checklist

### When Things Go Wrong
1. **Check system resources** - CPU, memory, disk space
2. **Verify services** - PM2 processes, Nginx status
3. **Test connectivity** - API endpoints, database access
4. **Review logs** - Application logs, system logs, PM2 logs
5. **Check configuration** - Environment variables, file permissions
6. **Test API key** - Verify Anthropic API connectivity
7. **Restart services** - PM2 processes, Nginx
8. **Check network** - Firewall rules, port availability

### Emergency Contacts
- **System logs**: `/var/log/syslog`
- **Application logs**: `/home/ubuntu/claude-ai-agent/logs/app.log`
- **Health check**: `./scripts/health-check.sh`
- **Recovery script**: `./scripts/recover.sh`
- **Support logs**: `./scripts/collect-support-logs.sh`

## Common Commands Reference

```bash
# Service Management
pm2 status                    # Check all processes
pm2 restart all              # Restart all services
pm2 logs                     # View all logs
sudo systemctl restart nginx # Restart web server

# Health Monitoring
curl localhost:8000/health   # API health check
./scripts/health-check.sh    # Comprehensive health
./scripts/monitor.sh         # System monitoring

# Log Analysis
tail -f logs/app.log         # Follow application logs
grep -i error logs/app.log   # Find errors
pm2 logs claude-backend      # Backend specific logs

# Database Operations
sqlite3 data/agent_database.db ".tables"  # List tables
./scripts/db-monitor.sh      # Database statistics
./scripts/db-recovery.sh     # Database recovery

# System Maintenance
./scripts/backup.sh          # Create backup
./scripts/cleanup.sh         # Clean old files
sudo apt-get update && sudo apt-get upgrade -y  # Update system
```

For additional help with specific issues, refer to:
- [Installation Guide](installation-guide.md) for setup problems
- [Configuration Guide](configuration-guide.md) for configuration issues  
- [Monitoring Guide](monitoring-guide.md) for performance problems
- [API Documentation](api-documentation.md) for API-related issues

If problems persist, collect support logs using `./scripts/collect-support-logs.sh` and consult the Claude AI Agent community or documentation.
