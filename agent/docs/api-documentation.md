# Universal API Documentation

Complete API reference for Claude AI Agent universal deployment system with comprehensive monitoring, health scoring, and platform-adaptive features.

## Base URL

The API automatically adapts to your deployment environment:

```
# Direct backend access
http://your-server-ip:8000

# Through Nginx proxy (recommended)
http://your-server-ip/api

# Local development
http://localhost:8000
```

## Universal Response Format

All API responses follow this adaptive format based on your environment:

```json
{
  "success": true|false,
  "response": "response_content",
  "timestamp": "2024-01-08T12:00:00Z",
  "request_id": 123,
  "platform_info": {
    "cloud_provider": "aws|gcp|azure|local|wsl",
    "environment": "production|staging|development",
    "deployment_type": "universal"
  },
  "session_stats": {
    "total_requests": 10,
    "total_tokens": 1500,
    "session_duration": "0:15:30",
    "health_score": 95.2
  }
}
```

## Health and Monitoring Endpoints

### **1. Comprehensive Health Check**

Returns detailed health information with scoring algorithm used by monitoring scripts.

**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "healthy|degraded|critical",
  "health_score": 95.2,
  "health_grade": "excellent|good|needs_attention|critical",
  "system_info": {
    "cloud_provider": "aws",
    "os_type": "debian", 
    "package_manager": "apt",
    "user_type": "ubuntu",
    "service_manager": "systemctl"
  },
  "resources": {
    "cpu_percent": 15.2,
    "memory_percent": 45.8,
    "disk_percent": 23.1,
    "load_average": [0.5, 0.3, 0.2],
    "uptime": "2 days, 14:30:25"
  },
  "services": {
    "backend_api": {
      "status": "online",
      "response_time": 0.45,
      "pid": 1234,
      "memory_mb": 120,
      "cpu_percent": 5.2
    },
    "frontend": {
      "status": "online", 
      "port": 3000,
      "build_exists": true
    },
    "nginx": {
      "status": "active",
      "config_valid": true,
      "connections": 15
    },
    "database": {
      "status": "healthy",
      "integrity": "ok",
      "size_mb": 15.7,
      "tables": 4,
      "last_backup": "2024-01-08T03:00:00Z"
    }
  },
  "network": {
    "external_connectivity": true,
    "anthropic_api_reachable": true,
    "ports": {
      "80": "listening",
      "443": "listening", 
      "8000": "listening",
      "3000": "listening"
    }
  },
  "security": {
    "firewall_active": true,
    "ssl_configured": false,
    "env_permissions": "600",
    "api_key_configured": true
  },
  "recommendations": [
    "System is operating optimally",
    "Consider enabling SSL for production"
  ],
  "timestamp": "2024-01-08T12:00:00Z"
}
```

### **2. Real-Time System Metrics**

Provides detailed metrics used by the monitoring dashboard.

**Endpoint:** `GET /metrics`

**Response:**
```json
{
  "platform": {
    "cloud_provider": "aws",
    "instance_id": "i-1234567890abcdef0",
    "region": "us-east-1",
    "instance_type": "t3.small",
    "public_ip": "1.2.3.4"
  },
  "system": {
    "cpu": {
      "usage_percent": 15.2,
      "load_1min": 0.5,
      "load_5min": 0.3,
      "load_15min": 0.2,
      "cores": 2
    },
    "memory": {
      "total_gb": 2.0,
      "used_gb": 0.9,
      "usage_percent": 45.8,
      "available_gb": 1.1
    },
    "disk": {
      "total_gb": 60,
      "used_gb": 14,
      "usage_percent": 23.1,
      "available_gb": 46
    },
    "network": {
      "bytes_sent": 1024000,
      "bytes_received": 2048000,
      "connections_active": 15
    }
  },
  "application": {
    "processes": {
      "claude-backend": {
        "status": "online",
        "pid": 1234,
        "cpu_percent": 5.2,
        "memory_mb": 120,
        "uptime": "2d 14h 30m",
        "restarts": 0
      },
      "claude-frontend": {
        "status": "online",
        "pid": 5678,
        "cpu_percent": 2.1,
        "memory_mb": 80,
        "uptime": "2d 14h 30m",
        "restarts": 0
      }
    },
    "performance": {
      "requests_per_minute": 12.5,
      "avg_response_time": 1.15,
      "error_rate": 0.0,
      "total_requests": 1450,
      "total_errors": 0
    }
  },
  "database": {
    "size_mb": 15.7,
    "tables": {
      "conversation_logs": 1250,
      "user_sessions": 89,
      "system_metrics": 2880,
      "api_usage": 30
    },
    "performance": {
      "query_time_avg": 0.05,
      "last_backup": "2024-01-08T03:00:00Z",
      "integrity_status": "ok"
    }
  },
  "api_usage": {
    "today": {
      "requests": 142,
      "tokens": 15420,
      "estimated_cost_usd": 2.31
    },
    "this_month": {
      "requests": 4250,
      "tokens": 462000,
      "estimated_cost_usd": 69.30
    }
  },
  "timestamp": "2024-01-08T12:00:00Z"
}
```

### **3. Platform Information**

Returns environment detection results used by universal scripts.

**Endpoint:** `GET /platform`

**Response:**
```json
{
  "detection": {
    "cloud_provider": "aws",
    "os_type": "debian",
    "package_manager": "apt",
    "service_manager": "systemctl",
    "user_type": "ubuntu",
    "architecture": "x86_64"
  },
  "environment": {
    "project_root": "/home/ubuntu/claude-ai-agent",
    "public_ip": "1.2.3.4",
    "instance_id": "i-1234567890abcdef0",
    "deployment_type": "universal"
  },
  "capabilities": {
    "auto_recovery": true,
    "health_monitoring": true,
    "backup_system": true,
    "universal_scripts": true
  },
  "versions": {
    "system_version": "1.0.0",
    "node_version": "v18.17.0",
    "python_version": "3.10.12",
    "nginx_version": "1.22.1"
  }
}
```

## Chat and Conversation Endpoints

### **4. Universal Chat Interface**

Adaptive chat endpoint that works across all platforms.

**Endpoint:** `POST /chat`

**Request Body:**
```json
{
  "message": "Your message to Claude",
  "session_id": "optional-session-id",
  "options": {
    "max_tokens": 1000,
    "model": "claude-3-sonnet-20240229"
  }
}
```

**Response:**
```json
{
  "success": true,
  "response": "Claude's response to your message",
  "metadata": {
    "tokens_used": 245,
    "processing_time": 1.23,
    "model": "claude-3-sonnet-20240229",
    "cost_estimate": 0.00368
  },
  "session_info": {
    "session_id": "user-123-session",
    "message_count": 15,
    "total_tokens": 3420,
    "session_duration": "0:25:15",
    "created_at": "2024-01-08T11:35:00Z"
  },
  "system_status": {
    "health_score": 95.2,
    "response_quality": "optimal",
    "resource_usage": "normal"
  },
  "timestamp": "2024-01-08T12:00:00Z",
  "request_id": 15
}
```

### **5. Session Management**

Enhanced session management with monitoring integration.

**Get Session Details:**
**Endpoint:** `GET /sessions/{session_id}`

**Response:**
```json
{
  "success": true,
  "session": {
    "session_id": "user-123-session",
    "created_at": "2024-01-08T11:35:00Z",
    "last_activity": "2024-01-08T12:00:00Z",
    "status": "active",
    "platform_info": {
      "user_agent": "Mozilla/5.0...",
      "ip_address": "192.168.1.100",
      "location": "external"
    }
  },
  "statistics": {
    "total_messages": 30,
    "total_tokens": 4520,
    "total_cost": 0.0678,
    "avg_response_time": 1.15,
    "session_duration": "0:25:15"
  },
  "recent_activity": [
    {
      "timestamp": "2024-01-08T12:00:00Z",
      "type": "message",
      "tokens": 45,
      "processing_time": 0.85
    }
  ],
  "conversation_summary": {
    "topics": ["python", "deployment", "monitoring"],
    "message_count": 30,
    "quality_score": 4.8
  }
}
```

## Monitoring and Administration

### **6. System Status Dashboard**

Comprehensive status endpoint for admin dashboards.

**Endpoint:** `GET /admin/status`

**Response:**
```json
{
  "system": {
    "health_score": 95.2,
    "status": "excellent",
    "uptime": "2 days, 14:30:25",
    "deployment_info": {
      "cloud_provider": "aws",
      "environment": "production",
      "version": "1.0.0",
      "deployed_at": "2024-01-06T10:15:00Z"
    }
  },
  "services": {
    "backend": {
      "status": "healthy",
      "uptime": "2d 14h 30m",
      "memory_usage": "120MB",
      "cpu_usage": "5.2%",
      "response_time": "0.45s"
    },
    "frontend": {
      "status": "healthy", 
      "build_date": "2024-01-06T10:20:00Z",
      "serving": "production_build"
    },
    "nginx": {
      "status": "active",
      "connections": 15,
      "requests_per_minute": 12.5
    },
    "database": {
      "status": "healthy",
      "size": "15.7MB",
      "integrity": "ok",
      "last_backup": "2024-01-08T03:00:00Z"
    }
  },
  "usage": {
    "active_sessions": 5,
    "total_conversations": 1250,
    "today_requests": 142,
    "today_tokens": 15420,
    "estimated_monthly_cost": 69.30
  },
  "alerts": [],
  "recommendations": [
    "System operating optimally",
    "Consider SSL setup for production"
  ]
}
```

### **7. Real-Time Monitoring Stream**

WebSocket endpoint for real-time monitoring (if available).

**Endpoint:** `WS /monitor`

**Message Format:**
```json
{
  "type": "system_update",
  "timestamp": "2024-01-08T12:00:00Z",
  "data": {
    "cpu_percent": 15.2,
    "memory_percent": 45.8,
    "health_score": 95.2,
    "active_requests": 3,
    "response_time": 0.45
  }
}
```

## Backup and Recovery Endpoints

### **8. Backup Management**

Control backup operations through API.

**Create Backup:**
**Endpoint:** `POST /admin/backup`

**Response:**
```json
{
  "success": true,
  "backup_info": {
    "backup_id": "backup_20240108_120000",
    "created_at": "2024-01-08T12:00:00Z",
    "files": {
      "database": "database_20240108_120000.db",
      "configuration": "config_20240108_120000.tar.gz",
      "logs": "logs_20240108_120000.tar.gz"
    },
    "total_size": "45.2MB",
    "integrity_verified": true
  },
  "retention": {
    "days": 30,
    "total_backups": 15,
    "oldest_backup": "2024-01-01T03:00:00Z"
  }
}
```

**List Backups:**
**Endpoint:** `GET /admin/backups`

**Response:**
```json
{
  "backups": [
    {
      "backup_id": "backup_20240108_120000",
      "created_at": "2024-01-08T12:00:00Z",
      "size": "45.2MB",
      "type": "automatic",
      "integrity": "verified"
    }
  ],
  "retention_policy": {
    "days": 30,
    "auto_cleanup": true
  },
  "storage_info": {
    "total_used": "680MB",
    "available": "59.3GB"
  }
}
```

## Configuration Management

### **9. Environment Configuration**

Manage system configuration (sensitive data excluded).

**Endpoint:** `GET /admin/config`

**Response:**
```json
{
  "platform": {
    "cloud_provider": "aws",
    "deployment_type": "universal",
    "environment": "production"
  },
  "services": {
    "backend_port": 8000,
    "frontend_port": 3000,
    "nginx_enabled": true,
    "ssl_enabled": false
  },
  "features": {
    "health_monitoring": true,
    "auto_backup": true,
    "rate_limiting": true,
    "metrics_collection": true
  },
  "performance": {
    "max_tokens": 1000,
    "rate_limit_requests": 100,
    "rate_limit_window": 3600
  },
  "security": {
    "cors_enabled": true,
    "firewall_configured": true,
    "api_key_configured": true
  }
}
```

## Error Handling and Codes

### **Universal Error Response Format**
```json
{
  "success": false,
  "error": {
    "type": "rate_limit|connection_error|auth_error|system_error",
    "message": "Human-readable error description",
    "code": "ERROR_CODE",
    "details": {
      "platform": "aws",
      "component": "backend|frontend|database|nginx",
      "resolution": "Suggested resolution steps"
    }
  },
  "system_info": {
    "health_score": 85.0,
    "affected_services": ["backend"],
    "auto_recovery": "attempted|successful|failed"
  },
  "timestamp": "2024-01-08T12:00:00Z"
}
```

### **HTTP Status Codes**
- `200` - Success
- `400` - Bad Request (validation error)
- `401` - Unauthorized (future authentication)
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error
- `503` - Service Unavailable (maintenance/overload)

### **Custom Error Types**
- `system_healthy` - All systems operational
- `degraded_performance` - Reduced performance
- `service_unavailable` - Specific service down
- `maintenance_mode` - System in maintenance
- `configuration_error` - Configuration problem
- `platform_error` - Platform-specific issue

## SDK and Integration Examples

### **Universal Python Client**
```python
import requests
import json
from typing import Dict, Optional

