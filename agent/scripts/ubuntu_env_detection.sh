#!/bin/bash

# Ubuntu Universal Environment Detection for Claude AI Agent
# Version: FINAL v1.2 - Ubuntu Universal
# This file should be sourced by other scripts: source scripts/ubuntu-detection.sh
# Works across AWS Ubuntu, GCP Ubuntu, Azure Ubuntu, local Ubuntu, and WSL Ubuntu

# Global variables that will be exported
CLOUD_PROVIDER=""
UBUNTU_VERSION=""
UBUNTU_CODENAME=""
CURRENT_USER=""
PUBLIC_IP=""
INSTANCE_ID=""
PROJECT_ROOT=""
UBUNTU_TYPE=""

# Function to detect Ubuntu environment and set global variables
detect_ubuntu_environment() {
    # Initialize variables
    CURRENT_USER=$(whoami)
    
    # Verify Ubuntu system first
    verify_ubuntu_system
    
    # Detect Ubuntu version and details
    detect_ubuntu_version
    
    # Detect cloud provider or local environment
    detect_cloud_provider
    
    # Detect Ubuntu deployment type
    detect_ubuntu_type
    
    # Set project root based on user and environment
    set_ubuntu_project_root
    
    # Export all variables for use in other scripts
    export CLOUD_PROVIDER UBUNTU_VERSION UBUNTU_CODENAME CURRENT_USER PUBLIC_IP INSTANCE_ID PROJECT_ROOT UBUNTU_TYPE
    
    # Log detection results
    log_ubuntu_environment_detection
}

# Function to verify this is an Ubuntu system
verify_ubuntu_system() {
    if [ ! -f /etc/os-release ]; then
        echo "ERROR: /etc/os-release not found. This script requires Ubuntu 20.04 or 22.04."
        exit 1
    fi
    
    # Source the os-release file
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        echo "ERROR: This script is designed specifically for Ubuntu systems."
        echo "Detected OS: $ID"
        echo "Please use Ubuntu 20.04 LTS or Ubuntu 22.04 LTS."
        exit 1
    fi
    
    # Check Ubuntu version
    local version_major=$(echo "$VERSION_ID" | cut -d. -f1)
    if [ "$version_major" -ne 20 ] && [ "$version_major" -ne 22 ]; then
        echo "ERROR: Unsupported Ubuntu version: $VERSION_ID"
        echo "This script requires Ubuntu 20.04 LTS or Ubuntu 22.04 LTS."
        exit 1
    fi
    
    echo "✅ Ubuntu system verified: $PRETTY_NAME"
}

# Function to detect Ubuntu version details
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_VERSION="$VERSION_ID"
        UBUNTU_CODENAME="$VERSION_CODENAME"
    else
        # Fallback method
        UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
        UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
    fi
}

# Function to detect cloud provider or local environment
detect_cloud_provider() {
    # AWS Ubuntu detection
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        CLOUD_PROVIDER="aws"
        PUBLIC_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
        return 0
    fi
    
    # GCP Ubuntu detection
    if curl -s --max-time 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id >/dev/null 2>&1; then
        CLOUD_PROVIDER="gcp"
        PUBLIC_IP=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id 2>/dev/null || echo "unknown")
        return 0
    fi
    
    # Azure Ubuntu detection
    if curl -s --max-time 3 -H "Metadata:true" http://169.254.169.254/metadata/instance?api-version=2021-02-01 >/dev/null 2>&1; then
        CLOUD_PROVIDER="azure"
        PUBLIC_IP=$(curl -s --max-time 5 -H "Metadata:true" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "127.0.0.1")
        INSTANCE_ID=$(curl -s --max-time 5 -H "Metadata:true" "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2021-02-01&format=text" 2>/dev/null || echo "unknown")
        return 0
    fi
    
    # WSL Ubuntu detection
    if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
        CLOUD_PROVIDER="wsl"
        PUBLIC_IP="127.0.0.1"
        INSTANCE_ID="wsl-ubuntu"
        return 0
    fi
    
    # VPS Ubuntu detection (DigitalOcean, Linode, Vultr, etc.)
    if [ -f /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg ]; then
        CLOUD_PROVIDER="vps"
    elif [ -f /etc/cloud/cloud.cfg ]; then
        CLOUD_PROVIDER="cloud"
    else
        CLOUD_PROVIDER="local"
    fi
    
    # Get public IP for VPS/local systems
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || ip route get 1.1.1.1 | awk '{print $7}' | head -n1 || echo "127.0.0.1")
    INSTANCE_ID="ubuntu-local"
}

