# Installation Guide

Complete step-by-step installation guide for deploying Claude AI Agent on AWS Lightsail.

## Prerequisites

Before starting, ensure you have:
- AWS Account (free tier eligible)
- Anthropic API Key ([get one here](https://console.anthropic.com/))
- Basic Linux/command line familiarity
- Credit card for AWS verification

## Cost Estimate

- **AWS Lightsail Instance**: $10-15/month (2GB RAM, 1 vCPU, 60GB SSD)
- **Anthropic API Usage**: $5-20/month (pay-per-token based on usage)
- **Total Monthly Cost**: ~$15-35/month

## Step 1: AWS Account Setup

### 1.1 Create AWS Account
1. Go to [https://aws.amazon.com/](https://aws.amazon.com/)
2. Click "Create an AWS Account"
3. Follow the registration process requiring:
   - Email address
   - Phone number
   - Credit card (for verification)
4. Complete account verification steps
5. Choose Basic/Free support plan

### 1.2 Access AWS Console
1. Sign in to AWS Management Console
2. Navigate to services menu
3. Search for "Lightsail" in services

## Step 2: Create Lightsail Instance

### 2.1 Instance Configuration
1. In AWS Console, navigate to Amazon Lightsail
2. Click "Create instance"
3. Select platform: **Linux/Unix**
4. Choose blueprint: **OS Only**
5. Select operating system: **Ubuntu 22.04 LTS**

### 2.2 Choose Instance Plan

**Recommended for Production:**
- $10 USD/month
- 2 GB RAM
- 1 vCPU
- 60 GB SSD
- 3 TB transfer

**For Development/Testing:**
- $5 USD/month
- 1 GB RAM
- 1 vCPU
- 40 GB SSD
- 2 TB transfer

### 2.3 Instance Settings
1. Instance name: `claude-ai-agent`
2. Availability Zone: (keep default)
3. Key pair: Download default key or create new
4. Click "Create instance"
5. Wait for instance to be running (2-3 minutes)

## Step 3: Configure Networking

### 3.1 Create Static IP
1. Go to "Networking" tab in Lightsail console
2. Click "Create static IP"
3. Select your instance
4. Name: `claude-agent-static-ip`
5. Click "Create"

### 3.2 Configure Firewall Rules
Add these firewall rules in your instance dashboard:

```
Application: Custom
Protocol: TCP
Port range: 8000
Source: Anywhere (0.0.0.0/0)
Description: FastAPI Backend

Application: Custom
Protocol: TCP
Port range: 3000
Source: Anywhere (0.0.0.0/0)
Description: React Development

Application: HTTP
Protocol: TCP
Port range: 80
Source: Anywhere (0.0.0.0/0)
Description: Web Server

Application: HTTPS
Protocol: TCP
Port range: 443
Source: Anywhere (0.0.0.0/0)
Description: Secure Web Server
```

## Step 4: Connect to Your Instance

### 4.1 Browser SSH (Recommended)
1. Go to your Lightsail instance dashboard
2. Click "Connect using SSH"
3. Browser-based terminal opens
4. You should see: `ubuntu@ip-172-26-x-x:~$`

### 4.2 SSH Client (Alternative)
```bash
# Download the default key from Lightsail
# On your local machine:
chmod 400 LightsailDefaultKey-us-east-1.pem
ssh -i LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_PUBLIC_IP
```

## Step 5: System Setup

### 5.1 Update System
```bash
# Update package lists
sudo apt-get update

# Upgrade existing packages
sudo apt-get upgrade -y

# Install essential packages
sudo apt-get install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    zip \
    tree \
    nano \
    vim \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
```

### 5.2 Install Node.js
```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Install Node.js
sudo apt-get install -y nodejs

# Verify installation
node --version  # Should show v18.x.x
npm --version   # Should show 9.x.x or higher
```

### 5.3 Install Python Dependencies
```bash
# Install Python and tools
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential

# Verify Python installation
python3 --version  # Should show Python 3.10.x
pip3 --version     # Should show pip 22.x.x
```

### 5.4 Install Additional Tools
```bash
# Install Nginx
sudo apt-get install -y nginx

# Install PM2 globally for process management
sudo npm install -g pm2

# Install other useful tools
sudo apt-get install -y \
    sqlite3 \
    jq \
    netcat \
    telnet

# Verify installations
nginx -v        # Should show nginx version
pm2 --version   # Should show PM2 version
sqlite3 --version  # Should show SQLite version
```

## Step 6: Create Project Structure

### 6.1 Create Directories
```bash
# Navigate to home directory
cd /home/ubuntu

# Create main project directory
mkdir claude-ai-agent
cd claude-ai-agent

# Create subdirectories
mkdir -p backend frontend scripts logs data config backups docs

# Create essential files
touch README.md .gitignore .env

# Verify structure
tree -L 2
```

### 6.2 Set Permissions
```bash
# Ensure ubuntu user owns everything
sudo chown -R ubuntu:ubuntu /home/ubuntu/claude-ai-agent

# Set directory permissions
find /home/ubuntu/claude-ai-agent -type d -exec chmod 755 {} \;

# Set file permissions
find /home/ubuntu/claude-ai-agent -type f -exec chmod 644 {} \;

# Make scripts directory executable
chmod 755 /home/ubuntu/claude-ai-agent/scripts
```

## Step 7: Environment Configuration

### 7.1 Create Environment File
```bash
cd /home/ubuntu/claude-ai-agent

# Get your public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create .env file
cat > .env << EOF
# =====================================
# Claude AI Agent Configuration
# =====================================

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
SECRET_KEY=$(openssl rand -hex 32)
ACCESS_TOKEN_EXPIRE_MINUTES=60

# AWS Configuration
AWS_REGION=us-east-1
STATIC_IP=$PUBLIC_IP
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# CORS Configuration
ALLOWED_ORIGINS=*
CORS_ENABLED=True

# Rate Limiting
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=3600

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=/home/ubuntu/claude-ai-agent/logs/app.log

# Monitoring Configuration
HEALTH_CHECK_INTERVAL=300
METRICS_COLLECTION=True

# Backup Configuration
BACKUP_RETENTION_DAYS=30
AUTO_BACKUP=True
EOF

# Secure the environment file
chmod 600 .env
```

### 7.2 Configure API Key
```bash
# Edit the environment file to add your Anthropic API key
nano /home/ubuntu/claude-ai-agent/.env

# Replace 'your_anthropic_api_key_here' with your actual key:
# ANTHROPIC_API_KEY=sk-ant-your-actual-key-here

# Save and exit (Ctrl+X, Y, Enter)
```

## Step 8: Backend Setup

### 8.1 Create Virtual Environment
```bash
cd /home/ubuntu/claude-ai-agent/backend

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

### 8.2 Install Python Packages
```bash
# Install core packages
pip install \
    anthropic==0.7.8 \
    fastapi==0.104.1 \
    uvicorn[standard]==0.24.0 \
    python-dotenv==1.0.0 \
    pydantic==2.5.0 \
    sqlalchemy==2.0.23 \
    aiofiles==23.2.1 \
    python-multipart==0.0.6 \
    requests==2.31.0 \
    psutil==5.9.6

# Install additional packages
pip install \
    python-jose[cryptography]==3.3.0 \
    passlib[bcrypt]==1.7.4 \
    email-validator==2.1.0 \
    jinja2==3.1.2

# Create requirements.txt
pip freeze > requirements.txt
```

## Step 9: Database Initialization

### 9.1 Initialize Database
```bash
# Ensure data directory exists
mkdir -p /home/ubuntu/claude-ai-agent/data

# The database will be created automatically when the application starts
# SQLite database will be created at: ./data/agent_database.db
```

## Step 10: Frontend Setup

### 10.1 Initialize React Application
```bash
cd /home/ubuntu/claude-ai-agent/frontend

# Create React TypeScript application
npx create-react-app . --template typescript

# Install additional dependencies
npm install @mui/material @emotion/react @emotion/styled
npm install @mui/icons-material
npm install axios
```

## Step 11: Nginx Configuration

### 11.1 Configure Nginx
```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/claude-agent

# Add this configuration:
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_IP;

    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Enable the site
sudo ln -s /etc/nginx/sites-available/claude-agent /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

## Step 12: Process Management

### 12.1 Configure PM2
```bash
# Start backend with PM2
cd /home/ubuntu/claude-ai-agent/backend
source venv/bin/activate
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" --name claude-backend

# Build and start frontend
cd /home/ubuntu/claude-ai-agent/frontend
npm run build
pm2 start "npx serve -s build -l 3000" --name claude-frontend

# Save PM2 configuration
pm2 save
pm2 startup

# Follow the instructions provided by pm2 startup command
```

## Step 13: Verification

### 13.1 Check Services
```bash
# Check PM2 processes
pm2 status

# Check Nginx status
sudo systemctl status nginx

# Check if ports are listening
netstat -tlnp | grep :8000  # Backend
netstat -tlnp | grep :3000  # Frontend
netstat -tlnp | grep :80    # Nginx
```

### 13.2 Test Installation
```bash
# Test backend API
curl http://localhost:8000/health

# Test frontend (in browser)
# Visit: http://YOUR_PUBLIC_IP
```

## Troubleshooting

### Common Issues

**Port Already in Use:**
```bash
sudo lsof -i :8000
sudo kill -9 PID_NUMBER
```

**Permission Issues:**
```bash
sudo chown -R ubuntu:ubuntu /home/ubuntu/claude-ai-agent
```

**Service Not Starting:**
```bash
pm2 logs claude-backend
pm2 logs claude-frontend
```

**Nginx Configuration Errors:**
```bash
sudo nginx -t
sudo systemctl status nginx
```

## Next Steps

After successful installation:
1. Test your Claude AI agent in the browser
2. Configure SSL certificates for production use
3. Set up monitoring and backup procedures
4. Review security settings
5. Configure domain name (optional)

See [Configuration Guide](configuration-guide.md) for detailed configuration options.