class UniversalClaudeClient:
    def __init__(self, base_url: str, timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.session = requests.Session()
        
    def get_platform_info(self) -> Dict:
        """Get platform detection and capabilities."""
        response = self.session.get(f"{self.base_url}/platform")
        return response.json()
    
    def health_check(self) -> Dict:
        """Comprehensive health check with scoring."""
        response = self.session.get(f"{self.base_url}/health")
        return response.json()
    
    def chat(self, message: str, session_id: Optional[str] = None) -> Dict:
        """Send message with full session tracking."""
        payload = {"message": message}
        if session_id:
            payload["session_id"] = session_id
            
        response = self.session.post(
            f"{self.base_url}/chat",
            json=payload,
            timeout=self.timeout
        )
        return response.json()
    
    def get_metrics(self) -> Dict:
        """Get comprehensive system metrics."""
        response = self.session.get(f"{self.base_url}/metrics")
        return response.json()
    
    def create_backup(self) -> Dict:
        """Trigger system backup."""
        response = self.session.post(f"{self.base_url}/admin/backup")
        return response.json()

# Usage example
client = UniversalClaudeClient("http://your-server-ip:8000")

# Check platform capabilities
platform = client.get_platform_info()
print(f"Running on {platform['detection']['cloud_provider']}")

# Monitor health
health = client.health_check()
print(f"Health Score: {health['health_score']}%")

# Chat with monitoring
result = client.chat("Hello Claude!", "my-session")
print(f"Response: {result['response']}")
print(f"Health: {result['system_status']['health_score']}%")
```

### **JavaScript Universal Client**
```javascript
class UniversalClaudeClient {
    constructor(baseUrl, options = {}) {
        this.baseUrl = baseUrl.replace(/\/+$/, '');
        this.timeout = options.timeout || 30000;
    }
    
    async getPlatformInfo() {
        const response = await fetch(`${this.baseUrl}/platform`);
        return await response.json();
    }
    
    async healthCheck() {
        const response = await fetch(`${this.baseUrl}/health`);
        return await response.json();
    }
    
    async chat(message, sessionId = null) {
        const payload = { message };
        if (sessionId) payload.session_id = sessionId;
        
        const response = await fetch(`${this.baseUrl}/chat`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        return await response.json();
    }
    
    async getMetrics() {
        const response = await fetch(`${this.baseUrl}/metrics`);
        return await response.json();
    }
    
    async monitorHealth(callback, interval = 30000) {
        const monitor = async () => {
            try {
                const health = await this.healthCheck();
                callback(health);
            } catch (error) {
                callback({ error: error.message });
            }
        };
        
        monitor(); // Initial check
        return setInterval(monitor, interval);
    }
}

// Usage
const client = new UniversalClaudeClient('http://your-server-ip:8000');

// Platform detection
client.getPlatformInfo().then(platform => {
    console.log(`Platform: ${platform.detection.cloud_provider}`);
});

// Continuous health monitoring
client.monitorHealth(health => {
    if (health.error) {
        console.error('Health check failed:', health.error);
    } else {
        console.log(`Health: ${health.health_score}% - ${health.status}`);
    }
}, 30000);
```

## Testing and Validation

### **API Health Validation**
```bash
# Test platform detection
curl -s http://your-server-ip:8000/platform | jq '.detection'

# Comprehensive health check
curl -s http://your-server-ip:8000/health | jq '.health_score'

# Test chat functionality
curl -X POST http://your-server-ip:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Test universal deployment"}' | jq '.system_status'

# Monitor real-time metrics
curl -s http://your-server-ip:8000/metrics | jq '.system.cpu'
```

This universal API documentation now accurately reflects the sophisticated monitoring, platform detection, and management capabilities that are actually implemented in the scripts, rather than describing a basic system.
