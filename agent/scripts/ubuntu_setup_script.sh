#!/bin/bash

# Claude AI Agent Ubuntu Setup Script
# Version: FINAL v1.2 - Ubuntu Multi-Environment Support
# Works on Ubuntu 20.04/22.04 across AWS, GCP, Azure, local, and WSL

set -e  # Exit on any error
set -u  # Exit on undefined variables

echo "========================================"
echo "Claude AI Agent - Ubuntu Setup"
echo "========================================"
echo "Starting Ubuntu setup process at $(date)"
echo

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UBUNTU_DETECTION_SCRIPT="$SCRIPT_DIR/ubuntu-detection.sh"

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

# Function to create or source Ubuntu detection script
setup_ubuntu_detection() {
    # If the detection script doesn't exist, create it inline
    if [ ! -f "$UBUNTU_DETECTION_SCRIPT" ]; then
        print_status "Creating Ubuntu detection script..."
        mkdir -p "$(dirname "$UBUNTU_DETECTION_SCRIPT")"
        
        # Create the detection script (embedded for portability)
        cat > "$UBUNTU_DETECTION_SCRIPT" << 'EOF'
#!/bin/bash
# Ubuntu Environment Detection - Embedded Version

CLOUD_PROVIDER=""
UBUNTU_VERSION=""
UBUNTU_CODENAME=""
CURRENT_USER=""
PUBLIC_IP=""
INSTANCE_ID=""
PROJECT_ROOT=""
UBUNTU_TYPE=""

detect_ubuntu_environment() {
    CURRENT_USER=$(whoami)
    
    # Verify Ubuntu system
    if [ ! -f /etc/os-release ]; then
        echo "ERROR: This script requires Ubuntu 20.04 or 22.04."
        exit 1
    fi
    
    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        echo "ERROR: This script is designed for Ubuntu systems. Detected: $ID"
        exit 1
    fi
    
    UBUNTU_VERSION="$VERSION_ID"
    UBUNTU_CODENAME="$VERSION_CODENAME"
    
    # Check Ubuntu version
    local version_major=$(echo "$UBUNTU_VERSION" | cut -d. -f1)
    if [ "$version_major" -ne 20 ] && [ "$version_major" -ne 22 ]; then
        echo "ERROR: Unsupported Ubuntu version: $UBUNTU_VERSION"
        echo "This script requires Ubuntu 20.04 LTS or Ubuntu 22.04 LTS."
        exit 1
    fi
    
    # Detect cloud provider or environment type
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
    
    # Set project root based on user and environment
    case "$CURRENT_USER" in
        "ubuntu") PROJECT_ROOT="/home/ubuntu/claude-ai-agent" ;;
        "azureuser") PROJECT_ROOT="/home/azureuser/claude-ai-agent" ;;
        "ec2-user") PROJECT_ROOT="/home/ec2-user/claude-ai-agent" ;;
        "root") PROJECT_ROOT="/root/claude-ai-agent" ;;
        *) PROJECT_ROOT="$HOME/claude-ai-agent" ;;
    esac
    
    # Determine Ubuntu type
    if [ "$CLOUD_PROVIDER" != "local" ] && [ "$CLOUD_PROVIDER" != "wsl" ]; then
        UBUNTU_TYPE="cloud-ubuntu"
    elif [ "$CLOUD_PROVIDER" = "wsl" ]; then
        UBUNTU_TYPE="wsl-ubuntu"
    else
        UBUNTU_TYPE="local-ubuntu"
    fi
    
    export CLOUD_PROVIDER UBUNTU_VERSION UBUNTU_CODENAME CURRENT_USER PUBLIC_IP INSTANCE_ID PROJECT_ROOT UBUNTU_TYPE
}

