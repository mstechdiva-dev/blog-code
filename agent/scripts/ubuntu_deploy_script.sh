#!/bin/bash

# Claude AI Agent Ubuntu Universal Deployment Script
# Version: FINAL v1.2 - Ubuntu Universal
# Works on Ubuntu 20.04/22.04 across AWS, GCP, Azure, local, and WSL

set -e  # Exit on any error
set -u  # Exit on undefined variables

echo "========================================"
echo "Claude AI Agent - Ubuntu Universal Deploy"
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
        print_error "Unsupported Ubuntu version: $UBUNTU_VERSION. Required: 20.04 or 22.04"
    fi
    
    # Detect cloud provider
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        CLOUD_PROVIDER="aws"
        PUBLIC_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "127.0.0.1")
    elif curl -s --max-time 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id >/dev/null 2>&1; then
        CLOUD_PROVIDER="gcp"
        PUBLIC_IP=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "127.0.0.1")
    elif curl -s --max-time 3 -H "Metadata:true" http://169.254.169.254/metadata/instance?api-version=2021-02-01 >/dev/null 2>&1; then
        CLOUD_PROVIDER="azure"
        PUBLIC_IP=$(curl -s --max-time 5 -H "Metadata:true" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "127.0.0.1")
    elif grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
        CLOUD_PROVIDER="wsl"
        PUBLIC_IP="127.0.0.1"
    else
        CLOUD_PROVIDER="local"
        PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "127.0.0.1")
    fi
    
    # Determine Ubuntu type
    if [ "$CLOUD_PROVIDER" != "local" ] && [ "$CLOUD_PROVIDER" != "wsl" ]; then
        UBUNTU_TYPE="cloud-ubuntu"
    elif [ "$CLOUD_PROVIDER" = "wsl" ]; then
        UBUNTU_TYPE="wsl-ubuntu"
    else
        UBUNTU_TYPE="local-ubuntu"
    fi
    
    print_status "✅ Ubuntu environment detected:"
    print_status "   Ubuntu: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    print_status "   Cloud: $CLOUD_PROVIDER"
    print_status "   Type: $UBUNTU_TYPE"
    print_status "   User: $CURRENT_USER"
    print_status "   IP: $PUBLIC_IP"
}

# Function to setup logging for Ubuntu
setup_ubuntu_logging() {
    mkdir -p "$PROJECT_ROOT/logs"
    LOG_FILE="$PROJECT_ROOT/logs/ubuntu-deployment.log"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Log to Ubuntu syslog as well
    logger "Claude AI Agent Ubuntu deployment started by $CURRENT_USER"
}

# Function to check if Ubuntu project directory is correct
check_ubuntu_project_directory() {
    if [ ! -f "$PROJECT_ROOT/.env" ] || [ ! -d "$PROJECT_ROOT/backend" ] || [ ! -d "$PROJECT_ROOT/frontend" ]; then
        print_error "Not in Claude AI agent Ubuntu project directory. Required files/directories missing:
        - .env file
        - backend/ directory  
        - frontend/ directory
        
        Current directory: $PROJECT_ROOT
        Please run this script from the claude-ai-agent project root."
    fi
    
    print_status "✅ Ubuntu project directory validation passed"
}

# Function to validate Ubuntu configuration
validate_ubuntu_configuration() {
    print_status "Validating Ubuntu configuration..."
    
    # Check if .env file exists and is readable
    if [ ! -r "$PROJECT_ROOT/.env" ]; then
        print_error "Ubuntu .env file not found or not readable at: $PROJECT_ROOT/.env"
    fi
    
    # Source the .env file safely
    set +u  # Temporarily allow undefined variables
    if ! source "$PROJECT_ROOT/.env"; then
        print_error "Failed to source Ubuntu .env file. Check for syntax errors."
    fi
    set -u
    
    # Check API key configuration
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        print_error "ANTHROPIC_API_KEY not found in Ubuntu .env file"
    fi
    
    if [ "$ANTHROPIC_API_KEY" = "your_anthropic_api_key_here" ]; then
        print_error "Anthropic API key not configured in Ubuntu .env file.
        
        To get an API key:
        1. Visit: https://console.anthropic.com/
        2. Create an account or sign in
        3. Generate a new API key
        4. Replace 'your_anthropic_api_key_here' in .env file"
    fi
    
    if [[ ! "$ANTHROPIC_API_KEY" =~ ^sk-ant- ]]; then
        print_error "Invalid Anthropic API key format in Ubuntu .env. Key should start with 'sk-ant-'"
    fi
    
    # Validate other critical Ubuntu configurations
    if [ -z "${PORT:-}" ]; then
        print_warning "PORT not specified in Ubuntu .env, using default 8000"
        export PORT=8000
    fi
    
    if [ -z "${HOST:-}" ]; then
        print_warning "HOST not specified in Ubuntu .env, using default 0.0.0.0"
        export HOST="0.0.0.0"
    fi
    
    print_status "✅ Ubuntu configuration validation passed"
}

