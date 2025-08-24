#!/bin/bash

# Claude AI Agent Ubuntu Universal Setup Script
# Version: FINAL v1.2 - Ubuntu Universal
# Works on Ubuntu 20.04/22.04 across AWS, GCP, Azure, local, and WSL

set -e  # Exit on any error
set -u  # Exit on undefined variables

echo "========================================"
echo "Claude AI Agent - Ubuntu Universal Setup"
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
        PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID="ubuntu-local"
    fi
    
    # Set project root
    case "$CURRENT_USER" in
        "ubuntu") PROJECT_ROOT="/home/ubuntu/claude-ai-agent" ;;
        "azureuser") PROJECT_ROOT="/home/azureuser/claude-ai-agent" ;;
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
        print_error "❌ Unsupported Ubuntu version: $UBUNTU_VERSION. Required: 20.04 or 22.04"
    fi
    
    # Check available disk space (require at least 5GB)
    if command_exists df; then
        local available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
        local required_kb=5242880  # 5GB in KB
        
        if [ -n "$available_kb" ] && [ "$available_kb" -gt "$required_kb" ]; then
            local available_gb=$((available_kb / 1024 / 1024))
            print_status "✅ Sufficient disk space: ${available_gb}GB available"
        else
            local available_gb=$((available_kb / 1024 / 1024))
            print_error "❌ Insufficient disk space: ${available_gb}GB available (5GB required)"
        fi
    fi
    
    # Check memory (warn if less than 1GB)
    if command_exists free; then
        local total_memory_gb=$(free -g | awk 'NR==2{print $2}')
        if [ "$total_memory_gb" -ge 1 ]; then
            print_status "✅ Memory: ${total_memory_gb}GB"
        else
            print_warning "⚠️ Low memory: ${total_memory_gb}GB (2GB+ recommended)"
        fi
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_status "✅ Internet connectivity verified"
    else
        print_error "❌ No internet connectivity"
    fi
    
    print_status "Ubuntu system requirements check passed"
}

# Function to install Ubuntu dependencies
install_ubuntu_dependencies() {
    print_status "Installing Ubuntu system dependencies..."
    
    # Update package lists
    ubuntu_update_system
    
    # Essential Ubuntu packages
    local essential_packages=(
        "curl" "wget" "git" "htop" "unzip" "zip" "tree" "nano" "vim"
        "software-properties-common" "apt-transport-https" "ca-certificates"
        "gnupg" "lsb-release" "jq" "bc" "sqlite3" "netcat" "build-essential"
    )
    
    print_status "Installing essential Ubuntu packages..."
    ubuntu_install_package "${essential_packages[@]}"
    
    # Verify critical tools are installed
    local critical_tools=("curl" "wget" "git")
    for tool in "${critical_tools[@]}"; do
        if ! command_exists "$tool"; then
            print_error "Critical tool '$tool' failed to install"
        fi
    done
    
    print_status "Ubuntu dependencies installed successfully"
}

# Function to install Node.js on Ubuntu
install_ubuntu_nodejs() {
    print_status "Installing Node.js on Ubuntu..."
    
    if command_exists node; then
        local node_version=$(node --version 2>/dev/null || echo "unknown")
        print_status "Node.js already installed: $node_version"
        
        # Check if version is 16+ (required for React 18)
        local major_version=$(echo "$node_version" | sed 's/v//' | cut -d. -f1)
        if [ -n "$major_version" ] && [ "$major_version" -ge 16 ]; then
            print_status "Node.js version is acceptable"
            return 0
        else
            print_warning "Node.js version $node_version is old. Upgrading..."
        fi
    fi
    
    # Add NodeSource repository for Ubuntu
    print_status "Adding NodeSource repository for Ubuntu..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    
    # Install Node.js
    ubuntu_install_package "nodejs"
    
    # Verify installation
    if ! command_exists node || ! command_exists npm; then
        print_error "Node.js or npm not found after installation"
    fi
    
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    print_status "✅ Node.js installed: $node_version"
    print_status "✅ npm installed: $npm_version"
}

# Function to install Python on Ubuntu
install_ubuntu_python() {
    print_status "Installing Python on Ubuntu..."
    
    # Python packages for Ubuntu
    local python_packages=(
        "python3" "python3-pip" "python3-venv" "python3-dev" 
        "python3-setuptools" "python3-wheel"
    )
    
    ubuntu_install_package "${python_packages[@]}"
    
    # Verify Python installation
    if ! command_exists python3; then
        print_error "Python3 not found after installation"
    fi
    
    if ! command_exists pip3; then
        print_error "pip3 not found after installation"
    fi
    
    local python_version=$(python3 --version)
    local pip_version=$(pip3 --version)
    print_status "✅ Python installed: $python_version"
    print_status "✅ pip installed: $pip_version"
    
    # Upgrade pip
    python3 -m pip install --upgrade pip || print_warning "Failed to upgrade pip"
}

