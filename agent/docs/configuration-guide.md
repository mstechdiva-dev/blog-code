# Configuration Guide

Comprehensive configuration guide for Claude AI Agent deployment system.

## Configuration Files

### Primary Configuration: .env
**Location:** `~/claude-ai-agent/.env`

The main configuration file that contains all system settings. This file is automatically created by the setup script with secure defaults.

```bash
# View current configuration
cat .env

# Edit configuration
nano .env

# Secure the file (automatically set to 600)
ls -la .env
```

## Complete .env Configuration Reference

### 🔑 Anthropic API Configuration
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
4. Copy to your .env file

### 🖥️ Server Configuration
```bash
# Server host (0.0.0.0 for all interfaces)
HOST=0.0.0.0

# Backend server port
PORT=8000

# Debug mode (False for production)
DEBUG=False

# Environment mode
ENVIRONMENT=production
```

### 📊 Database Configuration
```bash
# SQLite database path (default)
DATABASE_URL=sqlite:///./data/agent_database.db

# PostgreSQL example
# DATABASE_URL=postgresql://user:password@localhost:5432/claude_agent

# MySQL example
# DATABASE_URL=mysql://user:password@localhost:3306/claude_agent
```

### 🔒 Security Configuration
```bash
# Secret key for sessions (auto-generated)
SECRET_KEY=your-secret-key-here

# Token expiration time (minutes)
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

### 🌐 CORS Configuration
```bash
# Allowed origins (* for all, specific domains for production)
ALLOWED_ORIGINS=*

# Production example:
# ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Enable/disable CORS
CORS_ENABLED=True
```

### ⚡ Rate Limiting
```bash
# Maximum requests per window
RATE_LIMIT_REQUESTS=100

# Rate limit window in seconds (3600 = 1 hour)
RATE_LIMIT_WINDOW=3600

# Burst limiting
RATE_LIMIT_BURST=10
```

### 📋 Logging Configuration
```bash
# Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
LOG_LEVEL=INFO

# Log file path
LOG_FILE=/home/ubuntu/claude-ai-agent/logs/app.log

# Enable syslog integration
SYSLOG_ENABLED=True
```

### 📈 Monitoring Configuration
```bash
# Health check interval (seconds)
HEALTH_CHECK_INTERVAL=300

# Enable metrics collection
METRICS_COLLECTION=True

# System monitoring
SYSTEM_MONITORING=True
```

### 💾 Backup Configuration
```bash
# Backup retention days
BACKUP_RETENTION_DAYS=30

# Enable automatic backups
AUTO_BACKUP=True

# Backup schedule (cron format)
BACKUP_SCHEDULE="0 3 * * *"

# Backup directory
BACKUP_DIR=/home/ubuntu/claude-ai-agent/backups
```

### ☁️ Cloud Provider Configuration
```bash
# Cloud provider (auto-detected)
CLOUD_PROVIDER=aws

# Static IP address (auto-detected)
STATIC_IP=your.public.ip.address

# Instance ID (auto-detected for cloud instances)
INSTANCE_ID=i-1234567890abcdef0

# Project root path
PROJECT_ROOT=/home/ubuntu/claude-ai-agent
```

## Configuration Validation

### Environment Variables
Important configuration values and their requirements:

**ANTHROPIC_API_KEY**
- **Required**: Yes
- **Format**: Must start with `sk-ant-`
- **Security**: Keep secret, never commit to version control

**HOST**
- **Default**: `0.0.0.0`
- **Description**: Server binding address
- **Security**: Use `127.0.0.1` for local-only access

**PORT**
- **Default**: `8000`
- **Description**: Backend server port
- **Notes**: Must match Nginx proxy configuration

**DEBUG**
- **Default**: `False`
- **Options**: `True`, `False`
- **Production**: Always set to `False`

**ENVIRONMENT**
- **Default**: `production`
- **Options**: `development`, `staging`, `production`
- **Description**: Application environment mode

### Database Configuration

**DATABASE_URL**
- **Default**: `sqlite:///./data/agent_database.db`
- **SQLite**: `sqlite:///path/to/database.db`
- **PostgreSQL**: `postgresql://user:pass@host:port/dbname`
- **MySQL**: `mysql://user:pass@host:port/dbname`

**Database Schema**
The application creates these tables automatically:
- `conversation_logs` - All chat interactions
- `user_sessions` - Session tracking and statistics
- `system_metrics` - Performance and health metrics
- `api_usage` - API usage and cost tracking

### Security Configuration

**SECRET_KEY**
- **Required**: Yes
- **Generate**: `openssl rand -hex 32`
- **Description**: Used for session security and JWT tokens
- **Security**: Must be unique and kept secret

**ACCESS_TOKEN_EXPIRE_MINUTES**
- **Default**: `60`
- **Description**: Session token expiration time in minutes

### CORS Configuration

**ALLOWED_ORIGINS**
- **Default**: `*` (allow all origins)
- **Production**: Set to your specific domain
- **Examples**: 
  - `https://yourdomain.com`
  - `http://localhost:3000,https://yourdomain.com`

