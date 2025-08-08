# Private Claude AI Agent - Self-Hosted Deployment

Complete deployment guide for your own private Claude AI agent with improved privacy, security, and team access.

> **🔒 Private AI Deployment:** Your own Claude AI agent that runs on YOUR servers. All conversations and data stay on your infrastructure. A practical alternative for teams and privacy-conscious users who want more control than commercial AI services.

> **🛡️ Security-Focused Setup:** Built with common security practices - rate limiting, input validation, firewall configuration, and audit logging. Reduces exposure compared to shared AI services, though security depends on your implementation and maintenance.

> **🌐 Universal Deployment:** Works seamlessly across AWS, GCP, Azure, local systems, WSL, and all major Linux distributions. One script set, any platform.

## Why Consider a Private AI Agent?

### **🛡️ Security & Privacy Benefits**
- **Reduced shared service risk** - Fewer users = smaller attack surface than massive AI platforms
- **Data control** - You decide where conversations are stored and how long to keep them
- **Custom security measures** - Implement security practices that fit your organization
- **Audit transparency** - See exactly what happens with your data (unlike black-box services)
- **Network isolation options** - Can run on internal networks or air-gapped systems

### **🔒 Privacy Improvements**
- **No external data sharing** - Conversations don't leave your infrastructure by default
- **Training data control** - Your conversations aren't used to train other AI models
- **Geographic control** - Choose where your data is stored and processed
- **Retention policies** - Decide how long to keep conversation data

### **💰 Cost Considerations**
- **Potentially lower team costs** - One deployment vs multiple subscriptions (2+ users)
- **Predictable expenses** - You see and control infrastructure and API costs
- **No vendor lock-in** - Your deployment, your choice to continue or migrate

### **🔧 Practical Customization**
- **System prompts** - Customize Claude's behavior for your specific needs
- **Integration potential** - Connect to your existing tools and databases
- **UI control** - Modify the interface to match your workflow
- **Feature additions** - Add functionality that commercial services don't offer

## What This Provides

Your own **private Claude AI agent** with practical improvements over commercial services:
- **🔒 Data Privacy** - Conversations and data stay on your servers (you control storage)
- **🛡️ Improved Security Posture** - Reduces shared service exposure (with proper setup)
- **👥 Team Access** - Multiple users on one deployment vs individual subscriptions
- **🚨 Reduced Third-Party Risk** - Less dependency on external AI service availability
- **⚙️ More Customization Control** - Modify prompts, integrate with your systems
- **📊 Usage Visibility** - See your own analytics and costs (data you control)
- **🌐 Flexible Deployment** - Choose your platform: AWS, GCP, Azure, local, or VPS

## Supported Platforms

This installation works on:
- ✅ **Amazon Web Services** (EC2, Lightsail) - ubuntu, ec2-user users
- ✅ **Google Cloud Platform** (Compute Engine) - any user type
- ✅ **Microsoft Azure** (Virtual Machines) - azureuser, admin users
- ✅ **Local Linux Machines** (Ubuntu, Fedora, Arch, Alpine, RHEL, SUSE)
- ✅ **Windows Subsystem for Linux** (WSL/WSL2)
- ✅ **VPS Providers** (DigitalOcean, Linode, Vultr, etc.)
- ✅ **Package Managers** (apt, dnf, yum, pacman, apk, zypper, brew)

The setup script automatically detects your environment and adapts accordingly.

## Features

- 🛡️ **Security-Focused Setup** - Rate limiting, firewall configuration, secure permissions
- 🔒 **Private Data Storage** - Conversations stored on your infrastructure
- 🚨 **Comprehensive Monitoring** - Real-time health checks, performance metrics, error tracking
- 👥 **Multi-user Support** - Team access without individual subscription requirements
- 💬 **Clean Web Interface** - React TypeScript frontend with conversation history
- 📊 **Usage Transparency** - See your own analytics, costs, and usage patterns
- 🔧 **Extensive Management Tools** - Backup, recovery, monitoring, and maintenance scripts
- 🛠️ **Advanced Monitoring** - Health checks, performance tracking, automated alerts
- 🌐 **Platform Flexibility** - Works on major cloud providers and local infrastructure
- 💰 **Cost-effective** - Can be cheaper than multiple individual AI subscriptions

## Quick Start

### Option 1: Universal Installer (Recommended)
```bash
# Download and run the universal setup script (auto-detects platform)
curl -fsSL https://raw.githubusercontent.com/your-repo/claude-ai-agent/main/scripts/setup.sh | bash

# The installer will:
# 1. Detect your platform (AWS/GCP/Azure/local)
# 2. Install all dependencies for your OS
# 3. Set up project structure
# 4. Configure services

# After setup, configure your API key
cd claude-ai-agent
nano .env
# Set: ANTHROPIC_API_KEY=sk-ant-your-key-here

# Deploy your application
./scripts/deploy.sh
```