# Function to install and configure Nginx on Ubuntu
install_ubuntu_nginx() {
    print_status "Installing Nginx on Ubuntu..."
    
    if command_exists nginx; then
        print_status "Nginx already installed"
        local nginx_version=$(nginx -v 2>&1 | head -1 || echo "version unknown")
        print_status "Nginx version: $nginx_version"
        return 0
    fi
    
    # Install Nginx
    ubuntu_install_package "nginx"
    
    # Verify Nginx installation
    if ! command_exists nginx; then
        print_error "Nginx not found after installation"
    fi
    
    # Enable and start Nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
    # Test Nginx configuration
    if ! sudo nginx -t; then
        print_warning "Nginx configuration test failed"
    fi
    
    local nginx_version=$(nginx -v 2>&1 | head -1)
    print_status "✅ Nginx installed: $nginx_version"
}

# Function to install PM2 on Ubuntu
install_ubuntu_pm2() {
    print_status "Installing PM2 process manager..."
    
    if command_exists pm2; then
        local pm2_version=$(pm2 --version)
        print_status "PM2 already installed: $pm2_version"
        return 0
    fi
    
    # Install PM2 globally
    sudo npm install -g pm2
    
    # Verify PM2 installation
    if ! command_exists pm2; then
        print_error "PM2 not found after installation"
    fi
    
    local pm2_version=$(pm2 --version)
    print_status "✅ PM2 installed: $pm2_version"
}

# Function to create Ubuntu project structure
create_ubuntu_project_structure() {
    print_status "Creating Ubuntu project structure..."
    
    # Create main directory if it doesn't exist
    if [ ! -d "$PROJECT_ROOT" ]; then
        mkdir -p "$PROJECT_ROOT"
    fi
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Create subdirectories
    local subdirs=("backend" "frontend" "scripts" "logs" "data" "config" "backups" "docs")
    for dir in "${subdirs[@]}"; do
        mkdir -p "$dir"
    done
    
    # Create essential files
    touch README.md .gitignore .env
    
    # Set proper permissions for Ubuntu
    chown -R "$CURRENT_USER:$CURRENT_USER" "$PROJECT_ROOT" 2>/dev/null || {
        sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$PROJECT_ROOT"
    }
    
    # Set directory permissions
    find "$PROJECT_ROOT" -type d -exec chmod 755 {} \;
    find "$PROJECT_ROOT" -type f -exec chmod 644 {} \;
    chmod 755 "$PROJECT_ROOT/scripts"
    
    print_status "✅ Ubuntu project structure created at: $PROJECT_ROOT"
}

# Function to create .gitignore for Ubuntu environment
create_ubuntu_gitignore() {
    print_status "Creating Ubuntu .gitignore..."
    
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/
pip-log.txt
.tox/
.coverage
.pytest_cache/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs/
*.log

# Database
*.db
*.sqlite
*.sqlite3

# Build outputs
dist/
build/
*.egg-info/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Ubuntu specific
*~
.directory

# Backup files
backups/
*.backup
*.bak

# Temporary files
tmp/
temp/
*.tmp
EOF
    
    chmod 644 .gitignore
    print_status "✅ Ubuntu .gitignore created"
}

# Function to create Ubuntu environment file
create_ubuntu_environment_file() {
    print_status "Creating Ubuntu environment configuration..."
    
    # Generate secret key using Ubuntu system entropy
    local secret_key
    if command_exists openssl; then
        secret_key=$(openssl rand -hex 32)
    else
        secret_key=$(date +%s | sha256sum | head -c 64)
    fi
    
    cat > .env << EOF
# =====================================
# Claude AI Agent - Ubuntu Configuration
# =====================================

# Anthropic API Configuration
ANTHROPIC_API_KEY=your_anthropic_api_key_here
MODEL_NAME=claude-3-sonnet-20240229
MAX_TOKENS=1000

# Ubuntu Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=False
ENVIRONMENT=production

# Database Configuration (Ubuntu paths)
DATABASE_URL=sqlite:///$PROJECT_ROOT/data/agent_database.db

# Security Configuration
SECRET_KEY=$secret_key
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Ubuntu System Information
UBUNTU_VERSION=$UBUNTU_VERSION
UBUNTU_CODENAME=$UBUNTU_CODENAME
CLOUD_PROVIDER=$CLOUD_PROVIDER
UBUNTU_TYPE=$UBUNTU_TYPE
STATIC_IP=$PUBLIC_IP
INSTANCE_ID=$INSTANCE_ID

# Ubuntu Project Paths
PROJECT_ROOT=$PROJECT_ROOT
LOG_FILE=$PROJECT_ROOT/logs/app.log
DATA_DIR=$PROJECT_ROOT/data
BACKUP_DIR=$PROJECT_ROOT/backups

# CORS
