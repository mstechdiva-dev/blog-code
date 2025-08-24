# Claude AI Agent Project - Script & File Glossary

## Overview
This glossary describes every script, configuration file, and document in the Claude AI Agent project. Each entry explains the file's purpose, functionality, and role in the overall system.

---

## 🔧 Shell Scripts (.sh files)

### Core Setup Scripts

**`setup-script.sh`**
- **Purpose**: Main project initialization and system setup
- **Function**: Detects operating system, installs dependencies (Node.js, Python, Nginx, PM2), creates project structure, sets up virtual environments
- **When to use**: First-time installation on supported platforms
- **Key features**: Multi-platform OS detection, automated dependency installation, error handling

**`ubuntu_setup_script.sh`**  
- **Purpose**: Ubuntu-specific optimized setup script
- **Function**: Tailored installation process for Ubuntu 20.04/22.04 systems with Ubuntu-specific package management
- **When to use**: When running specifically on Ubuntu systems for optimized performance
- **Key features**: Ubuntu package repositories, multi-environment support (AWS/GCP/Azure/local/WSL), version-specific optimizations

### Deployment Scripts

**`deploy-script.sh`**
- **Purpose**: Cross-platform application deployment and updates
- **Function**: Builds frontend, starts backend services, configures Nginx, manages PM2 processes
- **When to use**: Deploy new versions or restart services
- **Key features**: Health checks, rollback capabilities, service management

**`ubuntu_deploy_script.sh`**
- **Purpose**: Ubuntu-optimized deployment process
- **Function**: Ubuntu-specific deployment with optimized paths and service configurations across different Ubuntu environments
- **When to use**: Deploying on Ubuntu systems for maximum compatibility
- **Key features**: Ubuntu service integration, systemd management, multi-cloud environment support

### Monitoring & Maintenance Scripts

**`monitor-script.sh`**
- **Purpose**: Real-time system monitoring and alerts
- **Function**: Tracks CPU, memory, disk usage, service health, API status, database performance
- **When to use**: Continuous monitoring (typically run via cron)
- **Key features**: Resource monitoring, automated alerts, performance metrics

**`backup-script.sh`**
- **Purpose**: Comprehensive backup and recovery system
- **Function**: Creates automated backups of database, configuration, code, and system state with integrity validation
- **When to use**: Regular automated backups or manual backup creation
- **Key features**: Incremental backups, compression, integrity checking, automated cleanup

**`health-check-script.sh`**
- **Purpose**: Comprehensive system health assessment
- **Function**: Performs detailed health checks on all system components, generates health scores, provides recommendations
- **When to use**: Regular health assessments, troubleshooting, system validation
- **Key features**: Weighted health scoring, detailed diagnostics, actionable recommendations

**`recover-script.sh`**
- **Purpose**: Emergency recovery and restoration procedures
- **Function**: Automated recovery from common failure scenarios, service restoration, data recovery
- **When to use**: System failures, service outages, emergency situations
- **Key features**: Automated diagnostics, service restoration, backup recovery

---

## 🐍 Python Application Files (.py)

**`main_fastapi_app.py`** (or `main.py`)
- **Purpose**: Core FastAPI application and API endpoints
- **Function**: Handles HTTP requests, integrates with Anthropic API, manages conversation flow, implements security middleware
- **Key components**: API routes, authentication, request/response handling, Claude integration
- **Dependencies**: FastAPI, Anthropic SDK, SQLAlchemy, Pydantic

**`database.py`**
- **Purpose**: Database models, connections, and data management
- **Function**: SQLite/PostgreSQL integration, data models, CRUD operations, session management
- **Key components**: Database models, connection pooling, data validation, migration support
- **Features**: 
  - User session tracking
  - Conversation logging
  - System metrics storage
  - API usage analytics
  - Error logging and monitoring

---

## 📚 Documentation Files (.md)

**`readme.md`**
- **Purpose**: Project overview and quick start guide
- **Function**: Provides project introduction, feature overview, installation summary, and command reference
- **Audience**: New users and developers

**`docs/installation-guide.md`**
- **Purpose**: Complete installation and setup documentation
- **Function**: Step-by-step instructions for system preparation, dependency installation, and initial configuration
- **Key sections**: System requirements, platform-specific setup, environment configuration

**`docs/api-documentation.md`**
- **Purpose**: Complete API reference documentation
- **Function**: Details all API endpoints, request/response formats, authentication, error codes
- **Key sections**: Endpoint specifications, usage examples, WebSocket support, SDK examples

**`docs/configuration-guide.md`**
- **Purpose**: Comprehensive configuration reference
- **Function**: Environment variables, security settings, performance tuning, platform-specific configurations
- **Key topics**: API keys, CORS settings, rate limiting, SSL/TLS, firewall configuration

**`docs/monitoring-guide.md`**
- **Purpose**: System monitoring and maintenance documentation
- **Function**: Setup monitoring tools, create dashboards, configure alerts, backup procedures
- **Key features**: Performance monitoring, log analysis, automated maintenance, cost tracking

