#!/bin/bash

# Claude AI Agent Ubuntu Deployment Script
# Version: FINAL v1.2 - Ubuntu Multi-Environment Support
# Works on Ubuntu 20.04/22.04 across AWS, GCP, Azure, local, and WSL

set -e  # Exit on any error
set -u  # Exit on undefined variables

echo "========================================"
echo "Claude AI Agent - Ubuntu Deploy"
echo "========================================"
echo "Starting Ubuntu deployment at $(date)"
echo

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Initialize Ubuntu environment variables
CLOUD_PROVIDER=""
UBUNTU_VERSION=""
UBUNTU_CODENAME=""
CURRENT_USER=""
PUBLIC_IP=""
INSTANCE_ID=""
UBUNTU_TYPE=""

# Function to print colored output and log
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$(date): INFO - $1" >> "$LOG_FILE"
    fi
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$(date): WARNING - $1" >> "$LOG_FILE"
    fi
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$(date): ERROR - $1" >> "$LOG_FILE"
    fi
    exit 1
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$(date): DEBUG - $1" >> "$LOG_FILE"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Ubuntu environment
detect_ubuntu_environment() {
    print_status "Detecting Ubuntu environment..."
    
    # Verify this is Ubuntu
    if [ ! -f /etc/os-release ]; then
        print_error "This deployment script requires Ubuntu 20.04 or 22.04"
    fi
    
    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        print_error "This script is designed for Ubuntu systems. Detected: $ID"
    fi
    
    UBUNTU_VERSION="$VERSION_ID"
    UBUNTU_CODENAME="$VERSION_CODENAME"
    CURRENT_USER=$(whoami)
    
    # Verify Ubuntu version
    local version_major=$(echo "$UBUNTU_VERSION" | cut -d. -f1)
    if [ "$version_major" -ne 20 ] && [ "$version_major" -ne 22 ]; then
        print_error "Unsupported Ubuntu version: $UBUNTU_VERSION. This script requires Ubuntu 20.04 LTS or Ubuntu 22.04 LTS."
    fi
    
    # Detect cloud provider
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        CLOUD_PROVIDER="aws"
        PUBLIC_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
    elif curl -s --max-time 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id >/dev/null 2>&1; then
        CLOUD_PROVIDER="gcp"
        PUBLIC_IP=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id 2>/dev/null || echo "unknown")
    elif curl -s --max-time 3 -H "Metadata:true" http://169.254.169.254/metadata/instance?api-version=2021-02-01 >/dev/null 2>&1; then
        CLOUD_PROVIDER="azure"
        PUBLIC_IP=$(curl -s --max-time 5 -H "Metadata:true" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID=$(curl -s --max-time 5 -H "Metadata:true" "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2021-02-01&format=text" 2>/dev/null || echo "unknown")
    elif grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
        CLOUD_PROVIDER="wsl"
        PUBLIC_IP="127.0.0.1"
        INSTANCE_ID="wsl-ubuntu"
    else
        CLOUD_PROVIDER="local"
        PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
        INSTANCE_ID="local-ubuntu"
    fi
    
    # Determine Ubuntu type
    if [ "$CLOUD_PROVIDER" != "local" ] && [ "$CLOUD_PROVIDER" != "wsl" ]; then
        UBUNTU_TYPE="cloud-ubuntu"
    elif [ "$CLOUD_PROVIDER" = "wsl" ]; then
        UBUNTU_TYPE="wsl-ubuntu"
    else
        UBUNTU_TYPE="local-ubuntu"
    fi
    
    print_status "✅ Ubuntu environment: $UBUNTU_VERSION ($UBUNTU_CODENAME) on $CLOUD_PROVIDER"
}

# Function to setup Ubuntu logging
setup_ubuntu_logging() {
    mkdir -p "$PROJECT_ROOT/logs"
    LOG_FILE="$PROJECT_ROOT/logs/ubuntu-deployment.log"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    print_status "Logging to: $LOG_FILE"
}

