# Configuration Guide

Comprehensive configuration guide for Claude AI Agent universal deployment system.

## Overview

The universal configuration system provides:
- 🌐 **Auto-detection** of cloud providers, OS types, and user configurations
- 🔒 **Secure defaults** with production-ready settings
- 📊 **Comprehensive monitoring** and performance tuning options
- 🔄 **Dynamic adaptation** to different deployment scenarios

## Configuration Files

### **Primary Configuration: .env**

**Location:** `claude-ai-agent/.env`

The main configuration file containing all system settings. This file is automatically created by the setup script with secure defaults and auto-detected values.

```bash
# View current configuration
cat .env

# Edit configuration
nano .env

# File permissions are automatically set to 600 (secure)
```

## Complete .env Configuration Reference

### **🔑 Anthropic API Configuration**
```bash
# Your Anthropic API key (REQUIRED)
ANTHROPIC_API_KEY=sk-ant-your-key-here

# Claude model to use
MODEL_NAME=claude-3-sonnet-20240229

# Maximum tokens per response (1-4096)
MAX_TOKENS=1000
```

**Getting an API Key:**
1. Visit [https://console.anthropic.com/](https://console.anthropic.com/)
2. Create account or sign in
3. Generate API key
4. Replace `your_anthropic_api_key_here` in .env

### **🌐 Server Configuration**
```bash
# Server bind address (0.0.0.0 for all interfaces)
HOST=0.0.0.0

# Backend server port
PORT=8000

# Debug mode (False for production)
DEBUG=False

# Environment type
ENVIRONMENT=production
```

### **💾 Database Configuration**
```bash
# Database connection string
DATABASE_URL=sqlite:///./data/agent_database.db

# Alternative database examples:
# PostgreSQL: postgresql://user:pass@host:port/dbname
# MySQL: mysql://user:pass@host:port/dbname
```

### **🔒 Security Configuration**
```bash
# Secret key for session security (auto-generated)
SECRET_KEY=your_generated_secret_key_here

# Session token expiration (minutes)
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

### **☁️ Cloud and Infrastructure (Auto-Detected)**
```bash
# Cloud provider (auto-detected)
CLOUD_PROVIDER=aws|gcp|azure|local|wsl

# Public IP address (auto-detected)
STATIC_IP=auto_detected_ip

# Instance ID (auto-detected)
INSTANCE_ID=auto_detected_id

# Project root path (auto-detected based on user)
PROJECT_ROOT=/path/to/claude-ai-agent
```

### **🌍 CORS Configuration**
```bash
# Allowed origins (* for all, comma-separated for specific)
ALLOWED_ORIGINS=*

# Enable/disable CORS
CORS_ENABLED=True

# For production, specify domains:
# ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

### **⚡ Rate Limiting**
```bash
# Maximum requests per window
RATE_LIMIT_REQUESTS=100

# Rate limit window in seconds (3600 = 1 hour)
RATE_LIMIT_WINDOW=3600
```

### **📋 Logging Configuration**
```bash
# Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
LOG_LEVEL=INFO

# Log file path
LOG_FILE=/path/to/claude-ai-agent/logs/app.log
```

### **📊 Monitoring Configuration**
```bash
# Health check interval in seconds
HEALTH_CHECK_INTERVAL=300

# Enable/disable metrics collection
METRICS_COLLECTION=True
```

### **💾 Backup Configuration**
```bash
# Backup retention in days
BACKUP_RETENTION_DAYS=30

# Enable/disable automatic backups
AUTO_BACKUP=True
```

## Platform-Specific Configurations

### **AWS Configuration**
The setup script automatically detects AWS and configures:
```bash
CLOUD_PROVIDER=aws
STATIC_IP=auto_detected_from_metadata
INSTANCE_ID=i-1234567890abcdef0
```

### **Google Cloud Platform**
```bash
CLOUD_PROVIDER=gcp
STATIC_IP=auto_detected_from_metadata
INSTANCE_ID=auto_detected_from_metadata
```

### **Microsoft Azure**
```bash
CLOUD_PROVIDER=azure
STATIC_IP=auto_detected_from_metadata
INSTANCE_ID=auto_detected_from_metadata
```

### **Local/VPS Systems**
```bash
CLOUD_PROVIDER=local
STATIC_IP=auto_detected_external_ip
INSTANCE_ID=local
```

### **WSL (Windows Subsystem for Linux)**
```bash
CLOUD_PROVIDER=wsl
STATIC_IP=127.0.0.1
INSTANCE_ID=wsl
```

## User-Specific Path Configuration

The system automatically sets project paths based on detected user:

### **Cloud Provider Users**
```bash
# AWS
ubuntu user → /home/ubuntu/claude-ai-agent
ec2-user → /home/ec2-user/claude-ai-agent

# GCP
Any user → /home/{username}/claude-ai-agent

# Azure
azureuser → /home/azureuser/claude-ai-agent
admin → /home/admin/claude-ai-agent
```

### **Local System Users**
```bash
# Standard users
$HOME/claude-ai-agent

# Root user
/root/claude-ai-agent
```

## Nginx Configuration

The setup script automatically creates nginx configuration at:
`/etc/nginx/sites-available/claude-agent`

### **Basic Configuration**
```nginx
server {
    listen 80 default_server;
    server_name _;
    
    client_max_body_size 10M;
    
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
        proxy_read_timeout 86400;
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
        proxy_read_timeout 86400;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8000/health;
        access_log off;
    }
}
```

### **SSL Configuration (Production)**
```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256;
    
    # Same location blocks as above
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## PM2 Configuration

The deployment script automatically configures PM2 processes:

### **Process Configuration**
```bash
# Backend process
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" \
    --name claude-backend \
    --watch \
    --ignore-watch="node_modules logs data backups" \
    --max-memory-restart 500M \
    --time

# Frontend process  
pm2 start "npx serve -s build -l 3000" \
    --name claude-frontend \
    --max-memory-restart 200M \
    --time
```

### **PM2 Ecosystem File (Advanced)**
Create `ecosystem.config.js` for advanced configuration:
```javascript
module.exports = {
  apps: [
    {
      name: 'claude-backend',
      script: 'uvicorn',
      args: 'main:app --host 0.0.0.0 --port 8000',
      cwd: '/path/to/claude-ai-agent/backend',
      interpreter: '/path/to/claude-ai-agent/backend/venv/bin/python',
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production'
      }
    },
    {
      name: 'claude-frontend',
      script: 'serve',
      args: '-s build -l 3000',
      cwd: '/path/to/claude-ai-agent/frontend',
      watch: false,
      max_memory_restart: '200M'
    }
  ]
};
```

## Firewall Configuration

### **UFW (Ubuntu Firewall)**
The setup script automatically configures UFW if available:
```bash
# Enable UFW
sudo ufw enable

