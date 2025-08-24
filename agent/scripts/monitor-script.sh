#!/bin/bash

# Claude AI Agent Monitoring Script
# Provides real-time system and application monitoring with comprehensive error handling

set -u  # Exit on undefined variables

echo "=== Claude AI Agent System Monitor ==="
echo "Time: $(date)"
echo "Host: $(hostname 2>/dev/null || echo "Unknown")"
echo

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="$PROJECT_ROOT/logs/monitor.log"

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely execute commands with error handling
safe_exec() {
    local cmd="$1"
    local default_value="${2:-N/A}"
    
    if eval "$cmd" 2>/dev/null; then
        return 0
    else
        echo "$default_value"
        return 1
    fi
}

# Function to get numeric value safely
get_numeric() {
    local cmd="$1"
    local default="${2:-0}"
    
    local result
    result=$(eval "$cmd" 2>/dev/null || echo "$default")
    
    # Validate that result is numeric
    if [[ "$result" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$result"
    else
        echo "$default"
    fi
}

# Function to get status indicator
get_status_indicator() {
    local value="$1"
    local threshold="$2"
    local operator="${3:-">="}"
    
    # Ensure we have numeric values
    if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ "$threshold" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "❓"
        return 1
    fi
    
    case "$operator" in
        ">=")
            if command_exists bc && (( $(echo "$value >= $threshold" | bc -l 2>/dev/null || echo "0") )); then
                echo "⚠️"
            else
                echo "✅"
            fi
            ;;
        "<=")
            if command_exists bc && (( $(echo "$value <= $threshold" | bc -l 2>/dev/null || echo "1") )); then
                echo "✅"
            else
                echo "⚠️"
            fi
            ;;
        ">")
            if command_exists bc && (( $(echo "$value > $threshold" | bc -l 2>/dev/null || echo "0") )); then
                echo "⚠️"
            else
                echo "✅"
            fi
            ;;
        "<")
            if command_exists bc && (( $(echo "$value < $threshold" | bc -l 2>/dev/null || echo "1") )); then
                echo "✅"
            else
                echo "⚠️"
            fi
            ;;
        *)
            echo "❓"
            ;;
    esac
}

# System Resources Monitoring
monitor_system_resources() {
    echo -e "${BLUE}📊 SYSTEM RESOURCES${NC}"
    
    # CPU Usage
    local cpu_usage
    cpu_usage=$(get_numeric "top -bn1 | grep load | awk '{printf \"%.1f\", \$(NF-2)*100}'" "0")
    local cpu_status
    cpu_status=$(get_status_indicator "$cpu_usage" "80" ">=")
    echo "   CPU Usage: ${cpu_usage}% $cpu_status"
    
    # Memory Usage
    local memory_usage memory_used memory_total
    if command_exists free; then
        memory_usage=$(get_numeric "free | grep Mem | awk '{printf \"%.1f\", (\$3/\$2) * 100.0}'" "0")
        memory_used=$(safe_exec "free -h | grep Mem | awk '{print \$3}'" "N/A")
        memory_total=$(safe_exec "free -h | grep Mem | awk '{print \$2}'" "N/A")
    else
        memory_usage="0"
        memory_used="N/A"
        memory_total="N/A"
    fi
    local memory_status
    memory_status=$(get_status_indicator "$memory_usage" "85" ">=")
    echo "   Memory Usage: ${memory_usage}% ($memory_used/$memory_total) $memory_status"
    
    # Disk Usage
    local disk_usage disk_used disk_total
    if command_exists df; then
        disk_usage=$(get_numeric "df / | awk 'NR==2 {print \$5}' | sed 's/%//'" "0")
        disk_used=$(safe_exec "df -h / | awk 'NR==2 {print \$3}'" "N/A")
        disk_total=$(safe_exec "df -h / | awk 'NR==2 {print \$2}'" "N/A")
    else
        disk_usage="0"
        disk_used="N/A"
        disk_total="N/A"
    fi
    local disk_status
    disk_status=$(get_status_indicator "$disk_usage" "85" ">=")
    echo "   Disk Usage: ${disk_usage}% ($disk_used/$disk_total) $disk_status"
    
    # System Load
    if command_exists uptime; then
        local load_1min load_5min load_15min
        load_1min=$(safe_exec "uptime | awk '{print \$(NF-2)}' | sed 's/,//'" "0")
        load_5min=$(safe_exec "uptime | awk '{print \$(NF-1)}' | sed 's/,//'" "0")
        load_15min=$(safe_exec "uptime | awk '{print \$NF}'" "0")
        echo "   Load Average: $load_1min, $load_5min, $load_15min (1, 5, 15 min)"
    else
        echo "   Load Average: N/A (uptime command not available)"
    fi
    
    # Uptime
    local uptime_info
    if command_exists uptime; then
        uptime_info=$(safe_exec "uptime -p" "Unknown")
    else
        uptime_info="Unknown"
    fi
    echo "   System Uptime: $uptime_info"
    
    echo
}