# Function to detect Ubuntu deployment type
detect_ubuntu_type() {
    if [ -f /var/lib/cloud/instance/cloud-id ]; then
        local cloud_id=$(cat /var/lib/cloud/instance/cloud-id 2>/dev/null)
        case "$cloud_id" in
            "aws") UBUNTU_TYPE="cloud-ubuntu" ;;
            "gce") UBUNTU_TYPE="cloud-ubuntu" ;;
            "azure") UBUNTU_TYPE="cloud-ubuntu" ;;
            *) UBUNTU_TYPE="cloud-ubuntu" ;;
        esac
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        UBUNTU_TYPE="wsl-ubuntu"
    elif [ -d /proc/vz ]; then
        UBUNTU_TYPE="container-ubuntu"
    elif systemd-detect-virt >/dev/null 2>&1; then
        UBUNTU_TYPE="vm-ubuntu"
    elif [ -f /etc/update-motd.d/00-header ]; then
        UBUNTU_TYPE="server-ubuntu"
    else
        UBUNTU_TYPE="desktop-ubuntu"
    fi
}

# Function to set project root based on Ubuntu user and environment
set_ubuntu_project_root() {
    case "$CURRENT_USER" in
        "ubuntu")
            PROJECT_ROOT="/home/ubuntu/claude-ai-agent"
            ;;
        "azureuser")
            PROJECT_ROOT="/home/azureuser/claude-ai-agent"
            ;;
        "root")
            PROJECT_ROOT="/root/claude-ai-agent"
            ;;
        *)
            # Fallback to user's home directory
            if [ -n "${HOME:-}" ]; then
                PROJECT_ROOT="$HOME/claude-ai-agent"
            else
                PROJECT_ROOT="/home/$CURRENT_USER/claude-ai-agent"
            fi
            ;;
    esac
}

# Function to log Ubuntu environment detection
log_ubuntu_environment_detection() {
    local log_file="$PROJECT_ROOT/logs/ubuntu-environment.log"
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    echo "$(date): Ubuntu environment detected - $CLOUD_PROVIDER/$UBUNTU_VERSION ($UBUNTU_CODENAME), User: $CURRENT_USER, Type: $UBUNTU_TYPE" >> "$log_file" 2>/dev/null || true
}

# Function to install packages using Ubuntu's apt
ubuntu_install_package() {
    local packages=("$@")
    
    if [ ${#packages[@]} -eq 0 ]; then
        echo "Error: No packages specified for Ubuntu installation"
        return 1
    fi
    
    echo "Installing Ubuntu packages: ${packages[*]}"
    
    # Update package lists first
    sudo apt-get update -qq || {
        echo "Warning: apt update failed, but continuing..."
    }
    
    # Install packages
    sudo apt-get install -y "${packages[@]}" || {
        echo "Error: Failed to install some packages: ${packages[*]}"
        return 1
    }
}

# Function to update Ubuntu system packages
ubuntu_update_system() {
    echo "Updating Ubuntu system packages..."
    
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    sudo apt-get autoclean
}

# Function to manage Ubuntu services using systemctl
ubuntu_manage_service() {
    local action="$1"
    local service_name="$2"
    
    if [ -z "$action" ] || [ -z "$service_name" ]; then
        echo "Error: ubuntu_manage_service requires action and service_name"
        return 1
    fi
    
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl "$action" "$service_name"
    else
        # Fallback for older Ubuntu systems
        case "$action" in
            "start"|"stop"|"restart"|"reload")
                sudo service "$service_name" "$action"
                ;;
            "enable")
                sudo update-rc.d "$service_name" enable
                ;;
            "disable")
                sudo update-rc.d "$service_name" disable
                ;;
            *)
                sudo service "$service_name" "$action"
                ;;
        esac
    fi
}

