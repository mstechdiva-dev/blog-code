#!/bin/bash

# Claude AI Agent Health Check Script
# Comprehensive system health analysis

echo "=== COMPREHENSIVE HEALTH CHECK ==="
echo "Time: $(date)"
echo "Host: $(hostname)"
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to get status indicator
get_status() {
    local condition=$1
    if [ "$condition" = "true" ]; then
        echo "✅"
    else
        echo "❌"
    fi
}

get_warning_status() {
    local value=$1
    local threshold=$2
    local operator=${3:-">"}
    
    if [ "$operator" = ">" ]; then
        if (( $(echo "$value > $threshold" | bc -l 2>/dev/null || echo "0") )); then
            echo "⚠️"
        else
            echo "✅"
        fi
    else
        if (( $(echo "$value < $threshold" | bc -l 2>/dev/null || echo "0") )); then
            echo "⚠️"
        else
            echo "✅"
        fi
    fi
}

# 1. SYSTEM RESOURCES
echo -e "${BLUE}1. SYSTEM RESOURCES${NC}"

# CPU Check
CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.1f", $(NF-2)*100}' 2>/dev/null || echo "0")
CPU_STATUS=$(get_warning_status "$CPU_USAGE" "80")
echo "   CPU Usage: $CPU_USAGE% $CPU_STATUS"

# Memory Check
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}' 2>/dev/null || echo "0")
MEMORY_STATUS=$(get_warning_status "$MEMORY_USAGE" "85")
MEMORY_USED=$(free -h | grep Mem | awk '{print $3}' 2>/dev/null || echo "N/A")
MEMORY_TOTAL=$(free -h | grep Mem | awk '{print $2}' 2>/dev/null || echo "N/A")
echo "   Memory Usage: $MEMORY_USAGE% ($MEMORY_USED/$MEMORY_TOTAL) $MEMORY_STATUS"

# Disk Check
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")
DISK_STATUS=$(get_warning_status "$DISK_USAGE" "85")
DISK_USED=$(df -h / | awk 'NR==2 {print $3}' 2>/dev/null || echo "N/A")
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}' 2>/dev/null || echo "N/A")
echo "   Disk Usage: $DISK_USAGE% ($DISK_USED/$DISK_TOTAL) $DISK_STATUS"

# Load Average
LOAD_1MIN=$(uptime | awk '{print $(NF-2)}' | sed 's/,//' 2>/dev/null || echo "0")
LOAD_5MIN=$(uptime | awk '{print $(NF-1)}' | sed 's/,//' 2>/dev/null || echo "0")
LOAD_15MIN=$(uptime | awk '{print $NF}' 2>/dev/null || echo "0")
echo "   Load Average: $LOAD_1MIN, $LOAD_5MIN, $LOAD_15MIN (1, 5, 15 min)"

# Uptime
UPTIME=$(uptime -p 2>/dev/null || echo "Unknown")
echo "   System Uptime: $UPTIME"

echo

# 2. PROCESS STATUS
echo -e "${BLUE}2. PROCESS STATUS${NC}"

# PM2 Processes
if command -v pm2 >/dev/null 2>&1; then
    PM2_OUTPUT=$(pm2 jlist 2>/dev/null)
    if [ "$PM2_OUTPUT" != "[]" ] && [ "$PM2_OUTPUT" != "" ]; then
        echo "$PM2_OUTPUT" | jq -r '.[] | "   \(.name): \(.pm2_env.status) (PID: \(.pid // "N/A"), CPU: \(.monit.cpu // 0)%, Mem: \((.monit.memory // 0)/1024/1024 | floor)MB) \(if .pm2_env.status == "online" then "✅" else "❌" end)"' 2>/dev/null || {
            echo "   PM2 parsing failed, showing raw status:"
            pm2 status --no-colors 2>/dev/null | grep -E "(claude-|Application)" || echo "   No PM2 processes found"
        }
    else
        echo "   PM2: No processes running ❌"
    fi