ubuntu_install_package() {
    local packages=("$@")
    if [ ${#packages[@]} -eq 0 ]; then
        echo "Error: No packages specified"
        return 1
    fi
    
    sudo apt-get update -qq || true
    sudo apt-get install -y "${packages[@]}"
}

ubuntu_update_system() {
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    sudo apt-get autoclean
}
EOF
        chmod +x "$UBUNTU_DETECTION_SCRIPT"
    fi
    
    # Source the detection script
    source "$UBUNTU_DETECTION_SCRIPT"
    detect_ubuntu_environment
}

# Function to check if running as correct user
check_ubuntu_user() {
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
    
    # Check sudo privileges
    if ! sudo -n true 2>/dev/null; then
        print_status "Testing sudo access..."
        if ! sudo true; then
            print_error "This script requires sudo privileges. Please ensure your user can run sudo commands."
        fi
    fi
    
    print_status "User verification passed: $CURRENT_USER"
}

# Function to setup logging
setup_logging() {
    mkdir -p "$PROJECT_ROOT/logs"
    LOG_FILE="$PROJECT_ROOT/logs/ubuntu-setup.log"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
}

# Function to check Ubuntu system requirements
check_ubuntu_system_requirements() {
    print_status "Checking Ubuntu system requirements..."
    
    # Verify Ubuntu version
    local version_major=$(echo "$UBUNTU_VERSION" | cut -d. -f1)
    if [ "$version_major" -eq 20 ] || [ "$version_major" -eq 22 ]; then
        print_status "✅ Ubuntu version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    else
        print_error "❌ Unsupported Ubuntu version: $UBUNTU_VERSION. This script requires Ubuntu 20.04 LTS or Ubuntu 22.04 LTS."
    fi
    
    # Memory check
    local memory_mb
    if command_exists free; then
        memory_mb=$(free -m | awk '/^Mem:/ {print $2}')
        if [ -n "$memory_mb" ]; then
            if [ "$memory_mb" -lt 512 ]; then
                print_warning "Low memory detected: ${memory_mb}MB. Recommended: 1GB+"
            else
                print_status "✅ Memory: ${memory_mb}MB"
            fi
        fi
    fi
    
    # Disk space check
    local disk_gb
    if command_exists df; then
        disk_gb=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
        if [ -n "$disk_gb" ] && [ "$disk_gb" -lt 2 ]; then
            print_warning "Low disk space: ${disk_gb}GB available. Recommended: 5GB+"
        else
            print_status "✅ Disk space: ${disk_gb}GB available"
        fi
    fi
    
    print_status "System requirements check passed"
}

# Function to install Ubuntu system dependencies
install_ubuntu_dependencies() {
    print_status "Installing Ubuntu system dependencies..."
    
    # Check if we can use sudo
    if ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo access. Please ensure your user has sudo privileges."
    fi
    
    # Update package lists
    print_status "Updating Ubuntu package lists..."
    if ! sudo apt-get update; then
        print_error "Failed to update package lists. Check your internet connection and apt configuration."
    fi
    
    # Install essential packages
    local essential_packages=(
        "curl" "wget" "git" "htop" "unzip" "zip" "tree" "nano" "vim"
        "software-properties-common" "apt-transport-https" "ca-certificates"
        "gnupg" "lsb-release" "jq" "bc" "sqlite3" "netcat" "telnet"
        "build-essential" "python3-dev" "python3-venv" "python3-pip"
    )
    
    print_status "Installing essential Ubuntu packages: ${essential_packages[*]}"
    if ! ubuntu_install_package "${essential_packages[@]}"; then
        print_error "Failed to install essential packages"
    fi
    
    # Verify critical tools are installed
    local critical_tools=("curl" "wget" "git" "python3" "pip3")
    for tool in "${critical_tools[@]}"; do
        if ! command_exists "$tool"; then
            print_error "Critical tool '$tool' failed to install or is not in PATH"
        fi
    done
    
    print_status "Ubuntu system dependencies installed successfully"
}

# Function to install Node.js on Ubuntu
install_nodejs() {
    print_status "Installing Node.js on Ubuntu..."
    
    if command_exists node; then
        local node_version
        node_version=$(node --version 2>/dev/null || echo "unknown")
        print_status "Node.js already installed: $node_version"
        
        # Check if version is 16+ (required for React 18)
        local major_version
        major_version=$(echo "$node_version" | sed 's/v//' | cut -d. -f1)
        if [ -n "$major_version" ] && [ "$major_version" -ge 16 ]; then
            print_status "Node.js version is acceptable"
            return 0
        else
            print_warning "Node.js version $node_version is old. Upgrading to latest LTS..."
        fi
    fi
    
    # Install Node.js from NodeSource repository
    print_status "Adding Node.js repository for Ubuntu..."
    if ! curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -; then
        print_error "Failed to add Node.js repository. Check internet connection."
    fi
    
    ubuntu_install_package "nodejs"
    
    # Verify installation
    if ! command_exists node || ! command_exists npm; then
        print_error "Node.js installation failed. node or npm not found in PATH."
    fi
    
    local node_version npm_version
    node_version=$(node --version)
    npm_version=$(npm --version)
    print_status "✅ Node.js installed: $node_version"
    print_status "✅ npm installed: $npm_version"
}

# Function to install Python virtual environment
setup_python_environment() {
    print_status "Setting up Python environment..."
    
    # Verify Python 3 is available
    if ! command_exists python3; then
        print_error "Python 3 not found. This should have been installed with system dependencies."
    fi
    
    local python_version
    python_version=$(python3 --version)
    print_status "Using Python: $python_version"
    
    # Install pip if not available
    if ! command_exists pip3; then
        print_status "Installing pip for Python 3..."
        ubuntu_install_package "python3-pip"
    fi
    
    # Upgrade pip to latest version
    print_status "Upgrading pip to latest version..."
    if ! python3 -m pip install --upgrade pip; then
        print_warning "Failed to upgrade pip, but continuing..."
    fi
    
    print_status "✅ Python environment ready"
}

# Function to install and configure Nginx
install_nginx() {
    print_status "Installing and configuring Nginx..."
    
    # Install Nginx
    ubuntu_install_package "nginx"
    
    # Verify installation
    if ! command_exists nginx; then
        print_error "Nginx installation failed"
    fi
    
    # Start and enable Nginx
    print_status "Starting Nginx service..."
    if ! sudo systemctl start nginx; then
        print_error "Failed to start Nginx"
    fi
    
    if ! sudo systemctl enable nginx; then
        print_warning "Failed to enable Nginx auto-start, but continuing..."
    fi
    
    # Test Nginx configuration
    if ! sudo nginx -t; then
        print_error "Nginx configuration test failed"
    fi
    
    print_status "✅ Nginx installed and running"
}

# Function to install PM2
install_pm2() {
    print_status "Installing PM2 process manager..."
    
    # Install PM2 globally
    if ! npm install -g pm2; then
        print_error "Failed to install PM2"
    fi
    
    # Verify installation
    if ! command_exists pm2; then
        print_error "PM2 installation failed"
    fi
    
    # Setup PM2 startup script
    print_status "Configuring PM2 startup..."
    if pm2 startup | grep -q "sudo"; then
        # Extract and run the startup command
        local startup_cmd
        startup_cmd=$(pm2 startup | grep "sudo" | tail -n 1)
        if [ -n "$startup_cmd" ]; then
            eval "$startup_cmd" || print_warning "PM2 startup configuration failed, but continuing..."
        fi
    fi
    
    local pm2_version
    pm2_version=$(pm2 --version)
    print_status "✅ PM2 installed: v$pm2_version"
}

# Function to create project structure
create_project_structure() {
    print_status "Creating project structure..."
    
    print_status "Project will be created at: $PROJECT_ROOT"
    
    # Create main directory if it doesn't exist
    if [ ! -d "$PROJECT_ROOT" ]; then
        if ! mkdir -p "$PROJECT_ROOT"; then
            print_error "Failed to create project directory: $PROJECT_ROOT"
        fi
    fi
    
    # Change to project directory
    if ! cd "$PROJECT_ROOT"; then
        print_error "Failed to change to project directory: $PROJECT_ROOT"
    fi
    
    # Create subdirectories
    local subdirs=("backend" "frontend" "scripts" "logs" "data" "config" "backups" "docs")
    for dir in "${subdirs[@]}"; do
        if ! mkdir -p "$dir"; then
            print_error "Failed to create directory: $dir"
        fi
    done
    
    # Create essential files
    touch README.md .gitignore .env || print_error "Failed to create essential files"
    
    # Set proper permissions
    print_status "Setting file permissions..."
    
    # Set ownership (may fail in some environments)
    if ! chown -R "$CURRENT_USER:$CURRENT_USER" "$PROJECT_ROOT" 2>/dev/null; then
        print_warning "Could not set file ownership, but continuing..."
    fi
    
    # Set directory permissions
    if ! chmod -R 755 "$PROJECT_ROOT"; then
        print_warning "Could not set directory permissions, but continuing..."
    fi
    
    # Set secure permissions for .env
    if ! chmod 600 "$PROJECT_ROOT/.env"; then
        print_warning "Could not set .env permissions, but continuing..."
    fi
    
    print_status "✅ Project structure created"
}

# Function to create environment configuration file
create_environment_file() {
    print_status "Creating environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env"
    
    # Create .env file with default configuration
    cat > "$env_file" << EOF
# Claude AI Agent Configuration
# Generated on $(date) for Ubuntu $UBUNTU_VERSION on $CLOUD_PROVIDER

# Anthropic API Configuration
ANTHROPIC_API_KEY=your_anthropic_api_key_here
MODEL_NAME=claude-3-sonnet-20240229
MAX_TOKENS=1000

# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=False
ENVIRONMENT=production

# Database Configuration
DATABASE_URL=sqlite:///./data/agent_database.db

# Security Configuration
SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 | head -c 32)
ACCESS_TOKEN_EXPIRE_MINUTES=60

# CORS Configuration
ALLOWED_ORIGINS=*
CORS_ENABLED=True

# Rate Limiting
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=3600
RATE_LIMIT_BURST=10

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=$PROJECT_ROOT/logs/app.log
SYSLOG_ENABLED=True

# Monitoring Configuration
HEALTH_CHECK_INTERVAL=300
METRICS_COLLECTION=True
SYSTEM_MONITORING=True

# Backup Configuration
BACKUP_RETENTION_DAYS=30
AUTO_BACKUP=True
BACKUP_SCHEDULE="0 3 * * *"

# System Information (Auto-detected)
CLOUD_PROVIDER=$CLOUD_PROVIDER
UBUNTU_VERSION=$UBUNTU_VERSION
UBUNTU_TYPE=$UBUNTU_TYPE
CURRENT_USER=$CURRENT_USER
PROJECT_ROOT=$PROJECT_ROOT
EOF
    
    # Set secure permissions
    chmod 600 "$env_file"
    
    print_status "✅ Environment configuration created"
    print_warning "⚠️  IMPORTANT: Edit $env_file and add your Anthropic API key before deployment"
}

