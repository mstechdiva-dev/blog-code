# API Documentation

Complete API reference for Claude AI Agent backend services.

## Base URL

```
http://your-server-ip:8000
```

All API endpoints are prefixed with `/api` when accessed through Nginx proxy:
```
http://your-server-ip/api
```

## Authentication

Currently, no authentication is required. Future versions may include API key or session-based authentication.

## Response Format

All API responses follow this standard format:

```json
{
  "success": true|false,
  "response": "response_content",
  "timestamp": "2024-01-01T12:00:00Z",
  "request_id": 123,
  "session_stats": {
    "total_requests": 10,
    "total_tokens": 1500,
    "session_duration": "0:15:30"
  }
}
```

## Core Endpoints

### 1. Chat Completion

Send a message to Claude and get a response.

**Endpoint:** `POST /chat`

**Request Body:**
```json
{
  "message": "Your message to Claude",
  "session_id": "optional-session-id"
}
```

**Response:**
```json
{
  "success": true,
  "response": "Claude's response to your message",
  "tokens_used": 245,
  "processing_time": 1.23,
  "model": "claude-3-sonnet-20240229",
  "timestamp": "2024-01-01T12:00:00Z",
  "request_id": 15,
  "session_stats": {
    "total_requests": 15,
    "total_tokens": 3420,
    "total_errors": 0,
    "conversation_length": 30,
    "session_duration": "0:25:15",
    "avg_response_time": 1.15,
    "error_rate": 0.0
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "response": "I'm experiencing high demand. Please try again in a few moments.",
  "error": "Rate limit exceeded",
  "error_type": "rate_limit",
  "processing_time": 0.05,
  "timestamp": "2024-01-01T12:00:00Z",
  "request_id": 16,
  "session_stats": {
    "total_requests": 16,
    "total_errors": 1,
    "error_rate": 6.25
  }
}
```

**cURL Example:**
```bash
curl -X POST http://your-server-ip:8000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, can you help me with Python programming?",
    "session_id": "user-123-session"
  }'
```

### 2. Health Check

Check system health and API connectivity.