else
    echo "   PM2: Not available ❌"
fi

# System Services
echo "   System Services:"
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "     Nginx: Running ✅"
else
    echo "     Nginx: Not running ❌"
fi

if systemctl is-active --quiet ssh 2>/dev/null; then
    echo "     SSH: Running ✅"
else
    echo "     SSH: Not running ❌"
fi

echo

# 3. NETWORK CONNECTIVITY
echo -e "${BLUE}3. NETWORK CONNECTIVITY${NC}"

# Port Status
echo "   Port Status:"
for port in 80 443 8000 3000; do
    if netstat -tln 2>/dev/null | grep -q ":$port "; then
        CONNECTIONS=$(netstat -an 2>/dev/null | grep ":$port " | grep ESTABLISHED | wc -l)
        echo "     Port $port: Listening ($CONNECTIONS active connections) ✅"
    else
        echo "     Port $port: Not listening ❌"
    fi
done

# Local Service Tests
echo "   Local Service Tests:"

# Backend API Test
if curl -s --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
    RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null --max-time 10 http://localhost:8000/health 2>/dev/null || echo "timeout")
    echo "     Backend API (8000): Responding (${RESPONSE_TIME}s) ✅"
else
    echo "     Backend API (8000): Not responding ❌"
fi

# Frontend Test
if curl -s --max-time 10 http://localhost:3000 >/dev/null 2>&1; then
    echo "     Frontend (3000): Responding ✅"
else
    echo "     Frontend (3000): Not responding ❌"
fi

# Nginx Proxy Test
if curl -s --max-time 10 http://localhost/ >/dev/null 2>&1; then
    echo "     Nginx Proxy (80): Responding ✅"
else
    echo "     Nginx Proxy (80): Not responding ❌"
fi

# External Connectivity
echo "   External Connectivity:"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "     Internet: Connected ✅"
else
    echo "     Internet: Connection issues ❌"
fi

if curl -s --max-time 10 https://api.anthropic.com >/dev/null 2>&1; then
    echo "     Anthropic API: Reachable ✅"
else
    echo "     Anthropic API: Unreachable ❌"
fi

echo

# 4. DATABASE STATUS
echo -e "${BLUE}4. DATABASE STATUS${NC}"

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"

if [ -f "$DB_PATH" ]; then
    DB_SIZE=$(du -h "$DB_PATH" | cut -f1 2>/dev/null || echo "Unknown")
    echo "   Database File: Present ($DB_SIZE) ✅"
    
    # Database Integrity
    if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        echo "   Database Integrity: OK ✅"
    else
        echo "   Database Integrity: Failed ❌"
    fi
    
    # Table Status
    TABLES=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null | wc -w)
    if [ "$TABLES" -ge 4 ]; then
        echo "   Database Tables: $TABLES tables ✅"
    else
        echo "   Database Tables: $TABLES tables (expected 4+) ⚠️"
    fi
    
    # Data Statistics
    CONVERSATIONS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM conversation_logs;" 2>/dev/null || echo "0")
    SESSIONS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM user_sessions;" 2>/dev/null || echo "0")
    METRICS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM system_metrics;" 2>/dev/null || echo "0")
    
    echo "   Data Records:"
    echo "     Conversations: $CONVERSATIONS"
    echo "     Sessions: $SESSIONS"  
    echo "     Metrics: $METRICS"
    
    # Recent Activity
    RECENT_ACTIVITY=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM conversation_logs WHERE timestamp > datetime('now', '-24 hours');" 2>/dev/null || echo "0")
    echo "   Recent Activity: $RECENT_ACTIVITY conversations (24h)"
    
else
    echo "   Database File: Not found ❌"
fi

echo

# 5. CONFIGURATION STATUS
echo -e "${BLUE}5. CONFIGURATION STATUS${NC}"