# Function to create gitignore file
create_gitignore() {
    print_status "Creating .gitignore file..."
    
    cat > "$PROJECT_ROOT/.gitignore" << 'EOF'
# Environment variables
.env
.env.local
.env.development
.env.test
.env.production

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# nyc test coverage
.nyc_output/

# Dependency directories
node_modules/
jspm_packages/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# parcel-bundler cache (https://parceljs.org/)
.cache
.parcel-cache

# next.js build output
.next

# nuxt.js build output
.nuxt

# vuepress build output
.vuepress/dist

# Serverless directories
.serverless

# FuseBox cache
.fusebox/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
*.manifest
*.spec

# Virtual environments
venv/
ENV/
env/
.env

# Database
*.db
*.sqlite3
data/

# Backups
backups/
*.backup
*.bak

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# Temporary files
tmp/
temp/
*.tmp
EOF

    print_status "✅ .gitignore file created"
}

# Function to setup basic management scripts
create_basic_scripts() {
    print_status "Creating basic management scripts..."
    
    # Create scripts directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/scripts"
    
    # Create a simple status script
    cat > "$PROJECT_ROOT/scripts/status.sh" << 'EOF'
#!/bin/bash
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
EOF

    chmod +x "$PROJECT_ROOT/scripts/status.sh"
    
    print_status "✅ Basic management scripts created"
}

