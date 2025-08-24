#!/bin/bash

# Claude AI Agent - Quick Status Script
# Provides rapid system overview

echo "=== Claude AI Agent Status ==="
echo "Time: $(date)"
echo

echo "PM2 Processes:"
pm2 status 2>/dev/null || echo "PM2 not available or no processes running"
echo

echo "System Resources:"
if command -v free >/dev/null; then
    echo "Memory: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
fi
if command -v df >/dev/null; then
    echo "Disk: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')"
fi

echo

echo "Service Status:"
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx: Running"
else
    echo "❌ Nginx: Not running"
fi

echo

echo "API Health:"
if curl -s --max-time 5 http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ Backend API: Responding"
else
    echo "❌ Backend API: Not responding"
fi

if curl -s --max-time 5 http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Frontend: Accessible"
else
    echo "❌ Frontend: Not accessible"
fi

echo
echo "Quick Status Complete"