# Environment File
if [ -f "/home/ubuntu/claude-ai-agent/.env" ]; then
    echo "   Environment File: Present ✅"
    
    # Check key configurations
    if grep -q "ANTHROPIC_API_KEY=sk-ant-" "/home/ubuntu/claude-ai-agent/.env" 2>/dev/null; then
        echo "   API Key: Configured ✅"
    else
        echo "   API Key: Not configured ❌"
    fi
    
    # Check other important configs
    if grep -q "MODEL_NAME=" "/home/ubuntu/claude-ai-agent/.env" 2>/dev/null; then
        MODEL=$(grep "MODEL_NAME=" "/home/ubuntu/claude-ai-agent/.env" | cut -d'=' -f2)
        echo "   Model Config: $MODEL ✅"
    else
        echo "   Model Config: Not set ⚠️"
    fi
    
    if grep -q "DATABASE_URL=" "/home/ubuntu/claude-ai-agent/.env" 2>/dev/null; then
        echo "   Database URL: Configured ✅"
    else
        echo "   Database URL: Not configured ⚠️"
    fi
    
else
    echo "   Environment File: Missing ❌"
fi

# Nginx Configuration
if [ -f "/etc/nginx/sites-available/claude-agent" ]; then
    echo "   Nginx Config: Present ✅"
    
    if sudo nginx -t >/dev/null 2>&1; then
        echo "   Nginx Syntax: Valid ✅"
    else
        echo "   Nginx Syntax: Invalid ❌"
    fi
else
    echo "   Nginx Config: Missing ❌"
fi

# Project Structure
PROJECT_DIRS=("backend" "frontend" "scripts" "logs" "data" "config")
MISSING_DIRS=()