# Function to run final validation
run_final_validation() {
    print_status "Running final validation..."
    
    # Check all required tools are available
    local required_tools=("node" "npm" "python3" "pip3" "nginx" "pm2" "git" "curl")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
    fi
    
    # Check project structure
    local required_dirs=("$PROJECT_ROOT/backend" "$PROJECT_ROOT/frontend" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/logs")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            print_error "Required directory missing: $dir"
        fi
    done
    
    # Check configuration files
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        print_error "Environment file missing: $PROJECT_ROOT/.env"
    fi
    
    print_status "✅ Final validation passed"
}

# Function to show completion message
show_completion_message() {
    echo
    echo "========================================"
    echo "✅ Ubuntu Setup completed successfully!"
    echo "========================================"
    echo
    echo "🐧 Ubuntu Environment detected:"
    echo "   Ubuntu Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "   Cloud Provider: $CLOUD_PROVIDER"
    echo "   Ubuntu Type: $UBUNTU_TYPE"
    echo "   Current User: $CURRENT_USER"
    echo "   Public IP: $PUBLIC_IP"
    echo
    echo "📁 Project created at: $PROJECT_ROOT"
    echo
    echo "🔧 Next steps:"
    echo "1. Configure your Anthropic API key:"
    echo "   nano $PROJECT_ROOT/.env"
    echo "   Replace 'your_anthropic_api_key_here' with your actual key"
    echo
    echo "2. Add your application code files to:"
    echo "   $PROJECT_ROOT/backend/ (Python/FastAPI code)"
    echo "   $PROJECT_ROOT/frontend/ (React application)"
    echo
    echo "3. Deploy your application:"
    echo "   $PROJECT_ROOT/scripts/deploy.sh"
    echo
    echo "4. Monitor your system:"
    echo "   $PROJECT_ROOT/scripts/status.sh"
    echo
    echo "📋 Available commands:"
    echo "   ./scripts/status.sh    - Check system status"
    echo "   ./scripts/deploy.sh    - Deploy application"
    echo "   ./scripts/monitor.sh   - Real-time monitoring"
    echo "   ./scripts/backup.sh    - Create backup"
    echo "   ./scripts/recover.sh   - Emergency recovery"
    echo
    echo "🌐 Get your Anthropic API key at:"
    echo "   https://console.anthropic.com/"
    echo
    echo "Setup completed at $(date)"
}

# Main execution function
main() {
    print_status "Claude AI Agent Ubuntu setup initiated"
    
    # Run Ubuntu environment detection first
    setup_ubuntu_detection
    
    # Run all setup steps
    check_ubuntu_user
    setup_logging
    check_ubuntu_system_requirements
    install_ubuntu_dependencies
    install_nodejs
    setup_python_environment
    install_nginx
    install_pm2
    create_project_structure
    create_gitignore
    create_environment_file
    create_basic_scripts
    run_final_validation
    show_completion_message
    
    print_status "Ubuntu setup process completed successfully"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