# Function to check Ubuntu project directory
check_ubuntu_project_directory() {
    if [ ! -f "$PROJECT_ROOT/.env" ] || [ ! -d "$PROJECT_ROOT/backend" ] || [ ! -d "$PROJECT_ROOT/frontend" ]; then
        print_error "Not in Claude AI agent project directory. Required files/directories missing:
        - .env file
        - backend/ directory  
        - frontend/ directory
        
        Current directory: $PROJECT_ROOT
        Please run this script from the claude-ai-agent project root."
    fi
    
    print_status "Project directory validation passed"
}

# Function to validate Ubuntu configuration
validate_ubuntu_configuration() {
    print_status "Validating Ubuntu configuration..."
    
    # Check if .env file exists and is readable
    if [ ! -r "$PROJECT_ROOT/.env" ]; then
        print_error ".env file not found or not readable at: $PROJECT_ROOT/.env"
    fi
    
    # Source the .env file safely
    set +u  # Temporarily allow undefined variables
    if ! source "$PROJECT_ROOT/.env"; then
        print_error "Failed to source .env file. Check for syntax errors."
    fi
    set -u
    
    # Check API key configuration
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        print_error "ANTHROPIC_API_KEY not found in .env file"
    fi
    
    if [ "$ANTHROPIC_API_KEY" = "your_anthropic_api_key_here" ]; then
        print_error "Anthropic API key not configured. Please edit .env file and add your API key.
        
        To get an API key:
        1. Visit: https://console.anthropic.com/
        2. Create an account or sign in
        3. Generate a new API key
        4. Replace 'your_anthropic_api_key_here' in .env with your actual key"
    fi
    
    # Validate API key format
    if [[ ! "$ANTHROPIC_API_KEY" =~ ^sk-ant- ]]; then
        print_error "Invalid Anthropic API key format. Key should start with 'sk-ant-'"
    fi
    
    print_status "✅ Configuration validation passed"
}

# Function to check if a process is running
check_process() {
    local process_name="$1"
    if command_exists pm2; then
        pm2 describe "$process_name" >/dev/null 2>&1
    else
        return 1
    fi
}

# Function to stop existing Ubuntu services
stop_ubuntu_services() {
    print_status "Stopping existing Ubuntu services..."
    
    if command_exists pm2; then
        # Stop existing PM2 processes
        if check_process "claude-backend"; then
            print_status "Stopping existing backend service..."
            pm2 stop claude-backend >/dev/null 2>&1 || true
        fi
        
        if check_process "claude-frontend"; then
            print_status "Stopping existing frontend service..."
            pm2 stop claude-frontend >/dev/null 2>&1 || true
        fi
    fi
    
    # Give services time to stop gracefully
    sleep 2
    
    print_status "Services stopped"
}

# Function to setup Ubuntu backend
setup_ubuntu_backend() {
    print_status "Setting up Ubuntu backend..."
    
    # Change to backend directory
    if ! cd "$PROJECT_ROOT/backend"; then
        print_error "Failed to change to Ubuntu backend directory"
    fi
    
    # Check if Python virtual environment exists
    if [ ! -d "venv" ]; then
        print_status "Creating Python virtual environment..."
        if ! python3 -m venv venv; then
            print_error "Failed to create Python virtual environment"
        fi
    fi
    
    # Activate virtual environment
    set +u
    if ! source venv/bin/activate; then
        print_error "Failed to activate Python virtual environment"
    fi
    set -u
    
    # Upgrade pip
    print_status "Upgrading pip..."
    python -m pip install --upgrade pip >/dev/null 2>&1 || print_warning "Failed to upgrade pip, but continuing..."
    
    # Install Python dependencies
    if [ -f "requirements.txt" ]; then
        print_status "Installing Python dependencies..."
        if ! pip install -r requirements.txt; then
            print_error "Failed to install Python dependencies on Ubuntu"
        fi
    else
        print_warning "requirements.txt not found on Ubuntu, skipping dependency installation"
    fi
    
    # Verify main application file exists
    if [ ! -f "main.py" ]; then
        print_error "main.py not found in Ubuntu backend directory. Please run setup.sh first."
    fi
    
    # Test Ubuntu backend configuration
    print_status "Testing Ubuntu backend configuration..."
    if ! python -c "
import os
from dotenv import load_dotenv
load_dotenv()

# Test API key
api_key = os.getenv('ANTHROPIC_API_KEY', '')
if not api_key or api_key == 'your_anthropic_api_key_here':
    print('ERROR: API key not configured on Ubuntu')
    exit(1)

if not api_key.startswith('sk-ant-'):
    print('ERROR: Invalid API key format on Ubuntu')
    exit(1)

print('✅ Ubuntu configuration test passed')
"; then
        print_error "Ubuntu backend configuration test failed"
    fi
    
    # Initialize Ubuntu database if database.py exists
    if [ -f "database.py" ]; then
        print_status "Initializing Ubuntu database..."
        if ! python -c "
try:
    from database import init_database
    init_database()
    print('✅ Ubuntu database initialized successfully')
except ImportError:
    print('⚠️ Database module not found on Ubuntu, skipping initialization')
except Exception as e:
    print(f'⚠️ Ubuntu database initialization failed: {e}')
"; then
            print_warning "Ubuntu database initialization encountered issues, but continuing..."
        fi
    else
        print_debug "database.py not found on Ubuntu, skipping database initialization"
    fi
    
    # Return to project root
    cd "$PROJECT_ROOT" || print_error "Failed to return to Ubuntu project root directory"
    
    print_status "✅ Ubuntu backend setup completed"
}

