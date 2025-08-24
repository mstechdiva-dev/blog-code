"""
Claude AI Agent - Main FastAPI Application
Complete backend implementation with Claude API integration
"""

import os
import sys
import asyncio
import logging
import uuid
import time
import psutil
import json
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

import anthropic
from fastapi import FastAPI, HTTPException, Depends, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from dotenv import load_dotenv
import uvicorn

# Import our database models and functions
from database import (
    get_db, init_database, SessionLocal,
    ConversationLog, UserSession, SystemMetrics, APIUsage, ErrorLog
)

# Load environment variables
load_env_result = load_dotenv()

# Configure logging
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
log_file = os.getenv('LOG_FILE', './logs/app.log')

# Ensure logs directory exists
os.makedirs(os.path.dirname(log_file), exist_ok=True)

logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Rate limiting storage (in-memory for simplicity)
rate_limit_storage = {}

# Security
security = HTTPBearer(auto_error=False)

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000, description="The user's message")
    session_id: Optional[str] = Field(None, description="Session ID for conversation continuity")
    model: Optional[str] = Field("claude-3-sonnet-20240229", description="Claude model to use")
    max_tokens: Optional[int] = Field(1000, ge=10, le=4000, description="Maximum tokens in response")
    
    @validator('message')
    def validate_message(cls, v):
        if not v.strip():
            raise ValueError('Message cannot be empty or just whitespace')
        return v.strip()

class ChatResponse(BaseModel):
    success: bool
    response: Optional[str] = None
    session_id: str
    tokens_used: int
    processing_time: float
    model_used: str
    error: Optional[str] = None
    error_type: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    message: str
    timestamp: datetime
    api_configured: bool
    database_status: str
    system_metrics: Dict[str, Any]
    version: str = "1.0.0"

class SessionInfo(BaseModel):
    session_id: str
    created_at: datetime
    last_activity: datetime
    total_messages: int
    total_tokens: int
    avg_response_time: float

# Global variables
app_start_time = datetime.utcnow()
anthropic_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting Claude AI Agent application...")
    
    # Initialize database
    try:
        init_database()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        raise
    
    # Initialize Anthropic client
    global anthropic_client
    api_key = os.getenv('ANTHROPIC_API_KEY')
    if not api_key or api_key == 'your_anthropic_api_key_here':
        logger.error("Anthropic API key not configured")
        raise ValueError("Anthropic API key not configured")
    
    try:
        anthropic_client = anthropic.Anthropic(api_key=api_key)
        # Test the connection
        test_response = anthropic_client.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=10,
            messages=[{"role": "user", "content": "test"}]
        )
        logger.info("Anthropic API connection verified")
    except Exception as e:
        logger.error(f"Anthropic API initialization failed: {e}")
        raise
    
    # Start background tasks
    asyncio.create_task(collect_system_metrics())
    asyncio.create_task(cleanup_old_data())
    
    logger.info("Application startup completed")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Claude AI Agent application...")

# Create FastAPI app
app = FastAPI(
    title="Claude AI Agent",
    description="A production-ready Claude AI agent with comprehensive features",
    version="1.0.0",
    lifespan=lifespan
)

# CORS Configuration
allowed_origins = os.getenv('ALLOWED_ORIGINS', '*').split(',')
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Trusted Host Middleware (for production)
if os.getenv('ENVIRONMENT') == 'production':
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=os.getenv('ALLOWED_HOSTS', 'localhost').split(',')
    )

# Rate limiting middleware
async def rate_limit_check(request: Request):
    """Simple rate limiting"""
    client_ip = request.client.host
    current_time = time.time()
    
    # Get rate limit settings
    requests_per_window = int(os.getenv('RATE_LIMIT_REQUESTS', 100))
    window_seconds = int(os.getenv('RATE_LIMIT_WINDOW', 3600))
    
    # Clean old entries
    cutoff_time = current_time - window_seconds
    if client_ip in rate_limit_storage:
        rate_limit_storage[client_ip] = [
            timestamp for timestamp in rate_limit_storage[client_ip] 
            if timestamp > cutoff_time
        ]
    else:
        rate_limit_storage[client_ip] = []
    
    # Check if rate limit exceeded
    if len(rate_limit_storage[client_ip]) >= requests_per_window:
        raise HTTPException(
            status_code=429,
            detail={
                "error": f"Rate limit exceeded. Maximum {requests_per_window} requests per hour.",
                "retry_after": int(window_seconds - (current_time - min(rate_limit_storage[client_ip])))
            }
        )
    
    # Add current request
    rate_limit_storage[client_ip].append(current_time)