for dir in "${PROJECT_DIRS[@]}"; do
    if [ ! -d "/home/ubuntu/claude-ai-agent/$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
    echo "   Project Structure: Complete ✅"
else
    echo "   Project Structure: Missing directories: ${MISSING_DIRS[*]} ⚠️"
fi

echo

# 6. LOG FILES STATUS
echo -e "${BLUE}6. LOG FILES STATUS${NC}"

LOG_DIR="/home/ubuntu/claude-ai-agent/logs"
if [ -d "$LOG_DIR" ]; then
    echo "   Log Directory: Present ✅"
    
    # Check individual log files
    LOG_FILES=("app.log" "backup.log" "maintenance.log")
    for logfile in "${LOG_FILES[@]}"; do
        if [ -f "$LOG_DIR/$logfile" ]; then
            SIZE=$(du -h "$LOG_DIR/$logfile" | cut -f1 2>/dev/null || echo "0B")
            MODIFIED=$(stat -c %y "$LOG_DIR/$logfile" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
            echo "     $logfile: Present ($SIZE, modified: $MODIFIED) ✅"
        else
            echo "     $logfile: Missing ⚠️"
        fi
    done
    
    # Check for errors in recent logs
    if [ -f "$LOG_DIR/app.log" ]; then
        RECENT_ERRORS=$(tail -n 100 "$LOG_DIR/app.log" 2>/dev/null | grep -i error | wc -l)
        if [ "$RECENT_ERRORS" -gt 10 ]; then
            echo "   Recent Errors: $RECENT_ERRORS (high) ⚠️"
        elif [ "$RECENT_ERRORS" -gt 0 ]; then
            echo "   Recent Errors: $RECENT_ERRORS (normal) ✅"
        else
            echo "   Recent Errors: None ✅"
        fi
    fi
else
    echo "   Log Directory: Missing ❌"
fi

# PM2 Logs
if command -v pm2 >/dev/null 2>&1; then
    PM2_LOG_DIR="$HOME/.pm2/logs"
    if [ -d "$PM2_LOG_DIR" ]; then
        PM2_LOGS=$(ls "$PM2_LOG_DIR"/*claude* 2>/dev/null | wc -l)
        echo "   PM2 Logs: $PM2_LOGS files ✅"
    else
        echo "   PM2 Logs: Directory missing ⚠️"
    fi
fi

echo

# 7. SECURITY STATUS
echo -e "${BLUE}7. SECURITY STATUS${NC}"

# Firewall Status
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -1 | grep -o "Status: \w*" | cut -d' ' -f2)
    if [ "$UFW_STATUS" = "active" ]; then
        echo "   Firewall (UFW): Active ✅"
    else
        echo "   Firewall (UFW): Inactive ⚠️"
    fi
else
    echo "   Firewall (UFW): Not installed ⚠️"
fi

# File Permissions
ENV_PERMS=$(stat -c %a "/home/ubuntu/claude-ai-agent/.env" 2>/dev/null || echo "000")
if [ "$ENV_PERMS" = "600" ]; then
    echo "   .env Permissions: Secure (600) ✅"
else
    echo "   .env Permissions: Insecure ($ENV_PERMS) ⚠️"
fi

# SSH Configuration
if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    echo "   SSH Password Auth: Disabled ✅"
else
    echo "   SSH Password Auth: Enabled ⚠️"
fi

echo

# 8. PERFORMANCE METRICS
echo -e "${BLUE}8. PERFORMANCE METRICS${NC}"

# Response Time Test
if curl -s --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
    API_RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null --max-time 10 http://localhost:8000/health 2>/dev/null || echo "timeout")
    if [ "$API_RESPONSE_TIME" != "timeout" ]; then
        echo "   API Response Time: ${API_RESPONSE_TIME}s"
    else
        echo "   API Response Time: Timeout ❌"
    fi
else
    echo "   API Response Time: API not responding ❌"
fi

# Database Query Performance
if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" >/dev/null 2>&1; then
    DB_QUERY_TIME=$(time (sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM conversation_logs;") 2>&1 | grep real | awk '{print $2}' || echo "unknown")
    echo "   Database Query Time: $DB_QUERY_TIME"
else
    echo "   Database Query Time: Database not accessible ❌"
fi

# Memory per Process
if command -v pm2 >/dev/null 2>&1; then
    PM2_JSON=$(pm2 jlist 2>/dev/null)
    if [ "$PM2_JSON" != "[]" ] && [ "$PM2_JSON" != "" ]; then
        echo "   Process Memory Usage:"
        echo "$PM2_JSON" | jq -r '.[] | "     \(.name): \((.monit.memory // 0)/1024/1024 | floor)MB"' 2>/dev/null || echo "     Memory info unavailable"
    fi
fi

echo

# 9. OVERALL HEALTH SUMMARY
echo -e "${BLUE}9. OVERALL HEALTH SUMMARY${NC}"

# Calculate health score
HEALTH_SCORE=0
TOTAL_CHECKS=0

# Critical checks (weight: 3)
CRITICAL_CHECKS=(
    "$([ $(echo "$CPU_USAGE < 90" | bc -l 2>/dev/null || echo "1") -eq 1 ] && echo "true" || echo "false")"
    "$([ $(echo "$MEMORY_USAGE < 95" | bc -l 2>/dev/null || echo "1") -eq 1 ] && echo "true" || echo "false")"
    "$([ "$DISK_USAGE" -lt 95 ] && echo "true" || echo "false")"
    "$(curl -s --max-time 5 http://localhost:8000/health >/dev/null 2>&1 && echo "true" || echo "false")"
    "$(systemctl is-active --quiet nginx && echo "true" || echo "false")"
)

for check in "${CRITICAL_CHECKS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 3))
    if [ "$check" = "true" ]; then
        HEALTH_SCORE=$((HEALTH_SCORE + 3))
    fi
done

# Important checks (weight: 2)
IMPORTANT_CHECKS=(
    "$(curl -s --max-time 5 http://localhost:3000 >/dev/null 2>&1 && echo "true" || echo "false")"
    "$([ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok" && echo "true" || echo "false")"
    "$([ -f "/home/ubuntu/claude-ai-agent/.env" ] && grep -q "ANTHROPIC_API_KEY=sk-ant-" "/home/ubuntu/claude-ai-agent/.env" 2>/dev/null && echo "true" || echo "false")"
)

for check in "${IMPORTANT_CHECKS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 2))
    if [ "$check" = "true" ]; then
        HEALTH_SCORE=$((HEALTH_SCORE + 2))
    fi
done

# Calculate percentage
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    HEALTH_PERCENTAGE=$(echo "scale=1; $HEALTH_SCORE * 100 / $TOTAL_CHECKS" | bc -l 2>/dev/null || echo "0")
else
    HEALTH_PERCENTAGE=0
fi

echo "   Overall Health Score: $HEALTH_SCORE/$TOTAL_CHECKS (${HEALTH_PERCENTAGE}%)"

if (( $(echo "$HEALTH_PERCENTAGE >= 90" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "   System Status: ${GREEN}EXCELLENT${NC} 🎉"
    RECOMMENDATION="System is operating optimally. Continue regular monitoring."
elif (( $(echo "$HEALTH_PERCENTAGE >= 75" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "   System Status: ${GREEN}GOOD${NC} ✅"
    RECOMMENDATION="System is stable with minor issues. Address warnings when convenient."
elif (( $(echo "$HEALTH_PERCENTAGE >= 50" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "   System Status: ${YELLOW}NEEDS ATTENTION${NC} ⚠️"
    RECOMMENDATION="Some issues detected. Review failed checks and take corrective action."
else
    echo -e "   System Status: ${RED}CRITICAL${NC} 🚨"
    RECOMMENDATION="Multiple critical issues detected. Immediate attention required."
fi

echo
echo -e "${BLUE}RECOMMENDATIONS:${NC}"
echo "   $RECOMMENDATION"

# Specific recommendations based on issues found
echo
echo "   Specific Actions:"

if (( $(echo "$CPU_USAGE > 80" | bc -l 2>/dev/null || echo "0") )); then
    echo "   • High CPU usage detected - investigate processes"
fi

if (( $(echo "$MEMORY_USAGE > 85" | bc -l 2>/dev/null || echo "0") )); then
    echo "   • High memory usage detected - consider restarting services"
fi

if [ "$DISK_USAGE" -gt 85 ]; then
    echo "   • High disk usage detected - clean up old files"
fi

if ! grep -q "ANTHROPIC_API_KEY=sk-ant-" "/home/ubuntu/claude-ai-agent/.env" 2>/dev/null; then
    echo "   • API key not configured - edit: nano /home/ubuntu/claude-ai-agent/.env"
fi

if [ ! -f "$DB_PATH" ] || ! sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
    echo "   • Database issues detected - run recovery script: ./scripts/recover.sh"
fi

echo
echo "   Management Commands:"
echo "   • Full system status: ./scripts/status.sh"
echo "   • Real-time monitoring: ./scripts/monitor.sh"
echo "   • Emergency recovery: ./scripts/recover.sh"
echo "   • Create backup: ./scripts/backup.sh"
echo "   • View logs: pm2 logs"

echo
echo "=== HEALTH CHECK COMPLETE ==="
echo "Generated: $(date)"
echo "Next check recommended in: 1 hour"

# Log health check results
LOG_FILE="/home/ubuntu/claude-ai-agent/logs/health-check.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "$(date): Health check completed - Score: $HEALTH_SCORE/$TOTAL_CHECKS (${HEALTH_PERCENTAGE}%)" >> "$LOG_FILE" curl -s --max-time 5 http://localhost:8000/health >/dev/null 2>&1; then
    echo "   • Backend API not responding - run recovery script: ./scripts/recover.sh"
fi

if ! systemctl is-active --quiet nginx; then
    echo "   • Nginx not running - restart: sudo systemctl start nginx"
fi

if !