# Function to setup Ubuntu frontend
setup_ubuntu_frontend() {
    print_status "Setting up Ubuntu frontend..."
    
    cd "$PROJECT_ROOT/frontend" || print_error "Failed to change to Ubuntu frontend directory"
    
    # Check if Node.js is available
    if ! command_exists node || ! command_exists npm; then
        print_error "Node.js or npm not found on Ubuntu. Please run setup.sh first."
    fi
    
    # Check Ubuntu Node.js version
    local node_version
    node_version=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$node_version" -lt 16 ]; then
        print_error "Node.js version too old on Ubuntu: $(node --version). Minimum required: v16"
    fi
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        print_warning "package.json not found on Ubuntu. Creating React application..."
        
        # Create React app with TypeScript template
        if ! npx create-react-app . --template typescript --skip-git; then
            print_error "Failed to create React application on Ubuntu"
        fi
    else
        print_status "package.json found on Ubuntu, using existing React application"
    fi
    
    # Install Ubuntu dependencies
    if [ -f "package.json" ]; then
        print_status "Installing Node.js dependencies on Ubuntu..."
        
        # Clean install to avoid conflicts
        if [ -d "node_modules" ]; then
            print_status "Cleaning existing node_modules on Ubuntu..."
            rm -rf node_modules package-lock.json
        fi
        
        if ! npm install; then
            print_error "Failed to install Node.js dependencies on Ubuntu"
        fi
        
        # Install additional dependencies for Claude integration
        print_status "Installing additional dependencies on Ubuntu..."
        local additional_deps=(
            "@mui/material" "@emotion/react" "@emotion/styled"
            "@mui/icons-material" "axios"
        )
        
        if ! npm install "${additional_deps[@]}"; then
            print_warning "Failed to install some additional dependencies on Ubuntu, but continuing..."
        fi
    else
        print_error "package.json still not found after React app creation on Ubuntu"
    fi
    
    # Build Ubuntu frontend application
    print_status "Building frontend application on Ubuntu..."
    if [ -f "package.json" ]; then
        # Set environment variables for Ubuntu build
        export GENERATE_SOURCEMAP=false
        export CI=false
        
        if ! npm run build; then
            print_error "Frontend build failed on Ubuntu"
        fi
        
        # Verify build directory was created
        if [ ! -d "build" ]; then
            print_error "Build directory not created on Ubuntu. Frontend build may have failed silently."
        fi
        
        # Check Ubuntu build contents
        if [ ! -f "build/index.html" ]; then
            print_error "Frontend build incomplete on Ubuntu. index.html not found in build directory."
        fi
        
        print_status "✅ Ubuntu frontend build completed successfully"
    else
        print_warning "Skipping Ubuntu frontend build - no package.json found"
    fi
    
    # Return to project root
    cd "$PROJECT_ROOT" || print_error "Failed to return to Ubuntu project root directory"
    
    print_status "✅ Ubuntu frontend setup completed"
}