async def get_client_info(request: Request) -> Dict[str, str]:
    """Extract client information from request"""
    return {
        "ip": request.client.host,
        "user_agent": request.headers.get("user-agent", "Unknown"),
        "referer": request.headers.get("referer", ""),
    }

async def log_conversation(
    db: SessionLocal,
    session_id: str,
    user_message: str,
    assistant_response: str,
    tokens_used: int,
    processing_time: float,
    model_used: str,
    success: bool,
    error_message: Optional[str] = None,
    error_type: Optional[str] = None,
    client_info: Optional[Dict[str, str]] = None
):
    """Log conversation to database"""
    try:
        conversation = ConversationLog(
            session_id=session_id,
            user_message=user_message,
            assistant_response=assistant_response or "",
            tokens_used=tokens_used,
            processing_time=processing_time,
            model_used=model_used,
            success=success,
            error_message=error_message,
            error_type=error_type,
            user_ip=client_info.get("ip") if client_info else None,
            user_agent=client_info.get("user_agent") if client_info else None
        )
        db.add(conversation)
        db.commit()
    except Exception as e:
        logger.error(f"Failed to log conversation: {e}")
        db.rollback()

async def update_session_stats(db: SessionLocal, session_id: str, client_info: Dict[str, str]):
    """Update session statistics"""
    try:
        session = db.query(UserSession).filter(UserSession.session_uuid == session_id).first()
        if not session:
            session = UserSession(
                session_uuid=session_id,
                user_ip=client_info.get("ip"),
                user_agent=client_info.get("user_agent"),
                browser_info=json.dumps({"user_agent": client_info.get("user_agent")}),
                device_info=json.dumps({"ip": client_info.get("ip")})
            )
            db.add(session)
        else:
            session.last_activity = datetime.utcnow()
            session.total_messages += 1
        
        db.commit()
    except Exception as e:
        logger.error(f"Failed to update session stats: {e}")
        db.rollback()

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """Log all requests"""
    start_time = time.time()
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    logger.info(
        f"{request.method} {request.url.path} - "
        f"Status: {response.status_code} - "
        f"Time: {process_time:.3f}s - "
        f"Client: {request.client.host}"
    )
    
    return response