# Function to check if Ubuntu process is running
check_ubuntu_process() {
    local process_name="$1"
    if ! command_exists pm2; then
        print_error "PM2 not found on Ubuntu. Please run setup.sh first."
    fi
    
    pm2 show "$process_name" >/dev/null 2>&1
}

# Function to stop Ubuntu services safely
stop_ubuntu_services() {
    print_status "Stopping existing Ubuntu services..."
    
    local services=("claude-backend" "claude-frontend")
    for service in "${services[@]}"; do
        if check_ubuntu_process "$service"; then
            print_status "Stopping Ubuntu $service..."
            if ! pm2 stop "$service"; then
                print_warning "Failed to stop Ubuntu $service, but continuing..."
            fi
        else
            print_debug "Ubuntu $service not running"
        fi
    done
    
    # Log to Ubuntu syslog
    logger "Claude AI Agent Ubuntu services stopped for deployment"
}

# Function to validate and setup Ubuntu backend
setup_ubuntu_backend() {
    print_status "Setting up Ubuntu backend..."
    
    cd "$PROJECT_ROOT/backend" || print_error "Failed to change to Ubuntu backend directory"
    
    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        print_error "Python virtual environment not found on Ubuntu. Please run setup.sh first.
        
        Expected location: $PROJECT_ROOT/backend/venv"
    fi
    
    # Activate virtual environment
    print_status "Activating Python virtual environment on Ubuntu..."
    set +u  # Allow undefined variables during source
    if ! source venv/bin/activate; then
        print_error "Failed to activate Python virtual environment on Ubuntu"
    fi
    set -u
    
    # Verify Ubuntu Python environment
    if ! python -c "import sys; print(f'Python: {sys.version}')" 2>/dev/null; then
        print_error "Python virtual environment is corrupted on Ubuntu"
    fi
    
    # Install/update dependencies if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        print_status "Installing/updating Python dependencies on Ubuntu..."
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
        print_error "Failed to activate Python virtual environment on Ubuntu"
    fi
    set -u
    
    # Start or restart Ubuntu backend with PM2
    local backend_cmd="uvicorn main:app --host ${HOST:-0.0.0.0} --port ${PORT:-8000}"
    
    if check_ubuntu_process "claude-backend"; then
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
    
    # Log to Ubuntu syslog
    logger "Claude AI Agent Ubuntu backend service started"
    
    print_status "✅ Ubuntu backend service started"
}

# Function to start Ubuntu frontend service
start_ubuntu_frontend() {
    print_status "Starting Ubuntu frontend service..."
    
    # Change to frontend directory
    cd "$PROJECT_ROOT/frontend" || print_error "Failed to change to Ubuntu frontend directory"
    
    # Determine Ubuntu frontend serving strategy
    local frontend_cmd
    if [ -d "build" ] && [ -f "build/index.html" ]; then
        print_status "Using production build on Ubuntu"
        frontend_cmd="npx serve -s build -l 3000"
    elif [ -f "package.json" ]; then
        print_warning "Build directory not found on Ubuntu, using development server"
        frontend_cmd="npm start"
    else
        print_error "No valid frontend configuration found on Ubuntu"
    fi
    
    # Start or restart Ubuntu frontend with PM2
    if check_ubuntu_process "claude-frontend"; then
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
    
    # Log to Ubuntu syslog
    logger "Claude AI Agent Ubuntu frontend service started"
    
    print_status "✅ Ubuntu frontend service started"
}

# Function to save Ubuntu PM2 configuration
save_ubuntu_pm2_configuration() {
    print_status "Saving Ubuntu PM2 configuration..."
    
    if ! pm2 save; then
        print_warning "Failed to save Ubuntu PM2 configuration, but continuing..."
    fi
    
    # Setup Ubuntu PM2 startup script
    print_status "Setting up Ubuntu PM2 startup configuration..."
    local startup_cmd
    startup_cmd=$(pm2 startup | grep "sudo" | head -1)
    
    if [ -n "$startup_cmd" ]; then
        print_status "Ubuntu PM2 startup command generated. Executing automatically..."
        
        # Try to execute it
        if eval "$startup_cmd" 2>/dev/null; then
            print_status "✅ Ubuntu PM2 startup configuration completed"
            logger "Claude AI Agent Ubuntu PM2 startup configured"
        else
            print_warning "Ubuntu PM2 startup configuration may need manual setup"
            print_status "If needed, run manually: $startup_cmd"
        fi
    fi
}