**CORS_ENABLED**
- **Default**: `True`
- **Description**: Enable/disable CORS headers

### Rate Limiting

**RATE_LIMIT_REQUESTS**
- **Default**: `100`
- **Description**: Maximum requests per window

**RATE_LIMIT_WINDOW**
- **Default**: `3600` (1 hour)
- **Description**: Rate limit window in seconds

### Logging Configuration

**LOG_LEVEL**
- **Default**: `INFO`
- **Options**: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- **Development**: Use `DEBUG`
- **Production**: Use `INFO` or `WARNING`

**LOG_FILE**
- **Default**: `/home/ubuntu/claude-ai-agent/logs/app.log`
- **Description**: Main application log file path

## Nginx Configuration

### Basic Configuration
```nginx
# /etc/nginx/sites-available/claude-agent
server {
    listen 80;
    server_name your-domain.com;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;
    
    # Frontend
    location / {
        root /home/ubuntu/claude-ai-agent/frontend/build;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # Caching for static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
        access_log off;
    }
}
```

### SSL Configuration (Optional)
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

### Process Configuration
```bash
# Backend process
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" \
    --name claude-backend \
    --watch \
    --ignore-watch="node_modules logs data" \
    --max-memory-restart 500M \
    --time

# Frontend process  
pm2 start "npx serve -s build -l 3000" \
    --name claude-frontend \
    --max-memory-restart 200M \
    --time
```

### PM2 Ecosystem File (Optional)
```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'claude-backend',
      script: 'uvicorn',
      args: 'main:app --host 0.0.0.0 --port 8000',
      cwd: '/home/ubuntu/claude-ai-agent/backend',
      interpreter: '/home/ubuntu/claude-ai-agent/backend/venv/bin/python',
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
      cwd: '/home/ubuntu/claude-ai-agent/frontend',
      watch: false,
      max_memory_restart: '200M'
    }
  ]
};
```

## Firewall Configuration

### UFW (Ubuntu Firewall)
```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow API port (if needed for direct access)
sudo ufw allow 8000/tcp

# Check status
sudo ufw status
```

### Cloud Provider Firewalls

**AWS Lightsail Firewall Rules:**
```
HTTP (80) - Anywhere (0.0.0.0/0)
HTTPS (443) - Anywhere (0.0.0.0/0)
Custom TCP (8000) - Anywhere (for direct backend access if needed)
SSH (22) - Your IP only (recommended)
```

## Performance Tuning

### System Limits
```bash
# /etc/security/limits.conf
ubuntu soft nofile 65536
ubuntu hard nofile 65536
```

### Nginx Performance
```nginx
# /etc/nginx/nginx.conf adjustments
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
gzip on;
gzip_types text/plain application/json text/css application/javascript;
```

### PM2 Performance
```bash
# Set PM2 to use cluster mode for CPU-intensive tasks
pm2 start app.js -i max  # Use all CPU cores
```

## Environment-Specific Settings

### Development
```bash
DEBUG=True
LOG_LEVEL=DEBUG
ENVIRONMENT=development
CORS_ENABLED=True
ALLOWED_ORIGINS=http://localhost:3000
```

### Staging
```bash
DEBUG=False
LOG_LEVEL=INFO
ENVIRONMENT=staging
CORS_ENABLED=True
ALLOWED_ORIGINS=https://staging.yourdomain.com
```

### Production
```bash
DEBUG=False
LOG_LEVEL=WARNING
ENVIRONMENT=production
CORS_ENABLED=True
ALLOWED_ORIGINS=https://yourdomain.com
```

## Configuration Validation

### Check Configuration
```bash
# Test environment file loading
cd /home/ubuntu/claude-ai-agent/backend
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

### Test API Connection
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

## Security Best Practices

1. **API Key Security**
   - Never commit `.env` files to version control
   - Use environment-specific API keys
   - Rotate keys regularly

2. **Server Security**
   - Keep system packages updated
   - Use strong passwords
   - Enable SSH key authentication only
   - Configure fail2ban for brute force protection

3. **Application Security**
   - Use HTTPS in production
   - Set appropriate CORS origins
   - Enable rate limiting
   - Validate all inputs

4. **File Permissions**
   - Set `.env` file to 600 (owner read/write only)
   - Secure log directory access
   - Protect backup files

## Troubleshooting Configuration

### Common Issues

**API Key Not Working:**
- Verify key starts with `sk-ant-`
- Check for extra spaces or characters
- Ensure key has sufficient credits

**Services Not Starting:**
- Check port availability: `netstat -tlnp | grep :8000`
- Verify file permissions
- Check logs: `pm2 logs`

**Database Issues:**
- Ensure data directory exists and is writable
- Check database URL format
- Verify SQLite installation

**CORS Errors:**
- Check `ALLOWED_ORIGINS` setting
- Verify frontend and backend URLs match
- Test with `ALLOWED_ORIGINS=*` temporarily

For additional configuration help, see:
- [Installation Guide](installation-guide.md) for setup issues
- [Monitoring Guide](monitoring-guide.md) for performance tuning
- [Troubleshooting Guide](troubleshooting-guide.md) for specific problems
