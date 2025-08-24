#!/bin/bash

# Claude AI Agent Recovery Script
# Handles automatic recovery from common issues

echo "========================================"
echo "Claude AI Agent - Emergency Recovery"
echo "========================================"
echo "Starting recovery process at $(date)"
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_FILE="/home/ubuntu/claude-ai-agent/logs/recovery.log"

print_status() {
    echo -e "${GREEN}[RECOVERY]${NC} $1"
    echo "$(date): $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date): WARNING - $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date): ERROR - $1" >> "$LOG_FILE"
}

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

print_status "Emergency recovery initiated"

# Function to check if process is responding
check_process_health() {
    local service_name=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    if curl -s --max-time 10 "http://localhost:$port$endpoint" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to restart service safely
restart_service() {
    local service_name=$1
    
    print_status "Restarting $service_name..."
    
    if pm2 show "$service_name" >/dev/null 2>&1; then
        pm2 restart "$service_name"
        sleep 3
        
        if pm2 show "$service_name" | grep -q "online"; then
            print_status "✅ $service_name restarted successfully"
            return 0
        else
            print_error "❌ $service_name restart failed"
            return 1
        fi
    else
        print_warning "$service_name not found in PM2"
        return 1
    fi
}

# 1. System Resource Check
print_status "Step 1: Checking system resources..."

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 95 ]; then
    print_warning "Critical disk space: ${DISK_USAGE}%"
    print_status "Attempting to free up space..."
    
    # Clean temporary files
    sudo rm -rf /tmp/* 2>/dev/null || true
    
    # Clean PM2 logs
    pm2 flush 2>/dev/null || true
    
    # Clean old log files
    find /home/ubuntu/claude-ai-agent/logs -name "*.log.*" -mtime +1 -delete 2>/dev/null || true
    
    # Clean package cache
    sudo apt-get clean 2>/dev/null || true
    
    NEW_DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    print_status "Disk usage after cleanup: ${NEW_DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
if [ "$MEMORY_USAGE" -gt 90 ]; then
    print_warning "High memory usage: ${MEMORY_USAGE}%"
    print_status "Attempting to free memory..."
    
    # Drop caches
    sudo sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    
    NEW_MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
    print_status "Memory usage after cleanup: ${NEW_MEMORY_USAGE}%"
fi

echo

# 2. Service Health Check and Recovery
print_status "Step 2: Checking service health..."

# Check Nginx
if ! systemctl is-active --quiet nginx; then
    print_warning "Nginx is not running"
    print_status "Attempting to start Nginx..."
    
    # Test configuration first
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl start nginx
        if systemctl is-active --quiet nginx; then
            print_status "✅ Nginx started successfully"
        else
            print_error "❌ Failed to start Nginx"
        fi
    else
        print_error "❌ Nginx configuration test failed"
        print_status "Attempting to fix Nginx configuration..."
        
        # Backup current config and create minimal working config
        sudo cp /etc/nginx/sites-available/claude-agent /etc/nginx/sites-available/claude-agent.backup.$(date +%s) 2>/dev/null || true
        
        sudo tee /etc/nginx/sites-available/claude-agent > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /health {
        proxy_pass http://localhost:8000/health;
    }
}
EOF
        
        if sudo nginx -t 2>/dev/null; then
            sudo systemctl start nginx
            print_status "✅ Nginx started with minimal configuration"
        else
            print_error "❌ Nginx recovery failed"
        fi
    fi
else
    print_status "✅ Nginx is running"
fi

# Check Backend Service
if ! check_process_health "backend" 8000 "/health"; then
    print_warning "Backend API is not responding"
    
    if ! restart_service "claude-backend"; then
        print_status "Attempting to start backend manually..."
        
        cd /home/ubuntu/claude-ai-agent/backend
        
        # Check if virtual environment exists
        if [ ! -d "venv" ]; then
            print_status "Creating Python virtual environment..."
            python3 -m venv venv
        fi
        
        source venv/bin/activate
        
        # Check if main.py exists
        if [ ! -f "main.py" ]; then
            print_status "Creating minimal backend application..."
            cat > main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Claude AI Agent", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "message": "Claude AI Agent is running",
        "recovery_mode": True
    }

@app.get("/")
async def root():
    return {"message": "Claude AI Agent API - Recovery Mode"}
EOF
        fi
        
        # Start with PM2
        pm2 delete claude-backend 2>/dev/null || true
        pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" --name claude-backend
        
        sleep 5
        
        if check_process_health "backend" 8000 "/health"; then
            print_status "✅ Backend recovered successfully"
        else
            print_error "❌ Backend recovery failed"
        fi
        
        cd - >/dev/null
    fi
else
    print_status "✅ Backend API is responding"
fi

# Check Frontend Service
if ! check_process_health "frontend" 3000; then
    print_warning "Frontend is not responding"
    
    if ! restart_service "claude-frontend"; then
        print_status "Attempting to start frontend manually..."
        
        cd /home/ubuntu/claude-ai-agent/frontend
        
        # Check if build directory exists
        if [ ! -d "build" ]; then
            # Check if package.json exists
            if [ -f "package.json" ]; then
                print_status "Building frontend..."
                npm run build 2>/dev/null || print_warning "Frontend build failed"
            else
                print_status "Creating minimal frontend..."
                mkdir -p build
                cat > build/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Claude AI Agent - Recovery Mode</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .status { color: #28a745; font-size: 24px; margin: 20px 0; }
        .message { color: #6c757d; font-size: 16px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Claude AI Agent</h1>
        <div class="status">🔧 Recovery Mode</div>
        <div class="message">
            The system is running in recovery mode. Core services are operational.
            <br><br>
            <a href="/health" target="_blank">Check API Health</a>
        </div>
    </div>
</body>
</html>
EOF
            fi
        fi
        
        # Start with PM2
        pm2 delete claude-frontend 2>/dev/null || true
        
        if [ -d "build" ]; then
            pm2 start "npx serve -s build -l 3000" --name claude-frontend
        else
            # Fallback to simple HTTP server
            pm2 start "python3 -m http.server 3000" --name claude-frontend
        fi
        
        sleep 5
        
        if check_process_health "frontend" 3000; then
            print_status "✅ Frontend recovered successfully"
        else
            print_error "❌ Frontend recovery failed"
        fi
        
        cd - >/dev/null
    fi
else
    print_status "✅ Frontend is responding"
fi

echo

# 3. Database Recovery
print_status "Step 3: Checking database integrity..."

DB_PATH="/home/ubuntu/claude-ai-agent/data/agent_database.db"

if [ -f "$DB_PATH" ]; then
    if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        print_status "✅ Database integrity check passed"
    else
        print_warning "Database integrity check failed"
        print_status "Attempting database recovery..."
        
        # Backup corrupted database
        BACKUP_PATH="/home/ubuntu/claude-ai-agent/backups/corrupted_$(date +%Y%m%d_%H%M%S).db"
        mkdir -p "$(dirname "$BACKUP_PATH")"
        cp "$DB_PATH" "$BACKUP_PATH"
        print_status "Corrupted database backed up to: $BACKUP_PATH"
        
        # Attempt recovery
        RECOVERED_PATH="/tmp/recovered_database.db"
        sqlite3 "$DB_PATH" ".recover $RECOVERED_PATH" 2>/dev/null || true
        
        if [ -f "$RECOVERED_PATH" ] && sqlite3 "$RECOVERED_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            mv "$RECOVERED_PATH" "$DB_PATH"
            print_status "✅ Database recovered successfully"
        else
            print_warning "Database recovery failed, creating new database"
            rm -f "$DB_PATH"
            
            # Create new database structure if database.py exists
            if [ -f "/home/ubuntu/claude-ai-agent/backend/database.py" ]; then
                cd /home/ubuntu/claude-ai-agent/backend
                source venv/bin/activate 2>/dev/null || true
                python -c "
try:
    from database import init_database
    init_database()
    print('✅ New database created')
except Exception as e:
    print(f'⚠️ Database creation failed: {e}')
" 2>/dev/null || print_warning "Could not create new database"
                cd - >/dev/null
            fi
        fi
    fi
else
    print_warning "Database file not found"
    mkdir -p "$(dirname "$DB_PATH")"
    
    # Create new database if possible
    if [ -f "/home/ubuntu/claude-ai-agent/backend/database.py" ]; then
        cd /home/ubuntu/claude-ai-agent/backend
        source venv/bin/activate 2>/dev/null || true
        python -c "
try:
    from database import init_database
    init_database()
    print('✅ New database created')
except Exception as e:
    print(f'⚠️ Database creation failed: {e}')
" 2>/dev/null || print_warning "Could not create new database"
        cd - >/dev/null
    fi
fi

echo

# 4. Configuration Check
print_status "Step 4: Validating configuration..."

# Check .env file
if [ ! -f "/home/ubuntu/claude-ai-agent/.env" ]; then
    print_warning ".env file not found"
    print_status "Creating default .env file..."
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "127.0.0.1")
    SECRET_KEY=$(openssl rand -hex 32)
    
    cat > /home/ubuntu/claude-ai-agent/.env << EOF
# Claude AI Agent Configuration
ANTHROPIC_API_KEY=your_anthropic_api_key_here
MODEL_NAME=claude-3-sonnet-20240229
MAX_TOKENS=1000
HOST=0.0.0.0
PORT=8000
DEBUG=False
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/agent_database.db
SECRET_KEY=$SECRET_KEY
STATIC_IP=$PUBLIC_IP
ALLOWED_ORIGINS=*
CORS_ENABLED=True
LOG_LEVEL=INFO
EOF
    
    chmod 600 /home/ubuntu/claude-ai-agent/.env
    print_status "✅ Default .env file created"
fi

# Check API key configuration
if ! grep -q "ANTHROPIC_API_KEY=sk-ant-" /home/ubuntu/claude-ai-agent/.env 2>/dev/null; then
    print_warning "Anthropic API key not configured"
    print_status "Please configure your API key in /home/ubuntu/claude-ai-agent/.env"
fi

echo

# 5. Save PM2 Configuration
print_status "Step 5: Saving PM2 configuration..."
pm2 save
pm2 startup | grep -E "sudo.*pm2" | sh 2>/dev/null || print_warning "PM2 startup configuration may need manual setup"

echo

# 6. Final Health Check
print_status "Step 6: Performing final health check..."

# Wait for services to stabilize
sleep 10

# Check all services
SERVICES_OK=true

# Nginx check
if systemctl is-active --quiet nginx; then
    print_status "✅ Nginx: Running"
else
    print_error "❌ Nginx: Not running"
    SERVICES_OK=false
fi

# Backend check
if check_process_health "backend" 8000 "/health"; then
    print_status "✅ Backend API: Responding"
else
    print_error "❌ Backend API: Not responding"
    SERVICES_OK=false
fi

# Frontend check
if check_process_health "frontend" 3000; then
    print_status "✅ Frontend: Responding"
else
    print_error "❌ Frontend: Not responding"
    SERVICES_OK=false
fi

# Database check
if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" >/dev/null 2>&1; then
    print_status "✅ Database: Accessible"
else
    print_warning "⚠️ Database: Issues detected"
fi

# Network connectivity check
if curl -s --max-time 10 http://localhost/ >/dev/null 2>&1; then
    print_status "✅ Full stack: Working"
else
    print_warning "⚠️ Full stack: Issues detected"
fi

echo

# 7. Recovery Summary
echo "========================================"
if [ "$SERVICES_OK" = true ]; then
    echo -e "${GREEN}✅ RECOVERY COMPLETED SUCCESSFULLY${NC}"
else
    echo -e "${YELLOW}⚠️ RECOVERY PARTIALLY COMPLETED${NC}"
fi
echo "========================================"
echo

print_status "Recovery Summary:"
echo "  🕐 Recovery Time: $(date)"
echo "  🔧 Actions Taken:"

if [ "$DISK_USAGE" -gt 95 ]; then
    echo "    • Cleaned up disk space"
fi

if [ "$MEMORY_USAGE" -gt 90 ]; then
    echo "    • Freed system memory"
fi

echo "    • Verified/restarted system services"
echo "    • Checked database integrity"
echo "    • Validated configuration files"
echo "    • Updated PM2 configuration"

echo
echo "  🌐 Access Points:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
echo "    • Main Site: http://$PUBLIC_IP"
echo "    • API Health: http://$PUBLIC_IP:8000/health"
echo "    • Direct Backend: http://$PUBLIC_IP:8000"
echo "    • Direct Frontend: http://$PUBLIC_IP:3000"

echo
if [ "$SERVICES_OK" = true ]; then
    echo -e "${GREEN}🎉 All services are now operational!${NC}"
else
    echo -e "${YELLOW}⚠️ Some issues remain. Check the following:${NC}"
    echo
    echo "  🔍 Troubleshooting Steps:"
    echo "    1. Check service logs: pm2 logs"
    echo "    2. Review system status: ./scripts/status.sh"
    echo "    3. Run health check: ./scripts/health-check.sh"
    echo "    4. Check configuration: nano /home/ubuntu/claude-ai-agent/.env"
    echo "    5. Restart specific service: pm2 restart <service-name>"
fi

echo
echo "  📋 Next Recommended Actions:"
echo "    • Configure your Anthropic API key if not already done"
echo "    • Run a full backup: ./scripts/backup.sh"
echo "    • Monitor system: ./scripts/monitor.sh"
echo "    • Review logs for any errors"

echo
echo "Recovery process completed at $(date)"
echo "$(date): Recovery process completed - Status: $([ "$SERVICES_OK" = true ] && echo "SUCCESS" || echo "PARTIAL")" >> "$LOG_FILE"

# Exit with appropriate code
if [ "$SERVICES_OK" = true ]; then
    exit 0
else
    exit 1
fi
