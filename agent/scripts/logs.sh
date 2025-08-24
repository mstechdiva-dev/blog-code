#!/bin/bash

# Claude AI Agent - Log Viewing Utility
# Centralized log access and filtering

SERVICE="${1:-all}"

echo "=== Claude AI Agent Logs ==="
echo "Service: $SERVICE"
echo "Time: $(date)"
echo

case "$SERVICE" in
    "backend"|"api")
        echo "Backend API Logs:"
        echo "=================="
        pm2 logs claude-backend --lines 50 2>/dev/null || echo "Backend logs not available"
        ;;
    
    "frontend"|"react")
        echo "Frontend Logs:"
        echo "=============="
        pm2 logs claude-frontend --lines 50 2>/dev/null || echo "Frontend logs not available"
        ;;
    
    "nginx"|"web")
        echo "Nginx Access Logs:"
        echo "=================="
        sudo tail -n 50 /var/log/nginx/access.log 2>/dev/null || echo "Nginx access logs not available"
        echo
        echo "Nginx Error Logs:"
        echo "================="
        sudo tail -n 50 /var/log/nginx/error.log 2>/dev/null || echo "Nginx error logs not available"
        ;;
    
    "system")
        echo "System Logs:"
        echo "============"
        journalctl --since "1 hour ago" --no-pager -n 50
        ;;
    
    "app"|"application")
        echo "Application Logs:"
        echo "================="
        if [ -f "/home/ubuntu/claude-ai-agent/logs/app.log" ]; then
            tail -n 50 /home/ubuntu/claude-ai-agent/logs/app.log
        else
            echo "Application log file not found"
        fi
        ;;
    
    "errors")
        echo "Recent Errors (All Services):"
        echo "============================="
        echo "PM2 Errors:"
        pm2 logs --err --lines 20 2>/dev/null
        echo
        echo "Nginx Errors:"
        sudo tail -n 20 /var/log/nginx/error.log 2>/dev/null | grep -v "connect() failed"
        echo
        echo "Application Errors:"
        if [ -f "/home/ubuntu/claude-ai-agent/logs/app.log" ]; then
            tail -n 100 /home/ubuntu/claude-ai-agent/logs/app.log | grep -i error | tail -20
        fi
        ;;
    
    "follow"|"tail")
        echo "Following all PM2 logs (Ctrl+C to exit):"
        echo "========================================"
        pm2 logs
        ;;
    
    "all"|*)
        echo "All Service Status:"
        echo "==================="
        pm2 status
        echo
        echo "Recent PM2 Logs:"
        echo "================"
        pm2 logs --lines 30
        echo
        echo "Recent Nginx Errors:"
        echo "===================="
        sudo tail -n 10 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error logs"
        ;;
esac

echo
echo "Available log options:"
echo "  ./logs.sh backend    - Backend API logs"
echo "  ./logs.sh frontend   - Frontend logs"
echo "  ./logs.sh nginx      - Web server logs"
echo "  ./logs.sh system     - System logs"
echo "  ./logs.sh app        - Application logs"
echo "  ./logs.sh errors     - Error logs only"
echo "  ./logs.sh follow     - Follow live logs"
echo "  ./logs.sh all        - All logs (default)"