# Process Status Monitoring
monitor_processes() {
    echo -e "${BLUE}🚀 PROCESS STATUS${NC}"
    
    # PM2 Processes
    if command_exists pm2; then
        local pm2_output
        pm2_output=$(pm2 jlist 2>/dev/null || echo "[]")
        
        if [ "$pm2_output" != "[]" ] && [ -n "$pm2_output" ]; then
            if command_exists jq; then
                # Use jq for reliable JSON parsing
                if echo "$pm2_output" | jq -e '. | length > 0' >/dev/null 2>&1; then
                    echo "$pm2_output" | jq -r '.[] | "   \(.name): \(.pm2_env.status) (PID: \(.pid // "N/A"), CPU: \(.monit.cpu // 0)%, Mem: \((.monit.memory // 0)/1024/1024 | floor)MB) \(if .pm2_env.status == "online" then "✅" else "❌" end)"' 2>/dev/null || {
                        echo "   PM2 JSON parsing failed, showing basic status:"
                        pm2 status --no-colors 2>/dev/null | grep -E "(claude-|Application|Process)" | head -10 || echo "   No PM2 processes found"
                    }
                else
                    echo "   PM2: No processes running ❌"
                fi
            else
                # Fallback without jq
                echo "   PM2: JSON parsing not available (jq not found)"
                pm2 status --no-colors 2>/dev/null | grep -E "(claude-|Application|Process)" | head -10 || echo "   No PM2 processes found"
            fi
        else
            echo "   PM2: No processes running ❌"
        fi
    else
        echo "   PM2: Not available ❌"
    fi
    
    # System Services
    echo "   System Services:"
    
    # Nginx
    if command_exists systemctl; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            echo "     Nginx: Running ✅"
        else
            echo "     Nginx: Not running ❌"
        fi
        
        # SSH
        if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
            echo "     SSH: Running ✅"
        else
            echo "     SSH: Not running ❌"
        fi
    else
        echo "     Service status: N/A (systemctl not available)"
    fi
    
    echo
}