# Allow essential ports
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp

# Check status
sudo ufw status
```

### **Cloud Provider Firewalls**
Configure these rules in your cloud provider console:

**AWS Security Groups:**
- HTTP (80) - 0.0.0.0/0
- HTTPS (443) - 0.0.0.0/0
- Custom TCP (8000) - 0.0.0.0/0
- SSH (22) - Your IP only

**GCP Firewall Rules:**
- allow-http: tcp:80
- allow-https: tcp:443
- allow-api: tcp:8000
- allow-ssh: tcp:22 (restricted source)

**Azure Network Security Groups:**
- HTTP_Allow: Port 80, Any source
- HTTPS_Allow: Port 443, Any source
- API_Allow: Port 8000, Any source
- SSH_Allow: Port 22, Restricted source

## Environment-Specific Settings

### **Development Environment**
```bash
DEBUG=True
LOG_LEVEL=DEBUG
ENVIRONMENT=development
CORS_ENABLED=True
ALLOWED_ORIGINS=http://localhost:3000
MAX_TOKENS=1000
```

### **Staging Environment**
```bash
DEBUG=False
LOG_LEVEL=INFO
ENVIRONMENT=staging
CORS_ENABLED=True
ALLOWED_ORIGINS=https://staging.yourdomain.com
MAX_TOKENS=1000
```

### **Production Environment**
```bash
DEBUG=False
LOG_LEVEL=WARNING
ENVIRONMENT=production
CORS_ENABLED=True
ALLOWED_ORIGINS=https://yourdomain.com
MAX_TOKENS=500
```

## Performance Tuning

### **System Limits**
```bash
# Add to /etc/security/limits.conf
ubuntu soft nofile 65536
ubuntu hard nofile 65536
```

### **Nginx Performance**
```nginx
# Add to /etc/nginx/nginx.conf
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
gzip on;
gzip_types text/plain application/json text/css application/javascript;
```

### **PM2 Performance**
```bash
# Use cluster mode for CPU-intensive tasks
pm2 start app.js -i max  # Use all CPU cores