@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint"""
    return {
        "message": "Claude AI Agent API",
        "version": "1.0.0",
        "documentation": "/docs",
        "health": "/health",
        "chat": "/chat"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check(db: SessionLocal = Depends(get_db)):
    """Comprehensive health check"""
    try:
        # Check database
        db_status = "healthy"
        try:
            db.execute("SELECT 1").fetchone()
        except Exception as e:
            db_status = f"error: {str(e)}"
        
        # System metrics
        system_metrics = {
            "cpu_percent": psutil.cpu_percent(interval=0.1),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_percent": psutil.disk_usage('/').percent,
            "uptime_seconds": int((datetime.utcnow() - app_start_time).total_seconds())
        }
        
        # API configuration check
        api_configured = bool(
            os.getenv("ANTHROPIC_API_KEY") and 
            os.getenv("ANTHROPIC_API_KEY") != "your_anthropic_api_key_here"
        )
        
        return HealthResponse(
            status="healthy",
            message="Claude AI Agent is running normally",
            timestamp=datetime.utcnow(),
            api_configured=api_configured,
            database_status=db_status,
            system_metrics=system_metrics
        )
    
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")

@app.post("/chat", response_model=ChatResponse)
async def chat_with_claude(
    request: ChatRequest,
    background_tasks: BackgroundTasks,
    http_request: Request,
    db: SessionLocal = Depends(get_db)
):
    """Main chat endpoint"""
    
    # Rate limiting
    await rate_limit_check(http_request)
    
    # Generate session ID if not provided
    session_id = request.session_id or str(uuid.uuid4())
    
    start_time = time.time()
    client_info = await get_client_info(http_request)
    
    try:
        # Get conversation history for context
        recent_conversations = db.query(ConversationLog).filter(
            ConversationLog.session_id == session_id,
            ConversationLog.success == True
        ).order_by(ConversationLog.timestamp.desc()).limit(10).all()
        
        # Build message history for Claude
        messages = []
        for conv in reversed(recent_conversations):
            messages.append({"role": "user", "content": conv.user_message})
            messages.append({"role": "assistant", "content": conv.assistant_response})
        
        # Add current message
        messages.append({"role": "user", "content": request.message})
        
        # Call Claude API
        try:
            response = anthropic_client.messages.create(
                model=request.model,
                max_tokens=request.max_tokens,
                messages=messages,
                system="You are Claude, a helpful AI assistant created by Anthropic. You are running on a private server deployment. Be helpful, harmless, and honest in your responses."
            )
            
            assistant_response = response.content[0].text if response.content else ""
            tokens_used = response.usage.input_tokens + response.usage.output_tokens
            
        except anthropic.RateLimitError as e:
            logger.warning(f"Anthropic rate limit: {e}")
            raise HTTPException(
                status_code=429,
                detail={
                    "error": "API rate limit exceeded. Please try again later.",
                    "error_type": "api_rate_limit",
                    "retry_after": 60
                }
            )
        except anthropic.APIError as e:
            logger.error(f"Anthropic API error: {e}")
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "AI service temporarily unavailable. Please try again.",
                    "error_type": "api_error"
                }
            )
        except Exception as e:
            logger.error(f"Unexpected Claude API error: {e}")
            raise HTTPException(
                status_code=500,
                detail={
                    "error": "Internal server error occurred.",
                    "error_type": "general_error"
                }
            )
        
        processing_time = time.time() - start_time
        
        # Background tasks for logging
        background_tasks.add_task(
            log_conversation,
            db, session_id, request.message, assistant_response,
            tokens_used, processing_time, request.model, True,
            client_info=client_info
        )
        background_tasks.add_task(update_session_stats, db, session_id, client_info)
        
        return ChatResponse(
            success=True,
            response=assistant_response,
            session_id=session_id,
            tokens_used=tokens_used,
            processing_time=processing_time,
            model_used=request.model
        )
        
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        processing_time = time.time() - start_time
        error_msg = str(e)
        
        logger.error(f"Chat endpoint error: {error_msg}")
        
        # Log failed conversation
        background_tasks.add_task(
            log_conversation,
            db, session_id, request.message, None, 0, processing_time,
            request.model, False, error_msg, "general_error", client_info
        )
        
        return ChatResponse(
            success=False,
            response=None,
            session_id=session_id,
            tokens_used=0,
            processing_time=processing_time,
            model_used=request.model,
            error="An unexpected error occurred",
            error_type="general_error"
        )

@app.get("/sessions/{session_id}", response_model=SessionInfo)
async def get_session_info(session_id: str, db: SessionLocal = Depends(get_db)):
    """Get session information"""
    session = db.query(UserSession).filter(UserSession.session_uuid == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return SessionInfo(
        session_id=session.session_uuid,
        created_at=session.created_at,
        last_activity=session.last_activity,
        total_messages=session.total_messages,
        total_tokens=session.total_tokens,
        avg_response_time=session.avg_response_time
    )

@app.get("/sessions/{session_id}/history")
async def get_conversation_history(
    session_id: str, 
    limit: int = 50,
    db: SessionLocal = Depends(get_db)
):
    """Get conversation history for a session"""
    conversations = db.query(ConversationLog).filter(
        ConversationLog.session_id == session_id,
        ConversationLog.success == True
    ).order_by(ConversationLog.timestamp.desc()).limit(limit).all()
    
    return {
        "session_id": session_id,
        "conversations": [
            {
                "timestamp": conv.timestamp,
                "user_message": conv.user_message,
                "assistant_response": conv.assistant_response,
                "tokens_used": conv.tokens_used,
                "processing_time": conv.processing_time
            }
            for conv in reversed(conversations)
        ]
    }

@app.get("/admin/stats")
async def get_system_stats(db: SessionLocal = Depends(get_db)):
    """Get system statistics (admin endpoint)"""
    try:
        # Get recent metrics
        recent_metrics = db.query(SystemMetrics).order_by(
            SystemMetrics.timestamp.desc()
        ).limit(24).all()
        
        # Get conversation stats
        total_conversations = db.query(ConversationLog).count()
        successful_conversations = db.query(ConversationLog).filter(
            ConversationLog.success == True
        ).count()
        
        # Get session stats
        total_sessions = db.query(UserSession).count()
        active_sessions = db.query(UserSession).filter(
            UserSession.last_activity >= datetime.utcnow() - timedelta(hours=24)
        ).count()
        
        return {
            "total_conversations": total_conversations,
            "successful_conversations": successful_conversations,
            "success_rate": (successful_conversations / max(total_conversations, 1)) * 100,
            "total_sessions": total_sessions,
            "active_sessions_24h": active_sessions,
            "recent_metrics": [
                {
                    "timestamp": metric.timestamp,
                    "cpu_percent": metric.cpu_percent,
                    "memory_percent": metric.memory_percent,
                    "active_sessions": metric.active_sessions
                }
                for metric in recent_metrics
            ]
        }
    except Exception as e:
        logger.error(f"Stats endpoint error: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve stats")

# Background tasks
async def collect_system_metrics():
    """Background task to collect system metrics"""
    while True:
        try:
            db = SessionLocal()
            
            metrics = SystemMetrics(
                cpu_percent=psutil.cpu_percent(interval=1),
                memory_percent=psutil.virtual_memory().percent,
                disk_percent=psutil.disk_usage('/').percent,
                memory_used_mb=psutil.virtual_memory().used / 1024 / 1024,
                memory_total_mb=psutil.virtual_memory().total / 1024 / 1024,
                disk_used_gb=psutil.disk_usage('/').used / 1024 / 1024 / 1024,
                disk_total_gb=psutil.disk_usage('/').total / 1024 / 1024 / 1024,
                uptime_seconds=int((datetime.utcnow() - app_start_time).total_seconds()),
                health_status="healthy"
            )
            
            db.add(metrics)
            db.commit()
            db.close()
            
        except Exception as e:
            logger.error(f"Failed to collect system metrics: {e}")
        
        await asyncio.sleep(300)  # Collect every 5 minutes

async def cleanup_old_data():
    """Background task to cleanup old data"""
    while True:
        try:
            await asyncio.sleep(86400)  # Run daily
            
            db = SessionLocal()
            cutoff_date = datetime.utcnow() - timedelta(days=30)
            
            # Clean old system metrics (keep 30 days)
            old_metrics = db.query(SystemMetrics).filter(
                SystemMetrics.timestamp < cutoff_date
            ).delete()
            
            # Clean old error logs (keep 30 days)
            old_errors = db.query(ErrorLog).filter(
                ErrorLog.timestamp < cutoff_date
            ).delete()
            
            db.commit()
            db.close()
            
            logger.info(f"Cleaned up {old_metrics} old metrics and {old_errors} old error logs")
            
        except Exception as e:
            logger.error(f"Failed to cleanup old data: {e}")

# Exception handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions with logging"""
    logger.warning(f"HTTP {exc.status_code}: {exc.detail} - {request.url}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.detail, "status_code": exc.status_code}
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions with logging"""
    logger.error(f"Unhandled exception: {exc} - {request.url}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error", 
            "status_code": 500,
            "error_type": "general_error"
        }
    )

if __name__ == "__main__":
    # Development server
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    debug = os.getenv("DEBUG", "False").lower() == "true"
    
    logger.info(f"Starting development server on {host}:{port}")
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level=log_level.lower()
    )