# Function to check if Ubuntu service is active
ubuntu_is_service_active() {
    local service_name="$1"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet "$service_name" 2>/dev/null
    else
        # Fallback for older Ubuntu systems
        service "$service_name" status >/dev/null 2>&1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get Ubuntu system information
get_ubuntu_system_info() {
    echo "Ubuntu System Information:"
    echo "=========================="
    echo "Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "Architecture: $(dpkg --print-architecture)"
    echo "Kernel: $(uname -r)"
    
    if command_exists free; then
        echo "Memory: $(free -h | awk 'NR==2{print $2}')"
    fi
    
    if command_exists df; then
        echo "Disk: $(df -h / | awk 'NR==2{print $2 " total, " $4 " available"}')"
    fi
    
    if command_exists nproc; then
        echo "CPU Cores: $(nproc)"
    fi
    
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
}

# Function to check Ubuntu prerequisites
check_ubuntu_prerequisites() {
    local errors=0
    
    echo "Checking Ubuntu prerequisites..."
    
    # Check Ubuntu version
    local version_major=$(echo "$UBUNTU_VERSION" | cut -d. -f1)
    if [ "$version_major" -ne 20 ] && [ "$version_major" -ne 22 ]; then
        echo "❌ Unsupported Ubuntu version: $UBUNTU_VERSION"
        echo "   Required: Ubuntu 20.04 LTS or Ubuntu 22.04 LTS"
        errors=$((errors + 1))
    else
        echo "✅ Ubuntu version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    fi
    
    # Check if user has sudo privileges
    if sudo -n true 2>/dev/null; then
        echo "✅ User has sudo privileges"
    elif sudo -v 2>/dev/null; then
        echo "✅ User can use sudo (password required)"
    else
        echo "❌ User does not have sudo privileges"
        errors=$((errors + 1))
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ Internet connectivity available"
    else
        echo "❌ No internet connectivity"
        errors=$((errors + 1))
    fi
    
    # Check available disk space (require at least 5GB)
    if command_exists df; then
        local available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
        local required_kb=5242880  # 5GB in KB
        
        if [ -n "$available_kb" ] && [ "$available_kb" -gt "$required_kb" ]; then
            local available_gb=$((available_kb / 1024 / 1024))
            echo "✅ Sufficient disk space: ${available_gb}GB available"
        else
            local available_gb=$((available_kb / 1024 / 1024))
            echo "❌ Insufficient disk space: ${available_gb}GB available (5GB required)"
            errors=$((errors + 1))
        fi
    fi
    
    # Check memory (warn if less than 1GB)
    if command_exists free; then
        local total_memory_gb=$(free -g | awk 'NR==2{print $2}')
        if [ "$total_memory_gb" -ge 1 ]; then
            echo "✅ Sufficient memory: ${total_memory_gb}GB"
        else
            echo "⚠️ Low memory: ${total_memory_gb}GB (2GB+ recommended)"
        fi
    fi
    
    # Check if running as root (not recommended for most operations)
    if [ "$CURRENT_USER" = "root" ]; then
        echo "⚠️ Running as root user (use with caution)"
    else
        echo "✅ Running as non-root user: $CURRENT_USER"
    fi
    
    return $errors
}

# Function to setup Ubuntu firewall (UFW)
setup_ubuntu_firewall() {
    echo "Setting up Ubuntu firewall (UFW)..."
    
    # Install UFW if not present
    if ! command_exists ufw; then
        ubuntu_install_package ufw
    fi
    
    # Configure basic firewall rules
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Allow custom application port
    sudo ufw allow 8000/tcp
    
    echo "✅ Ubuntu firewall configured"
}

# Function to configure Ubuntu security settings
configure_ubuntu_security() {
    echo "Configuring Ubuntu security settings..."
    
    # Install fail2ban for SSH protection
    ubuntu_install_package fail2ban
    
    # Configure SSH security (if SSH is installed)
    if [ -f /etc/ssh/sshd_config ]; then
        # Backup original config
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        
        # Disable password authentication if not already disabled
        if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
        fi
        
        # Disable root login if not already disabled
        if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
        fi
        
        # Restart SSH service
        ubuntu_manage_service restart ssh
    fi
    
    echo "✅ Ubuntu security configured"
}

# Function to display Ubuntu environment information
show_ubuntu_environment_info() {
    echo "Ubuntu Environment Detection Results:"
    echo "===================================="
    echo "Cloud Provider: $CLOUD_PROVIDER"
    echo "Ubuntu Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "Ubuntu Type: $UBUNTU_TYPE"
    echo "Current User: $CURRENT_USER"
    echo "Public IP: $PUBLIC_IP"
    echo "Instance ID: $INSTANCE_ID"
    echo "Project Root: $PROJECT_ROOT"
    
    get_ubuntu_system_info
}

# Function to validate Ubuntu environment
validate_ubuntu_environment() {
    local errors=0
    
    # Check Ubuntu prerequisites
    if ! check_ubuntu_prerequisites; then
        errors=$((errors + 1))
    fi
    
    if [ "$CLOUD_PROVIDER" = "" ]; then
        echo "Error: Cloud provider detection failed"
        errors=$((errors + 1))
    fi
    
    if [ "$UBUNTU_VERSION" = "unknown" ]; then
        echo "Error: Ubuntu version detection failed"
        errors=$((errors + 1))
    fi
    
    if [ ! -d "$(dirname "$PROJECT_ROOT")" ]; then
        echo "Error: Parent directory for project root does not exist: $(dirname "$PROJECT_ROOT")"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Function to create Ubuntu-optimized environment file
create_ubuntu_env_file() {
    local env_file="$PROJECT_ROOT/.env"
    
    # Generate secret key using Ubuntu's entropy sources
    local secret_key
    if command_exists openssl; then
        secret_key=$(openssl rand -hex 32)
    else
        secret_key=$(date +%s | sha256sum | head -c 64)
    fi
    
    # Create environment configuration
    cat > "$env_file" << EOF
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

# Database Configuration (Ubuntu optimized paths)
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

# CORS Configuration
ALLOWED_ORIGINS=*
CORS_ENABLED=True

# Rate Limiting
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=3600

# Ubuntu Logging Configuration
LOG_LEVEL=INFO
SYSLOG_ENABLED=True

# Ubuntu Monitoring Configuration
HEALTH_CHECK_INTERVAL=300
METRICS_COLLECTION=True
SYSTEM_MONITORING=True

# Ubuntu Backup Configuration
BACKUP_RETENTION_DAYS=30
AUTO_BACKUP=True
UBUNTU_BACKUP_PATH=$PROJECT_ROOT/backups

# Ubuntu Security Configuration
UFW_ENABLED=True
FAIL2BAN_ENABLED=True
SSH_SECURITY=True
EOF

    # Secure the environment file
    chmod 600 "$env_file"
    echo "✅ Ubuntu environment file created: $env_file"
}

# Function to check Ubuntu package availability
check_ubuntu_package_availability() {
    local packages=("$@")
    local unavailable=()
    
    echo "Checking Ubuntu package availability..."
    
    # Update package cache
    sudo apt-get update -qq
    
    for package in "${packages[@]}"; do
        if ! apt-cache show "$package" >/dev/null 2>&1; then
            unavailable+=("$package")
        fi
    done
    
    if [ ${#unavailable[@]} -gt 0 ]; then
        echo "⚠️ Unavailable packages: ${unavailable[*]}"
        return 1
    else
        echo "✅ All packages available"
        return 0
    fi
}

# Function to optimize Ubuntu for Claude AI Agent
optimize_ubuntu_system() {
    echo "Optimizing Ubuntu system for Claude AI Agent..."
    
    # Install essential Ubuntu packages
    local essential_packages=(
        "curl" "wget" "git" "htop" "unzip" "zip" "tree" "nano" "vim"
        "software-properties-common" "apt-transport-https" "ca-certificates"
        "gnupg" "lsb-release" "jq" "bc" "sqlite3" "netcat" "build-essential"
        "python3" "python3-pip" "python3-venv" "python3-dev"
    )
    
    ubuntu_install_package "${essential_packages[@]}"
    
    # Configure system limits for better performance
    cat << EOF | sudo tee /etc/security/limits.conf.d/claude-agent.conf
$CURRENT_USER soft nofile 65536
$CURRENT_USER hard nofile 65536
EOF
    
    # Configure sysctl for better network performance
    cat << EOF | sudo tee /etc/sysctl.d/99-claude-agent.conf
# Network optimizations for Claude AI Agent
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
EOF
    
    # Apply sysctl changes
    sudo sysctl -p /etc/sysctl.d/99-claude-agent.conf
    
    echo "✅ Ubuntu system optimized"
}

# Main detection function - called when script is run directly
main() {
    echo "Starting Ubuntu environment detection..."
    
    detect_ubuntu_environment
    show_ubuntu_environment_info
    echo
    
    if validate_ubuntu_environment; then
        echo "✅ Ubuntu environment validation passed"
        
        # Optionally setup basic security
        read -p "Setup Ubuntu security (UFW firewall, fail2ban)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_ubuntu_firewall
            configure_ubuntu_security
        fi
        
        # Optionally optimize system
        read -p "Optimize Ubuntu system for Claude AI Agent? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            optimize_ubuntu_system
        fi
        
        echo "✅ Ubuntu environment setup complete"
    else
        echo "❌ Ubuntu environment validation failed"
        exit 1
    fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