### Option 2: Manual Setup
```bash
# Clone the repository
git clone https://github.com/your-repo/claude-ai-agent.git
cd claude-ai-agent

# Run platform-aware setup
./scripts/setup.sh

# Configure your API key
nano .env
# Set: ANTHROPIC_API_KEY=sk-ant-your-key-here

# Deploy the system
./scripts/deploy.sh
```

**Access your agent at:** `http://your-server-ip`

## Management Commands

### **📊 System Monitoring**
```bash
./scripts/monitor.sh         # Real-time system monitoring dashboard
./scripts/health-check.sh    # Comprehensive health analysis with scoring
./scripts/status.sh          # Quick system status overview
```

### **🔧 Deployment & Maintenance**
```bash
./scripts/setup.sh           # Universal platform setup
./scripts/deploy.sh          # Deploy/update application with validation
./scripts/recover.sh         # Emergency recovery with automatic fixes
```

### **💾 Backup & Data Management**
```bash
./scripts/backup.sh          # Comprehensive backup with validation
./scripts/restore.sh         # Restore from backup
```

### **🚀 Process Management**
```bash
pm2 status                   # Check all running services
pm2 logs                     # View application logs in real-time
pm2 restart all             # Restart all services
pm2 monit                   # Process monitoring dashboard
```

## Architecture

- **Backend:** Python FastAPI + SQLite with Anthropic SDK
- **Frontend:** React TypeScript + Material-UI  
- **Infrastructure:** Nginx reverse proxy (auto-configured for your platform)
- **Process Management:** PM2 for production reliability
- **Monitoring:** Comprehensive health checks, performance metrics, error tracking
- **Deployment:** Universal scripts supporting all major platforms
- **Database:** SQLite with automatic initialization and recovery

## Project Structure

```
claude-ai-agent/
├── backend/           # Python FastAPI application
├── frontend/          # React TypeScript app
├── scripts/           # Management and deployment scripts
│   ├── setup.sh       # Universal platform setup
│   ├── deploy.sh      # Application deployment
│   ├── monitor.sh     # Real-time monitoring
│   ├── health-check.sh # Comprehensive health analysis
│   ├── backup.sh      # Backup system
│   └── recover.sh     # Emergency recovery
├── config/            # Configuration files
├── docs/              # Documentation
├── data/              # Database and user data
├── logs/              # Application and system logs
└── backups/           # Automated backups
```

## Documentation

- [Installation Guide](docs/installation-guide.md) - Complete setup for all platforms
- [Configuration Guide](docs/configuration-guide.md) - Environment and settings
- [API Documentation](docs/api-documentation.md) - Backend API reference
- [Monitoring Guide](docs/monitoring-guide.md) - System monitoring and maintenance
- [Troubleshooting Guide](docs/troubleshooting-guide.md) - Problem resolution

## Cost Analysis

### **💰 Monthly Cost Breakdown**
- **Cloud Infrastructure:** $10-30/month (depending on provider and usage)
- **Anthropic API Usage:** $5-50/month (based on actual token usage)
- **Total Cost:** $15-80/month for unlimited team members

### **💵 Comparison with Commercial Services**
- **Commercial Alternative:** $20/user/month = $200/month for 10 users
- **Your Private Deployment:** $15-80/month total regardless of user count
- **Potential Savings:** $120-185/month for teams of 10+ users

## Security & Monitoring Features

### **🛡️ Security**
- Automatic firewall configuration
- Secure file permissions (600 for .env)
- Rate limiting and input validation
- Encrypted configuration management
- Audit logging and monitoring

### **📊 Monitoring**
- Real-time health scoring system
- Comprehensive system resource monitoring
- Database integrity checking
- Error rate tracking and alerting
- Performance metrics collection

### **🔄 Backup & Recovery**
- Automated daily backups with retention
- Database integrity validation
- Emergency recovery procedures
- Configuration backup and restoration

## Troubleshooting

### **🚨 Emergency Commands**
```bash
# If something goes wrong, run these in order:

# 1. Check overall system health
./scripts/health-check.sh

# 2. Try automatic recovery
./scripts/recover.sh

# 3. Check service status
pm2 status

# 4. View recent errors
tail -n 50 logs/app.log | grep -i error

# 5. Restart all services
pm2 restart all && sudo systemctl restart nginx
```

### **📋 Common Issues**
- **API not responding:** Check `./scripts/health-check.sh` and restart services
- **Frontend not loading:** Rebuild with `cd frontend && npm run build`
- **Database issues:** Run `./scripts/recover.sh` for automatic database repair
- **High resource usage:** Monitor with `./scripts/monitor.sh`

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**🔒 Deploy your own private Claude AI agent!** A practical solution that prioritizes privacy and control, with comprehensive monitoring and management tools for reliable operation.