**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "healthy",
  "api_connection": true,
  "session_active": true,
  "conversation_length": 10,
  "server_info": "CPU: 15.2%, RAM: 45.8%, Disk: 23.1%",
  "timestamp": "2024-01-01T12:00:00Z",
  "uptime": "2 days, 14:30:25",
  "version": "1.0.0"
}
```

**cURL Example:**
```bash
curl http://your-server-ip:8000/health
```

### 3. Session Management

#### Get Session History

**Endpoint:** `GET /sessions/{session_id}`

**Response:**
```json
{
  "success": true,
  "session_id": "user-123-session",
  "conversation_history": [
    {
      "role": "user",
      "content": "Hello Claude",
      "timestamp": "2024-01-01T12:00:00Z",
      "token_estimate": 3
    },
    {
      "role": "assistant", 
      "content": "Hello! How can I help you today?",
      "timestamp": "2024-01-01T12:00:01Z",
      "tokens_used": 12,
      "processing_time": 0.85
    }
  ],
  "session_stats": {
    "created_at": "2024-01-01T11:45:00Z",
    "total_messages": 20,
    "total_tokens": 2450,
    "session_duration": "0:15:30"
  }
}
```

#### Reset Session

**Endpoint:** `POST /sessions/{session_id}/reset`

**Response:**
```json
{
  "success": true,
  "message": "Session reset successfully",
  "session_id": "user-123-session"
}
```

### 4. System Metrics

Get detailed system performance metrics.

**Endpoint:** `GET /metrics`

**Response:**
```json
{
  "system": {
    "cpu_percent": 15.2,
    "memory_percent": 45.8,
    "disk_percent": 23.1,
    "uptime": "2 days, 14:30:25"
  },
  "application": {
    "active_sessions": 5,
    "requests_per_minute": 12.5,
    "total_requests": 1450,
    "total_errors": 23,
    "avg_response_time": 1.15,
    "error_rate": 1.6
  },
  "api_usage": {
    "total_tokens_today": 15420,
    "successful_requests": 142,
    "failed_requests": 3,
    "estimated_cost": 2.45
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 5. Conversation Management

#### Save Conversation

**Endpoint:** `POST /conversations/save`

**Request Body:**
```json
{
  "session_id": "user-123-session",
  "filename": "optional-custom-filename.json"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Conversation saved successfully",
  "filename": "conversation_20240101_120000.json",
  "filepath": "/home/ubuntu/claude-ai-agent/data/conversation_20240101_120000.json"
}
```

#### Load Conversation

**Endpoint:** `POST /conversations/load`

**Request Body:**
```json
{
  "filename": "conversation_20240101_120000.json",
  "session_id": "user-123-session"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Conversation loaded successfully",
  "messages_loaded": 25,
  "session_id": "user-123-session"
}
```

#### Get Conversation Summary

**Endpoint:** `GET /conversations/{session_id}/summary`

**Response:**
```json
{
  "success": true,
  "summary": "The user asked about Python programming best practices and deployment strategies. We discussed FastAPI development, database design, and AWS deployment options.",
  "message_count": 30,
  "session_duration": "0:45:15",
  "topics_covered": ["python", "fastapi", "databases", "aws", "deployment"]
}
```

## Database Models

### ConversationLog

Stores all chat interactions.

```python
{
  "id": 1,
  "session_id": "user-123-session",
  "user_message": "Hello Claude",
  "assistant_response": "Hello! How can I help you?",
  "tokens_used": 15,
  "processing_time": 0.85,
  "timestamp": "2024-01-01T12:00:00Z",
  "success": true,
  "error_message": null,
  "error_type": null,
  "model_used": "claude-3-sonnet-20240229",
  "user_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0..."
}
```

### UserSession

Tracks user sessions and statistics.

```python
{
  "id": 1,
  "session_id": "user-123-session",
  "created_at": "2024-01-01T11:45:00Z",
  "last_activity": "2024-01-01T12:00:00Z",
  "total_messages": 20,
  "total_tokens": 2450,
  "total_processing_time": 23.5,
  "user_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "is_active": true
}
```

### SystemMetrics

Performance and health metrics.

```python
{
  "id": 1,
  "timestamp": "2024-01-01T12:00:00Z",
  "cpu_percent": 15.2,
  "memory_percent": 45.8,
  "disk_percent": 23.1,
  "active_sessions": 5,
  "requests_per_minute": 12.5,
  "total_requests": 1450,
  "total_errors": 23,
  "avg_response_time": 1.15
}
```

### APIUsage

API usage and cost tracking.

```python
{
  "id": 1,
  "date": "2024-01-01T00:00:00Z",
  "total_tokens": 15420,
  "total_requests": 145,
  "successful_requests": 142,
  "failed_requests": 3,
  "estimated_cost": 2.45,
  "model_usage": {
    "claude-3-sonnet-20240229": {
      "requests": 145,
      "tokens": 15420,
      "cost": 2.45
    }
  }
}
```

## Error Codes

### HTTP Status Codes
- `200` - Success
- `400` - Bad Request (invalid input)
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error
- `503` - Service Unavailable (API connection issues)

### Custom Error Types
- `rate_limit` - API rate limit exceeded
- `connection_error` - Cannot connect to Anthropic API
- `auth_error` - API authentication failed
- `api_error` - Anthropic API error
- `general_error` - Unexpected server error
- `validation_error` - Input validation failed

## Rate Limiting

**Default Limits:**
- 100 requests per hour per IP address
- Burst limit: 10 requests per minute

**Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

**Rate Limit Response:**
```json
{
  "success": false,
  "error": "Rate limit exceeded. Try again in 45 seconds.",
  "error_type": "rate_limit",
  "retry_after": 45
}
```

## WebSocket Support (Future)

Planning to add WebSocket support for real-time streaming responses:

```javascript
// Future WebSocket implementation
const ws = new WebSocket('ws://your-server-ip:8000/ws');
ws.send(JSON.stringify({
  "type": "chat",
  "message": "Hello Claude",
  "session_id": "user-123"
}));
```

## SDK Examples

### Python Client Example
```python
import requests
import json

class ClaudeAgentClient:
    def __init__(self, base_url):
        self.base_url = base_url.rstrip('/')
    
    def chat(self, message, session_id=None):
        payload = {"message": message}
        if session_id:
            payload["session_id"] = session_id
            
        response = requests.post(
            f"{self.base_url}/chat",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        return response.json()
    
    def health_check(self):
        response = requests.get(f"{self.base_url}/health")
        return response.json()

# Usage
client = ClaudeAgentClient("http://your-server-ip:8000")
result = client.chat("Hello, Claude!", session_id="my-session")
print(result["response"])
```

### JavaScript Client Example
```javascript
class ClaudeAgentClient {
    constructor(baseUrl) {
        this.baseUrl = baseUrl.replace(/\/+$/, '');
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
    
    async healthCheck() {
        const response = await fetch(`${this.baseUrl}/health`);
        return await response.json();
    }
}

// Usage
const client = new ClaudeAgentClient('http://your-server-ip:8000');
client.chat('Hello, Claude!', 'my-session')
    .then(result => console.log(result.response));
```

## Testing the API

### Basic Health Check Test
```bash
# Test if the API is running
curl -f http://your-server-ip:8000/health || echo "API not responding"
```

### Chat Functionality Test
```bash
# Test chat endpoint
curl -X POST http://your-server-ip:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Say hello in exactly 3 words"}' \
  | jq '.response'
```

### Load Testing (Optional)
```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Simple load test
ab -n 100 -c 10 -T application/json -p chat_payload.json \
   http://your-server-ip:8000/chat

# chat_payload.json content:
# {"message": "Hello Claude", "session_id": "load-test"}
```

## Performance Considerations

### Response Times
- **Simple queries**: 0.5-2 seconds
- **Complex queries**: 2-5 seconds  
- **Rate limited requests**: ~0.05 seconds (immediate error)

### Optimization Tips
1. Keep messages concise for faster responses
2. Use session management to maintain context
3. Implement client-side caching for static responses
4. Monitor token usage to control costs
5. Use appropriate rate limiting on client side

For deployment and configuration details, see:
- [Installation Guide](INSTALLATION.md)
- [Configuration Guide](CONFIGURATION.md)
- [Monitoring Guide](MONITORING.md)