# Network Connectivity Monitoring
monitor_network() {
    echo -e "${BLUE}🌐 NETWORK STATUS${NC}"
    
    # Port Status
    echo "   Port Status:"
    if command_exists netstat; then
        local ports=(80 443 8000 3000)
        for port in "${ports[@]}"; do
            if netstat -tln 2>/dev/null | grep -q ":$port "; then
                local connections
                connections=$(netstat -an 2>/dev/null | grep ":$port " | grep ESTABLISHED | wc -l)
                echo "     Port $port: Listening ($connections active connections) ✅"
            else
                echo "     Port $port: Not listening ❌"
            fi
        done
    else
        echo "     Port monitoring: N/A (netstat not available)"
    fi
    
    # Local Service Tests
    echo "   Local Service Tests:"
    
    # Backend API Test
    if command_exists curl; then
        if curl -s --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
            local response_time
            response_time=$(curl -w "%{time_total}" -s -o /dev/null --max-time 10 http://localhost:8000/health 2>/dev/null || echo "timeout")
            if [ "$response_time" != "timeout" ]; then
                echo "     Backend API (8000): Responding (${response_time}s) ✅"
            else
                echo "     Backend API (8000): Timeout ⚠️"
            fi
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
    else
        echo "     Service tests: N/A (curl not available)"
    fi
    
    # External Connectivity
    echo "   External Connectivity:"
    if command_exists ping; then
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            echo "     Internet: Connected ✅"
        else
            echo "     Internet: Connection issues ❌"
        fi
    else
        echo "     Internet: N/A (ping not available)"
    fi
    
    if command_exists curl; then
        if curl -s --max-time 10 https://api.anthropic.com >/dev/null 2>&1; then
            echo "     Anthropic API: Reachable ✅"
        else
            echo "     Anthropic API: Unreachable ❌"
        fi
    else
        echo "     External API tests: N/A (curl not available)"
    fi
    
    echo
}

# Database Status Monitoring
monitor_database() {
    echo -e "${BLUE}💾 DATABASE STATUS${NC}"
    
    local db_path="$PROJECT_ROOT/data/agent_database.db"
    
    if [ -f "$db_path" ]; then
        local db_size
        db_size=$(du -h "$db_path" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "   Database File: Present ($db_size) ✅"
        
        # Database Integrity Check
        if command_exists sqlite3; then
            if sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
                echo "   Database Integrity: OK ✅"
            else
                echo "   Database Integrity: Failed ❌"
            fi
            
            # Table Status
            local tables
            tables=$(sqlite3 "$db_path" ".tables" 2>/dev/null | wc -w || echo "0")
            if [ "$tables" -ge 4 ]; then
                echo "   Database Tables: $tables tables ✅"
            elif [ "$tables" -gt 0 ]; then
                echo "   Database Tables: $tables tables (expected 4+) ⚠️"
            else
                echo "   Database Tables: No tables found ❌"
            fi
            
            # Data Statistics (with error handling)
            echo "   Data Records:"
            local conversations sessions metrics
            conversations=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM conversation_logs;" 2>/dev/null || echo "0")
            sessions=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM user_sessions;" 2>/dev/null || echo "0")
            metrics=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM system_metrics;" 2>/dev/null || echo "0")
            
            echo "     Conversations: $conversations"
            echo "     Sessions: $sessions"
            echo "     Metrics: $metrics"
            
            # Recent Activity
            local recent_activity
            recent_activity=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM conversation_logs WHERE timestamp > datetime('now', '-24 hours');" 2>/dev/null || echo "0")
            echo "   Recent Activity: $recent_activity conversations (24h)"
            
        else
            echo "   Database Access: N/A (sqlite3 not available)"
        fi
    else
        echo "   Database File: Not found ❌"
        echo "   Expected location: $db_path"
    fi
    
    echo
}

# Application Health Monitoring
monitor_application() {
    echo -e "${BLUE}🔍 APPLICATION HEALTH${NC}"
    
    # Configuration Check
    local env_file="$PROJECT_ROOT/.env"
    if [ -f "$env_file" ]; then
        echo "   Environment Config: Present ✅"
        
        # Check API key configuration (safely)
        if grep -q "ANTHROPIC_API_KEY=sk-ant-" "$env_file" 2>/dev/null; then
            echo "   API Key: Configured ✅"
        else
            echo "   API Key: Not configured ❌"
        fi
        
        # Check other configurations
        local model_config
        model_config=$(grep "MODEL_NAME=" "$env_file" 2>/dev/null | cut -d'=' -f2 || echo "Not set")
        if [ "$model_config" != "Not set" ] && [ -n "$model_config" ]; then
            echo "   Model Config: $model_config ✅"
        else
            echo "   Model Config: Not set ⚠️"
        fi
        
        if grep -q "DATABASE_URL=" "$env_file" 2>/dev/null; then
            echo "   Database URL: Configured ✅"
        else
            echo "   Database URL: Not configured ⚠️"
        fi
    else
        echo "   Environment Config: Missing ❌"
        echo "   Expected location: $env_file"
    fi
    
    # Log Files Check
    local app_log="$PROJECT_ROOT/logs/app.log"
    if [ -f "$app_log" ]; then
        local recent_errors
        recent_errors=$(tail -n 100 "$app_log" 2>/dev/null | grep -i error | wc -l || echo "0")
        if [ "$recent_errors" -gt 10 ]; then
            echo "   Recent Errors: $recent_errors (high) ⚠️"
        elif [ "$recent_errors" -gt 0 ]; then
            echo "   Recent Errors: $recent_errors (normal) ✅"
        else
            echo "   Recent Errors: None ✅"
        fi
    else
        echo "   Application Logs: Not found ⚠️"
    fi
    
    # API Response Test (if configured)
    if [ -f "$env_file" ] && grep -q "ANTHROPIC_API_KEY=sk-ant-" "$env_file" 2>/dev/null; then
        if command_exists curl; then
            local response_time
            response_time=$(curl -w "%{time_total}" -s -o /dev/null --max-time 10 http://localhost:8000/health 2>/dev/null || echo "timeout")
            if [ "$response_time" != "timeout" ]; then
                echo "   API Response Time: ${response_time}s ✅"
            else
                echo "   API Response Time: Timeout ❌"
            fi
        else
            echo "   API Response Time: N/A (curl not available)"
        fi
    else
        echo "   API Response Time: N/A (API key not configured)"
    fi
    
    echo
}

# System Services Monitoring
monitor_system_services() {
    echo -e "${BLUE}⚙️ SYSTEM SERVICES${NC}"
    
    # Nginx status
    if command_exists systemctl; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            echo "   Nginx: Running ✅"
            
            # Check Nginx configuration
            if command_exists nginx && nginx -t >/dev/null 2>&1; then
                echo "   Nginx Config: Valid ✅"
            else
                echo "   Nginx Config: Invalid ⚠️"
            fi
        else
            echo "   Nginx: Not running ❌"
        fi
    else
        echo "   Nginx: N/A (systemctl not available)"
    fi
    
    # Firewall status
    if command_exists ufw; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null | head -1 | grep -o "Status: \w*" | cut -d' ' -f2 2>/dev/null || echo "unknown")
        if [ "$ufw_status" = "active" ]; then
            echo "   Firewall (UFW): Active ✅"
        elif [ "$ufw_status" = "inactive" ]; then
            echo "   Firewall (UFW): Inactive ⚠️"
        else
            echo "   Firewall (UFW): Status unknown ❓"
        fi
    else
        echo "   Firewall (UFW): Not installed ⚠️"
    fi
    
    echo
}

# Recent Activity Summary
monitor_recent_activity() {
    echo -e "${BLUE}📈 RECENT ACTIVITY SUMMARY${NC}"
    
    local db_path="$PROJECT_ROOT/data/agent_database.db"
    if [ -f "$db_path" ] && command_exists sqlite3 && sqlite3 "$db_path" ".tables" >/dev/null 2>&1; then
        # Last hour activity
        local hour_requests hour_tokens
        hour_requests=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM conversation_logs WHERE timestamp > datetime('now', '-1 hour');" 2>/dev/null || echo "0")
        hour_tokens=$(sqlite3 "$db_path" "SELECT COALESCE(SUM(tokens_used), 0) FROM conversation_logs WHERE timestamp > datetime('now', '-1 hour');" 2>/dev/null || echo "0")
        
        echo "   Last Hour: $hour_requests requests, $hour_tokens tokens"
        
        # Today's activity
        local today_requests today_tokens
        today_requests=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM conversation_logs WHERE DATE(timestamp) = DATE('now');" 2>/dev/null || echo "0")
        today_tokens=$(sqlite3 "$db_path" "SELECT COALESCE(SUM(tokens_used), 0) FROM conversation_logs WHERE DATE(timestamp) = DATE('now');" 2>/dev/null || echo "0")
        
        echo "   Today: $today_requests requests, $today_tokens tokens"
        
        # Error rate calculation
        local today_errors error_rate
        today_errors=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM conversation_logs WHERE DATE(timestamp) = DATE('now') AND success = 0;" 2>/dev/null || echo "0")
        if [ "$today_requests" -gt 0 ] && command_exists bc; then
            error_rate=$(echo "scale=2; $today_errors * 100 / $today_requests" | bc -l 2>/dev/null || echo "0")
            echo "   Error Rate: ${error_rate}% ($today_errors errors)"
        else
            echo "   Error Rate: 0% (no requests today)"
        fi
    else
        echo "   Activity data unavailable (database not accessible)"
    fi
    
    echo
}

# System Status Summary
show_system_summary() {
    echo -e "${BLUE}🔧 QUICK ACTIONS${NC}"
    echo "   View logs:       pm2 logs"
    echo "   Restart all:     pm2 restart all"
    echo "   Full status:     ./scripts/status.sh"
    echo "   Health check:    ./scripts/health-check.sh"
    echo "   Database info:   ./scripts/db-monitor.sh"
    echo "   Emergency help:  ./scripts/recover.sh"
    
    # Check if any services need attention
    local needs_attention=false
    local attention_reasons=()
    
    # Check CPU
    local cpu_usage
    cpu_usage=$(get_numeric "top -bn1 | grep load | awk '{printf \"%.0f\", \$(NF-2)*100}'" "0")
    if command_exists bc && (( $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo "0") )); then
        needs_attention=true
        attention_reasons+=("High CPU: ${cpu_usage}%")
    fi
    
    # Check Memory
    local memory_usage
    memory_usage=$(get_numeric "free | grep Mem | awk '{printf \"%.0f\", (\$3/\$2) * 100.0}'" "0")
    if command_exists bc && (( $(echo "$memory_usage > 85" | bc -l 2>/dev/null || echo "0") )); then
        needs_attention=true
        attention_reasons+=("High Memory: ${memory_usage}%")
    fi
    
    # Check Disk
    local disk_usage
    disk_usage=$(get_numeric "df / | awk 'NR==2 {print \$5}' | sed 's/%//'" "0")
    if [ "$disk_usage" -gt 85 ]; then
        needs_attention=true
        attention_reasons+=("High Disk: ${disk_usage}%")
    fi
    
    # Check API
    if ! curl -s --max-time 5 http://localhost:8000/health >/dev/null 2>&1; then
        needs_attention=true
        attention_reasons+=("API not responding")
    fi
    
    echo
    if [ "$needs_attention" = true ]; then
        echo -e "${YELLOW}⚠️ ATTENTION NEEDED:${NC}"
        for reason in "${attention_reasons[@]}"; do
            echo "   • $reason"
        done
        echo "   Run: ./scripts/health-check.sh for detailed diagnosis"
        echo "   Run: ./scripts/recover.sh if services are failing"
    else
        echo -e "${GREEN}✅ ALL SYSTEMS NOMINAL${NC}"
        echo "   System is operating within normal parameters"
    fi
    
    echo
    echo "Monitor completed at $(date)"
    echo "Run 'watch -n 30 ./scripts/monitor.sh' for continuous monitoring"
    
    # Log monitoring completion
    echo "$(date): Monitor completed" >> "$LOG_FILE" 2>/dev/null || true
}

# Main monitoring function
main() {
    # Verify we're in the right directory
    if [ ! -d "$PROJECT_ROOT" ]; then
        echo "Error: Project root not found: $PROJECT_ROOT"
        exit 1
    fi
    
    # Run all monitoring functions
    monitor_system_resources
    monitor_processes
    monitor_network
    monitor_database
    monitor_application
    monitor_system_services
    monitor_recent_activity
    show_system_summary
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