# Function to perform Ubuntu health checks
perform_ubuntu_health_checks() {
    print_status "Performing Ubuntu health checks..."
    
    # Wait for Ubuntu services to stabilize
    print_status "Waiting for Ubuntu services to start..."
    sleep 10
    
    local health_ok=true
    
    # Check Ubuntu backend health
    print_status "Checking Ubuntu backend health..."
    local backend_check
    backend_check=$(curl -s --max-time 10 "http://localhost:${PORT:-8000}/health" 2>/dev/null || echo "failed")
    
    if [[ "$backend_check" == *"healthy"* ]]; then
        print_status "✅ Ubuntu backend health check passed"
        
        # Check if it shows Ubuntu info
        if [[ "$backend_check" == *"ubuntu"* ]]; then
            print_status "✅ Ubuntu backend reporting Ubuntu system info"
        fi
    else
        print_error "❌ Ubuntu backend health check failed. Check logs: pm2 logs claude-backend"
        health_ok=false
    fi
    
    # Check Ubuntu frontend health
    print_status "Checking Ubuntu frontend health..."
    local frontend_check
    frontend_check=$(curl -s --max-time 10 "http://localhost:3000" 2>/dev/null || echo "failed")
    
    if [[ "$frontend_check" != "failed" ]]; then
        print_status "✅ Ubuntu frontend health check passed"
    else
        print_warning "⚠️ Ubuntu frontend health check failed. Check logs: pm2 logs claude-frontend"
        health_ok=false
    fi
    
    # Check Ubuntu Nginx proxy
    print_status "Checking Ubuntu Nginx proxy..."
    local nginx_check
    nginx_check=$(curl -s --max-time 10 "http://localhost/" 2>/dev/null || echo "failed")
    
    if [[ "$nginx_check" != "failed" ]]; then
        print_status "✅ Ubuntu Nginx proxy health check passed"
    else
        print_warning "⚠️ Ubuntu Nginx proxy health check failed"
        health_ok=false
    fi
    
    # Test Ubuntu API endpoint specifically
    print_status "Testing Ubuntu API endpoint..."
    local api_check
    api_check=$(curl -s --max-time 10 "http://localhost/api/status" 2>/dev/null || echo "failed")
    
    if [[ "$api_check" != "failed" ]]; then
        print_status "✅ Ubuntu API endpoint test passed"
    else
        print_warning "⚠️ Ubuntu API endpoint test failed"
    fi
    
    # Check Ubuntu system services
    print_status "Checking Ubuntu system services..."
    if systemctl is-active --quiet nginx; then
        print_status "✅ Ubuntu Nginx systemd service active"
    else
        print_warning "⚠️ Ubuntu Nginx systemd service not active"
        health_ok=false
    fi
    
    if systemctl is-active --quiet ufw 2>/dev/null; then
        print_status "✅ Ubuntu UFW firewall service active"
    else
        print_warning "⚠️ Ubuntu UFW firewall service not active"
    fi
    
    # Log Ubuntu health check results
    if [ "$health_ok" = true ]; then
        logger "Claude AI Agent Ubuntu deployment health checks passed"
    else
        logger "Claude AI Agent Ubuntu deployment health checks failed"
    fi
    
    return $([ "$health_ok" = true ] && echo 0 || echo 1)
}

# Function to display Ubuntu service status
show_ubuntu_service_status() {
    print_status "Current Ubuntu service status:"
    
    echo "🐧 Ubuntu System Information:"
    echo "   Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "   Cloud: $CLOUD_PROVIDER"
    echo "   Type: $UBUNTU_TYPE"
    echo
    
    echo "🚀 PM2 Services:"
    if ! pm2 status; then
        print_warning "Failed to get Ubuntu PM2 status"
    fi
    
    echo
    echo "🔧 Ubuntu System Services:"
    systemctl is-active nginx >/dev/null && echo "   Nginx: ✅ Active" || echo "   Nginx: ❌ Inactive"
    systemctl is-active ufw >/dev/null 2>&1 && echo "   UFW Firewall: ✅ Active" || echo "   UFW Firewall: ❌ Inactive"
    systemctl is-active fail2ban >/dev/null 2>&1 && echo "   fail2ban: ✅ Active" || echo "   fail2ban: ❌ Inactive"
}

# Function to display Ubuntu access information
show_ubuntu_access_information() {
    echo
    echo "========================================"
    echo "✅ Ubuntu Deployment Completed!"
    echo "========================================"
    echo
    echo "🐧 Ubuntu Environment:"
    echo "   Ubuntu: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "   Cloud: $CLOUD_PROVIDER"
    echo "   Type: $UBUNTU_TYPE"
    echo "   User: $CURRENT_USER"
    echo "   IP: $PUBLIC_IP"
    echo
    echo "🌐 Access your Ubuntu Claude AI Agent:"
    echo "   Main site: http://$PUBLIC_IP"
    echo "   API docs:  http://$PUBLIC_IP:${PORT:-8000}/docs"
    echo "   Health:    http://$PUBLIC_IP:${PORT:-8000}/health"
    echo "   Status:    http://$PUBLIC_IP/api/status"
    echo
    if [ "$CLOUD_PROVIDER" = "wsl" ]; then
        echo "   WSL Ubuntu: Access from Windows at http://localhost"
    fi
    echo
    echo "🔧 Ubuntu management commands:"
    echo "   Check status:   ./scripts/ubuntu-status.sh"
    echo "   View logs:      pm2 logs"
    echo "   Ubuntu logs:    journalctl -u nginx -f"
    echo "   Restart:        pm2 restart all"
    echo "   Monitor:        ./scripts/monitor.sh"
    echo "   Health check:   ./scripts/health-check.sh"
    echo "   Ubuntu backup:  ./scripts/backup.sh"
    echo
    echo "📊 Ubuntu next steps:"
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
    print_status "Starting Claude AI Agent Ubuntu Universal deployment"
    
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
