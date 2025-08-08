# Configuration Guide

Comprehensive configuration guide for Claude AI Agent deployment.

## Environment Variables

All configuration is managed through the `.env` file located in the project root directory.

### Core Configuration

```bash
# Project root: /home/ubuntu/claude-ai-agent/.env

# =====================================
# Claude AI Agent Configuration
# =====================================

# Anthropic API Configuration
ANTHROPIC_API_KEY=sk-ant-your-key-here
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
SECRET_KEY=your-32-character-secret-key
ACCESS_TOKEN_EXPIRE_MINUTES=60

# AWS Configuration
AWS_REGION=us-east-1
STATIC_IP=your-static-ip
INSTANCE_ID=your-instance-id

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
```

## Detailed Configuration Options

### Anthropic API Settings

**ANTHROPIC_API_KEY**
- **Required**: Yes
- **Description**: Your Anthropic API key from https://console.anthropic.com/
- **Format**: `sk-ant-...`
- **Security**: Keep this secure, never commit to version control

**MODEL_NAME**
- **Default**: `claude-3-sonnet-20240229`
- **Options**: 
  - `claude-3-sonnet-20240229` (recommended)
  - `claude-3-opus-20240229` (more capable, higher cost)
  - `claude-3-haiku-20240307` (faster, lower cost)
- **Description**: Which Claude model to use

**MAX_TOKENS**
- **Default**: `1000`
- **Range**: `1-4096`
- **Description**: Maximum tokens per response
- **Cost Impact**: Higher values increase API costs

### Server Configuration

**HOST**
- **Default**: `0.0.0.0`
- **Description**: Server bind address
- **Production**: Keep as `0.0.0.0` to accept connections from Nginx

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
- **Description**: Path to application log file
- **Rotation**: Logs rotate automatically when they reach 10MB

### Monitoring Configuration

**HEALTH_CHECK_INTERVAL**
- **Default**: `300` (5 minutes)
- **Description**: Health check frequency in seconds

**METRICS_COLLECTION**
- **Default**: `True`
- **Description**: Enable/disable metrics collection
- **Performance**: Minimal impact when enabled

### Backup Configuration

**BACKUP_RETENTION_DAYS**
- **Default**: `30`
- **Description**: How long to keep database backups

**AUTO_BACKUP**
- **Default**: `True`
- **Description**: Enable automatic daily backups

## Nginx Configuration

### Basic Configuration
```nginx
# /etc/nginx/sites-available/claude-agent

server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or IP
    
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

# Check status
sudo ufw status
```

### AWS Lightsail Firewall
Configure these rules in the Lightsail console:
- HTTP (80) - Anywhere
- HTTPS (443) - Anywhere  
- Custom TCP (8000) - Anywhere (for direct backend access if needed)
- SSH (22) - Your IP only (recommended)

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

4. **Database Security**
   - Regular backups
   - Encrypt sensitive data
   - Use least privilege access

## Troubleshooting Configuration

### Common Issues

**Environment Variables Not Loading**
```bash
# Check if .env file exists and has correct permissions
ls -la /home/ubuntu/claude-ai-agent/.env
# Should show: -rw------- (600 permissions)
```

**Database Connection Issues**
```bash
# Check database file permissions
ls -la /home/ubuntu/claude-ai-agent/data/
# Ensure ubuntu user owns the files
```

**API Key Issues**
```bash
# Verify API key format (should start with 'sk-ant-')
grep ANTHROPIC_API_KEY /home/ubuntu/claude-ai-agent/.env
```

**Port Conflicts**
```bash
# Check what's using your ports
sudo netstat -tlnp | grep :8000
sudo netstat -tlnp | grep :3000
```

For additional troubleshooting, see [Troubleshooting Guide](TROUBLESHOOTING.md).
