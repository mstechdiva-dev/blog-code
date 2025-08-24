# Claude AI Agent

A complete, self-hosted Claude AI agent with secure deployment automation for any cloud platform. This project provides enterprise-grade security infrastructure for deploying your own private Claude AI assistant.

## Quick Start

### Option 1: Automated Setup
```bash
# 1. Download and run the universal setup script
curl -fsSL https://raw.githubusercontent.com/your-repo/claude-ai-agent/main/scripts/setup.sh | bash

# 2. Follow the prompts and add your API key when requested

# 3. Deploy your application
cd claude-ai-agent
./scripts/deploy.sh
```

### Option 2: Manual Setup
```bash
# 1. Clone the repository
git clone https://github.com/your-repo/claude-ai-agent.git
cd claude-ai-agent

# 2. Run the setup script (auto-detects your platform)
./scripts/setup.sh

# 3. Configure your API key
nano .env
# Set: ANTHROPIC_API_KEY=sk-ant-your-key-here

# 4. Deploy
./scripts/deploy.sh
```

**Access your agent at:** `http://your-server-ip`

The setup script automatically detects and configures for your specific platform.

## Architecture

- **Backend:** Python FastAPI + SQLite with Anthropic SDK
- **Frontend:** React TypeScript + Material-UI  
- **Infrastructure:** Nginx reverse proxy (platform-adaptive)
- **Process Management:** PM2 for production reliability
- **Monitoring:** Built-in metrics, logging, and health checks
- **Deployment:** Universal scripts supporting all major platforms

## Comparison with Commercial AI Services

| Feature | Private Claude Agent | ChatGPT Plus | Claude Pro |
|---------|---------------------|--------------|------------|
| **Data Location** | ✅ Your chosen servers | ❌ Provider servers | ❌ Provider servers |
| **Privacy Control** | ✅ You control policies | ⚠️ Provider policies | ⚠️ Provider policies |
| **Service Dependencies** | ⚠️ You maintain it | ✅ Provider maintains | ✅ Provider maintains |
| **Team Cost (10 users)** | ✅ ~$30-45/month | ❌ $200/month | ❌ $200/month |
| **Customization** | ✅ Full control | ⚠️ Limited options | ⚠️ Limited options |
| **Setup Complexity** | ❌ Technical setup required | ✅ Ready to use | ✅ Ready to use |
| **Updates** | ⚠️ Manual updates | ✅ Automatic | ✅ Automatic |
| **Uptime Guarantee** | ❌ You're responsible | ✅ Provider SLA | ✅ Provider SLA |
| **Feature Updates** | ⚠️ Community/self-driven | ✅ Regular updates | ✅ Regular updates |

*This is a trade-off between control/privacy and convenience/support.*

## Project Structure

```
claude-ai-agent/
├── backend/           # Python FastAPI application
├── frontend/          # React TypeScript app
├── scripts/           # Universal deployment and management scripts
├── config/            # Configuration files
├── logs/              # Application and system logs
└── data/              # Database and storage
```

## Tutorial Contents

The comprehensive guide covers:

- **Universal Platform Setup** - Auto-detection and configuration for any environment
- **Environment Configuration** - Dependencies, security, and optimization  
- **Backend Development** - Full Python implementation with database models
- **Frontend Development** - React application with modern UI components
- **Production Deployment** - Platform-adaptive configuration, process management
- **Monitoring & Maintenance** - Logging, metrics, backups, and troubleshooting

## What You Get

Deploy your own private and secure Claude AI agent with:
- **🛡️ Enterprise Security Infrastructure** - Hardened deployment with security best practices
- **🔒 100% Private & Encrypted** - Web interface accessible only to your authorized team
- **💬 Production-Ready Secure Chat** - Modern React interface with security controls
- **📊 Private Security Analytics** - Usage tracking, threat monitoring, and audit logs (all yours)
- **⚙️ Security Monitoring Suite** - Health checks, intrusion detection, and automated responses
- **🌐 Secure Universal Deployment** - Security-hardened setup for any platform
- **🚨 Zero Third-Party Exposure** - Complete isolation from shared AI service vulnerabilities

## Management Commands

```bash
# System monitoring and health
./scripts/status.sh      # Quick system status
./scripts/monitor.sh     # Real-time monitoring  
./scripts/health-check.sh # Comprehensive health analysis

# Deployment and maintenance
./scripts/deploy.sh      # Deploy/update application
./scripts/backup.sh      # Create comprehensive backup
./scripts/recover.sh     # Emergency recovery procedures

# Process management
pm2 status              # Check running services
pm2 logs               # View application logs
pm2 restart all        # Restart all services
```

## Documentation

- [Installation Guide](docs/installation-guide.md) - Platform-specific setup instructions
- [Configuration Guide](docs/configuration-guide.md) - Environment and settings
- [API Documentation](docs/api-documentation.md) - Backend API reference
- [Monitoring Guide](docs/monitoring-guide.md) - System monitoring and maintenance
- [Troubleshooting Guide](docs/troubleshooting-guide.md) - Platform-specific problem resolution
- [Project Glossary](docs/glossary.md) - Complete file and script reference

## Support

Questions about deployment on your platform? The documentation includes detailed platform-specific guides and troubleshooting for:
- AWS/GCP/Azure cloud-specific configurations
- Linux distribution differences
- Network and firewall setup
- Package manager variations

## License

MIT License - see [LICENSE](license-file.md) for details.

---

**🔒 Deploy your own private Claude AI agent!** A learning project that prioritizes privacy and control over convenience, with costs and security depending on your implementation.