**`docs/troubleshooting-guide.md`**
- **Purpose**: Problem diagnosis and resolution guide
- **Function**: Common issues, error codes, diagnostic procedures, recovery processes
- **Key sections**: Service failures, API errors, performance issues, emergency recovery

**`docs/glossary.md`** (this file)
- **Purpose**: Complete project file and script reference
- **Function**: Comprehensive documentation of all project components, their purposes, and relationships
- **Audience**: Developers, system administrators, documentation reference

---

## ⚙️ Configuration Files

**`.env`**
- **Purpose**: Environment variables and application configuration
- **Function**: Stores API keys, database URLs, security settings, feature flags
- **Security**: File permissions set to 600 (owner read/write only)
- **Key settings**: Anthropic API key, database configuration, CORS settings, rate limits

**`package.json`**
- **Purpose**: Frontend Node.js project configuration and dependencies
- **Function**: Defines React application dependencies, build scripts, development tools
- **Key scripts**: `start`, `build`, `test`, `lint`, `format`
- **Dependencies**: React, TypeScript, Material-UI, testing frameworks

**`requirements.txt`**
- **Purpose**: Python backend dependencies specification
- **Function**: Defines all Python packages required for the backend application
- **Key packages**: FastAPI, Anthropic SDK, SQLAlchemy, Uvicorn, Pydantic

**`nginx.conf` / Site configurations**
- **Purpose**: Reverse proxy and web server configuration
- **Function**: Routes requests between frontend/backend, SSL termination, security headers
- **Key features**: Load balancing, rate limiting, static file serving, security policies

**`.gitignore`**
- **Purpose**: Git version control exclusion rules
- **Function**: Prevents sensitive files and build artifacts from being committed to repository
- **Exclusions**: Environment files, logs, node_modules, Python cache, database files

**`pm2.config.js` / PM2 ecosystem**
- **Purpose**: Process manager configuration
- **Function**: Defines how Node.js and Python processes should be managed in production
- **Features**: Auto-restart, clustering, log rotation, monitoring

---

## 📊 Database & Storage Files

**`agent_database.db`**
- **Purpose**: SQLite database for development and small deployments
- **Location**: `data/` directory
- **Contains**: User sessions, conversation logs, system metrics, API usage data
- **Backup**: Automatically included in backup scripts

**Log Files (`logs/` directory)**
- **`app.log`**: Application runtime logs
- **`setup.log`**: Installation and setup logs
- **`deployment.log`**: Deployment process logs
- **`health-check.log`**: System health monitoring logs
- **`backup.log`**: Backup operation logs

---

## 🎨 Frontend Files

**`src/` directory**
- **Purpose**: React TypeScript application source code
- **Components**: Chat interface, message handling, user authentication
- **Styling**: Material-UI components, responsive design, dark/light themes

**`public/` directory**
- **Purpose**: Static assets and HTML template
- **Files**: index.html, favicon, manifest.json, robots.txt

**`build/` directory**
- **Purpose**: Production-ready compiled frontend application
- **Generated by**: `npm run build` command
- **Served by**: Nginx in production, development server in development

---

## 🔧 Utility Scripts

**`status.sh`**
- **Purpose**: Quick system status overview
- **Function**: Shows PM2 processes, system resources, service health
- **Usage**: `./scripts/status.sh`

**`logs.sh`**
- **Purpose**: Centralized log viewing utility
- **Function**: Displays and follows various application logs
- **Usage**: `./scripts/logs.sh [service]`

**`restart.sh`**
- **Purpose**: Graceful service restart utility
- **Function**: Restarts all services in proper order
- **Usage**: `./scripts/restart.sh`

---

## 💡 Usage Recommendations

**For New Installations:**
1. Read `readme.md` for project overview
2. Follow `docs/installation-guide.md` for detailed setup
3. Run `ubuntu_setup_script.sh` for Ubuntu systems
4. Configure using `docs/configuration-guide.md`
5. Deploy with `ubuntu_deploy_script.sh` or `deploy-script.sh`

**For Ongoing Operations:**
1. Monitor with `monitor-script.sh`
2. Regular backups via `backup-script.sh`  
3. Health checks using `health-check-script.sh`
4. Reference `docs/troubleshooting-guide.md` for issues

**For Development:**
1. Study `docs/api-documentation.md`
2. Modify `main_fastapi_app.py` and `database.py`
3. Test using health check scripts
4. Deploy updates with deployment scripts

**For Understanding the Project:**
1. Start with `readme.md` for overview
2. Use this `glossary.md` to understand all components
3. Reference specific documentation for detailed guidance

---

*This glossary covers all major scripts and files in the Claude AI Agent project. Each component is designed to work together to create a complete, production-ready AI agent deployment system with comprehensive setup, monitoring, backup, troubleshooting, and maintenance capabilities specifically optimized for Ubuntu environments while supporting multiple deployment scenarios.*