# Function to configure and test Ubuntu Nginx
configure_ubuntu_nginx() {
    print_status "Configuring Ubuntu Nginx..."
    
    # Check if Nginx is installed
    if ! command_exists nginx; then
        print_error "Nginx not found on Ubuntu. Please run setup.sh first."
    fi
    
    # Create Ubuntu Nginx configuration
    local nginx_config="/etc/nginx/sites-available/claude-agent"
    
    print_status "Creating Ubuntu Nginx configuration..."
    sudo tee "$nginx_config" > /dev/null << EOF
server {
    listen 80;
    server_name localhost $(hostname -f 2>/dev/null || echo "_");
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Frontend (React app)
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Backend API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
        
        # Rate limiting
        limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
        limit_req zone=api burst=20 nodelay;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8000/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static files
    location /static {
        alias $PROJECT_ROOT/frontend/build/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Security: Block access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ \.env {
        deny all;
    }
}
EOF
    
    # Test current Ubuntu Nginx configuration
    if ! sudo nginx -t; then
        print_error "Current Ubuntu Nginx configuration is invalid. Please check:
        - /etc/nginx/nginx.conf
        - /etc/nginx/sites-available/claude-agent
        
        You may need to run setup.sh again or manually fix the Ubuntu configuration."
    fi
    
    # Check if our Ubuntu site is enabled
    if [ ! -L /etc/nginx/sites-enabled/claude-agent ]; then
        print_warning "Claude agent site not enabled on Ubuntu. Enabling now..."
        if [ -f /etc/nginx/sites-available/claude-agent ]; then
            if ! sudo ln -s /etc/nginx/sites-available/claude-agent /etc/nginx/sites-enabled/; then
                print_error "Failed to enable Ubuntu Nginx site"
            fi
        else
            print_error "Ubuntu Nginx site configuration not found. Please run setup.sh first."
        fi
    fi
    
    # Disable default site
    if [ -L /etc/nginx/sites-enabled/default ]; then
        print_status "Disabling default Ubuntu Nginx site..."
        sudo rm -f /etc/nginx/sites-enabled/default
    fi
    
    # Restart Ubuntu Nginx
    print_status "Restarting Ubuntu Nginx..."
    if ! sudo systemctl restart nginx; then
        print_error "Failed to restart Ubuntu Nginx. Check system logs:
        sudo journalctl -u nginx -n 20"
    fi
    
    # Verify Ubuntu Nginx is running
    if ! sudo systemctl is-active --quiet nginx; then
        print_error "Ubuntu Nginx failed to start. Check status:
        sudo systemctl status nginx"
    fi
    
    # Log to Ubuntu syslog
    logger "Claude AI Agent Ubuntu Nginx configured and restarted"
    
    print_status "✅ Ubuntu Nginx configuration completed"
}

# Function to start Ubuntu backend service
start_ubuntu_backend() {
    print_status "Starting Ubuntu backend service..."
    
    # Change to backend directory
    cd "$PROJECT_ROOT/backend" || print_error "Failed to change to Ubuntu backend directory"
    
    # Activate virtual environment
    set +u
    if ! source venv/bin/activate; then
        print_error "Failed to activate Python virtual environment"
    fi
    set -u
    
    # Start or restart backend with PM2
    local backend_cmd="uvicorn main:app --host ${HOST:-0.0.0.0} --port ${PORT:-8000}"
    
    if check_process "claude-backend"; then
        print_status "Restarting existing Ubuntu backend service..."
        if ! pm2 restart claude-backend; then
            print_error "Failed to restart Ubuntu backend service"
        fi
    else
        print_status "Starting new Ubuntu backend service..."
        if ! pm2 start "$backend_cmd" \
            --name claude-backend \
            --watch \
            --ignore-watch="logs data node_modules __pycache__" \
            --max-memory-restart 500M \
            --time \
            --log-date-format="YYYY-MM-DD HH:mm:ss"; then
            print_error "Failed to start Ubuntu backend service with PM2"
        fi
    fi
    
    # Return to project root
    cd "$PROJECT_ROOT" || print_error "Failed to return to Ubuntu project root"
    
    print_status "✅ Ubuntu backend service started"
}

# Function to start Ubuntu frontend service
start_ubuntu_frontend() {
    print_status "Starting Ubuntu frontend service..."
    
    # Change to frontend directory
    cd "$PROJECT_ROOT/frontend" || print_error "Failed to change to Ubuntu frontend directory"
    
    # Determine frontend serving strategy for Ubuntu
    local frontend_cmd
    if [ -d "build" ] && [ -f "build/index.html" ]; then
        print_status "Using Ubuntu production build"
        frontend_cmd="npx serve -s build -l 3000"
    elif [ -f "package.json" ]; then
        print_warning "Build directory not found on Ubuntu, using development server"
        frontend_cmd="npm start"
    else
        print_error "No valid frontend configuration found on Ubuntu"
    fi
    
    # Start or restart frontend with PM2
    if check_process "claude-frontend"; then
        print_status "Restarting existing Ubuntu frontend service..."
        if ! pm2 restart claude-frontend; then
            print_error "Failed to restart Ubuntu frontend service"
        fi
    else
        print_status "Starting new Ubuntu frontend service..."
        if ! pm2 start "$frontend_cmd" \
            --name claude-frontend \
            --max-memory-restart 300M \
            --time \
            --log-date-format="YYYY-MM-DD HH:mm:ss"; then
            print_error "Failed to start Ubuntu frontend service with PM2"
        fi
    fi
    
    # Return to project root
    cd "$PROJECT_ROOT" || print_error "Failed to return to Ubuntu project root"
    
    print_status "✅ Ubuntu frontend service started"
}

# Function to save Ubuntu PM2 configuration
save_ubuntu_pm2_configuration() {
    print_status "Saving Ubuntu PM2 configuration..."
    
    # Save current PM2 processes
    if command_exists pm2; then
        if ! pm2 save; then
            print_warning "Failed to save Ubuntu PM2 configuration, but continuing..."
        else
            print_status "✅ Ubuntu PM2 configuration saved"
        fi
    fi
}

# Function to perform Ubuntu health checks
perform_ubuntu_health_checks() {
    print_status "Performing Ubuntu health checks..."
    
    local health_score=0
    local max_score=4
    
    # Check backend health
    print_status "Checking Ubuntu backend health..."
    if curl -s --max-time 10 http://localhost:8000/health >/dev/null 2>&1; then
        print_status "✅ Backend API responding"
        health_score=$((health_score + 1))
    else
        print_warning "❌ Backend API not responding"
    fi
    
    # Check frontend health
    print_status "Checking Ubuntu frontend health..."
    if curl -s --max-time 10 http://localhost:3000 >/dev/null 2>&1; then
        print_status "✅ Frontend accessible"
        health_score=$((health_score + 1))
    else
        print_warning "❌ Frontend not accessible"
    fi
    
    # Check Nginx health
    print_status "Checking Ubuntu Nginx health..."
    if systemctl is-active --quiet nginx; then
        print_status "✅ Nginx running"
        health_score=$((health_score + 1))
    else
        print_warning "❌ Nginx not running"
    fi
    
    # Check PM2 processes
    print_status "Checking Ubuntu PM2 processes..."
    if command_exists pm2 && pm2 describe claude-backend >/dev/null 2>&1 && pm2 describe claude-frontend >/dev/null 2>&1; then
        print_status "✅ PM2 processes running"
        health_score=$((health_score + 1))
    else
        print_warning "❌ Some PM2 processes not running"
    fi
    
    print_status "Ubuntu Health Score: $health_score/$max_score"
    
    if [ $health_score -eq $max_score ]; then
        print_status "✅ All Ubuntu health checks passed"
        return 0
    elif [ $health_score -ge 2 ]; then
        print_warning "⚠️ Ubuntu deployment partially healthy ($health_score/$max_score)"
        return 0
    else
        print_error "❌ Ubuntu deployment health checks failed ($health_score/$max_score)"
        return 1
    fi
}

# Function to show Ubuntu service status
show_ubuntu_service_status() {
    print_status "Ubuntu Service Status:"
    
    echo
    if command_exists pm2; then
        echo "PM2 Processes:"
        pm2 status 2>/dev/null || echo "No PM2 processes running"
    fi
    
    echo
    echo "System Services:"
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx: Running"
    else
        echo "❌ Nginx: Not running"
    fi
    
    echo
    echo "System Resources:"
    if command_exists free; then
        echo "Memory: $(free -h | awk '/^Mem:/ {print $3"/"$2" ("$3/$2*100"%)"}')"
    fi
    if command_exists df; then
        echo "Disk: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')"
    fi
}

# Function to show Ubuntu access information
show_ubuntu_access_information() {
    echo
    echo "========================================"
    echo "✅ Ubuntu Deployment Completed Successfully!"
    echo "========================================"
    echo
    echo "🐧 Ubuntu Environment:"
    echo "   Ubuntu Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "   Cloud Provider: $CLOUD_PROVIDER"
    echo "   Ubuntu Type: $UBUNTU_TYPE"
    echo "   Current User: $CURRENT_USER"
    echo
    echo "🌐 Access your Ubuntu Claude AI Agent:"
    if [ "$PUBLIC_IP" != "127.0.0.1" ] && [ "$PUBLIC_IP" != "localhost" ]; then
        echo "   External: http://$PUBLIC_IP"
    fi
    echo "   Local: http://localhost"
    echo "   Direct Backend: http://localhost:8000/health"
    echo "   Direct Frontend: http://localhost:3000"
    echo
    echo "📋 Ubuntu Management Commands:"
    echo "   pm2 status                    # Check Ubuntu service status"
    echo "   pm2 logs                      # View Ubuntu application logs"
    echo "   pm2 restart all               # Restart Ubuntu services"
    echo "   sudo systemctl status nginx   # Check Ubuntu Nginx status"
    echo "   sudo journalctl -u nginx -f   # Follow Ubuntu Nginx logs"
    echo
    echo "🔧 Next Ubuntu steps:"
    echo "   1. Test your Ubuntu deployment in a web browser"
    echo "   2. Check Ubuntu logs if issues: pm2 logs"
    echo "   3. Set up Ubuntu monitoring: ./scripts/monitor.sh"
    echo "   4. Configure Ubuntu SSL for production use"
    echo "   5. Set up Ubuntu domain name (optional)"
    echo "   6. Enable Ubuntu automated backups"
    echo
    echo "🔒 Ubuntu Security:"
    if command_exists ufw; then
        echo "   UFW Firewall: $(sudo ufw status | head -1 | cut -d' ' -f2)"
    fi
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo "   fail2ban: Active"
    fi
    echo
    echo "Ubuntu deployment completed at $(date)"
    echo "Ubuntu system logs: journalctl -u nginx -f"
}

# Main Ubuntu deployment function
main() {
    print_status "Starting Claude AI Agent Ubuntu deployment"
    
    # Detect Ubuntu environment first
    detect_ubuntu_environment
    setup_ubuntu_logging
    
    # Validate Ubuntu environment
    check_ubuntu_project_directory
    validate_ubuntu_configuration
    
    # Stop existing Ubuntu services
    stop_ubuntu_services
    
    # Setup Ubuntu components
    setup_ubuntu_backend
    setup_ubuntu_frontend
    configure_ubuntu_nginx
    
    # Start Ubuntu services
    start_ubuntu_backend
    start_ubuntu_frontend
    save_ubuntu_pm2_configuration
    
    # Validate Ubuntu deployment
    if perform_ubuntu_health_checks; then
        show_ubuntu_service_status
        show_ubuntu_access_information
        print_status "✅ Ubuntu deployment completed successfully"
        logger "Claude AI Agent Ubuntu deployment completed successfully"
        echo "$(date): Ubuntu deployment completed successfully" >> "$LOG_FILE"
    else
        print_error "Ubuntu deployment completed with issues. Please check the logs and service status."
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