# Set memory limits
pm2 start app.js --max-memory-restart 200M
```

## Configuration Validation

### **Check Configuration**
```bash
# Test environment file loading
cd /path/to/claude-ai-agent/backend
source venv/bin/activate
python -c "
import os
from dotenv import load_dotenv
load_dotenv()
print('API Key:', 'SET' if os.getenv('ANTHROPIC_API_KEY') else 'NOT SET')
print('Model:', os.getenv('MODEL_NAME'))
print('Database:', os.getenv('DATABASE_URL'))
"
```

### **Test API Connection**
```bash
# Test Anthropic API connection
python -c "
import anthropic
import os
from dotenv import load_dotenv
load_dotenv()
client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
try:
    response = client.messages.create(
        model='claude-3-sonnet-20240229',
        max_tokens=10,
        messages=[{'role': 'user', 'content': 'test'}]
    )
    print('✅ API connection successful')
except Exception as e:
    print('❌ API connection failed:', str(e))
"
```

### **Validate System Configuration**
```bash
# Run comprehensive configuration check
./scripts/health-check.sh

# Check specific configurations
./scripts/monitor.sh
```

## Security Best Practices

### **File Permissions**
The setup script automatically sets secure permissions:
```bash
# Environment file (sensitive)
chmod 600 .env

# Scripts (executable)
chmod 755 scripts/*.sh

# Data directory
chmod 755 data/
chmod 644 data/*.db

# Log directory
chmod 755 logs/
chmod 644 logs/*.log
```

### **API Key Security**
- Never commit `.env` files to version control
- Use environment-specific API keys
- Rotate keys regularly
- Monitor API usage for anomalies

### **Network Security**
- Use HTTPS in production
- Set appropriate CORS origins
- Enable rate limiting
- Monitor failed authentication attempts

### **Database Security**
- Regular automated backups
- Database integrity checks
- Secure file permissions
- Monitor database size and performance

## Troubleshooting Configuration

### **Common Issues**

**Environment Variables Not Loading**
```bash
# Check if .env file exists and has correct permissions
ls -la /path/to/claude-ai-agent/.env
# Should show: -rw------- (600 permissions)

# Test loading
cd backend && source venv/bin/activate
python -c "from dotenv import load_dotenv; load_dotenv(); print('Loaded')"
```

**Database Connection Issues**
```bash
# Check database file permissions
ls -la /path/to/claude-ai-agent/data/
# Ensure user owns the files

# Test database connectivity
sqlite3 /path/to/claude-ai-agent/data/agent_database.db ".tables"
```

**API Key Issues**
```bash
# Verify API key format (should start with 'sk-ant-')
grep ANTHROPIC_API_KEY /path/to/claude-ai-agent/.env

# Test API key validity
./scripts/health-check.sh
```

**Port Conflicts**
```bash
# Check what's using your ports
sudo netstat -tlnp | grep :8000
sudo netstat -tlnp | grep :3000

# Kill conflicting processes
sudo kill -9 PID_NUMBER
```

### **Configuration Recovery**
```bash
# Reset to default configuration
./scripts/setup.sh

# Restore from backup
cp backups/env_backup_YYYYMMDD.backup .env

# Regenerate configuration
./scripts/recover.sh
```

For additional troubleshooting, see [Troubleshooting Guide](troubleshooting-guide.md).
