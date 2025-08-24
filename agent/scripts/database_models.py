"""
Database models and setup for Claude AI Agent
SQLAlchemy models matching the SQLite schema
"""

import os
import logging
from datetime import datetime
from typing import Optional, List
from contextlib import contextmanager

from sqlalchemy import (
    create_engine, Column, Integer, String, Text, Float, Boolean, DateTime,
    ForeignKey, Index, CheckConstraint, UniqueConstraint, JSON
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./data/agent_database.db")

# Ensure data directory exists for SQLite
if DATABASE_URL.startswith("sqlite"):
    db_path = DATABASE_URL.replace("sqlite:///", "").replace("sqlite://", "")
    os.makedirs(os.path.dirname(db_path) if os.path.dirname(db_path) else ".", exist_ok=True)

# Create engine
engine = create_engine(
    DATABASE_URL,
    echo=os.getenv("DEBUG", "False").lower() == "true",
    pool_pre_ping=True,
    # SQLite specific settings
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for all models
Base = declarative_base()

class ConversationLog(Base):
    """Store all chat interactions and conversation data"""
    __tablename__ = "conversation_logs"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String(255), nullable=False, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    user_message = Column(Text, nullable=False)
    assistant_response = Column(Text, nullable=False)
    tokens_used = Column(Integer, default=0)
    processing_time = Column(Float, default=0.0)
    model_used = Column(String(100), default="claude-3-sonnet-20240229")
    success = Column(Boolean, default=True, index=True)
    error_message = Column(Text)
    error_type = Column(String(50))
    user_ip = Column(String(45))  # Support IPv6
    user_agent = Column(Text)
    conversation_context = Column(JSON)  # For additional context
    metadata = Column(JSON)  # For additional metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Indexes
    __table_args__ = (
        Index('idx_conversation_session_timestamp', 'session_id', 'timestamp'),
        Index('idx_conversation_tokens', 'tokens_used'),
        Index('idx_conversation_processing_time', 'processing_time'),
        Index('idx_conversation_model_timestamp', 'model_used', 'timestamp'),
        CheckConstraint('tokens_used >= 0', name='chk_tokens_positive'),
        CheckConstraint('processing_time >= 0', name='chk_processing_time_positive'),
    )
    
    def __repr__(self):
        return f"<ConversationLog(id={self.id}, session_id={self.session_id}, success={self.success})>"

class UserSession(Base):
    """Track user sessions and session-level statistics"""
    __tablename__ = "user_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    session_uuid = Column(String(255), unique=True, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_activity = Column(DateTime, default=datetime.utcnow, index=True)
    session_status = Column(String(20), default="active")  # active, inactive, expired
    total_messages = Column(Integer, default=0)
    total_tokens = Column(Integer, default=0)
    total_processing_time = Column(Float, default=0.0)
    user_ip = Column(String(45))
    user_agent = Column(Text)
    browser_info = Column(JSON)  # Store browser details
    device_info = Column(JSON)   # Store device details
    session_metadata = Column(JSON)
    total_errors = Column(Integer, default=0)
    avg_response_time = Column(Float, default=0.0)
    peak_tokens_per_hour = Column(Integer, default=0)
    conversation_topics = Column(JSON)  # Array of identified topics
    session_rating = Column(Integer)  # 1-5 rating
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship to conversations
    conversations = relationship("ConversationLog", 
                               primaryjoin="UserSession.session_uuid == foreign(ConversationLog.session_id)",
                               viewonly=True)
    
    __table_args__ = (
        Index('idx_session_activity', 'last_activity'),
        Index('idx_session_status_created', 'session_status', 'created_at'),
        Index('idx_session_tokens', 'total_tokens'),
        CheckConstraint('total_messages >= 0', name='chk_total_messages_positive'),
        CheckConstraint('total_tokens >= 0', name='chk_total_tokens_positive'),
        CheckConstraint('total_errors >= 0', name='chk_total_errors_positive'),
        CheckConstraint('session_rating IS NULL OR (session_rating >= 1 AND session_rating <= 5)', 
                       name='chk_session_rating_range'),
    )
    
    def __repr__(self):
        return f"<UserSession(id={self.id}, session_uuid={self.session_uuid}, status={self.session_status})>"

class SystemMetrics(Base):
    """Store comprehensive system performance and health metrics"""
    __tablename__ = "system_metrics"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    metric_date = Column(String(10), default=lambda: datetime.utcnow().strftime('%Y-%m-%d'))
    cpu_percent = Column(Float)
    memory_percent = Column(Float)
    memory_used_mb = Column(Float)
    memory_total_mb = Column(Float)
    disk_percent = Column(Float)
    disk_used_gb = Column(Float)
    disk_total_gb = Column(Float)
    network_bytes_sent = Column(Integer, default=0)
    network_bytes_recv = Column(Integer, default=0)
    active_sessions = Column(Integer, default=0)
    requests_per_minute = Column(Float, default=0.0)
    requests_per_hour = Column(Float, default=0.0)
    total_requests = Column(Integer, default=0)
    total_errors = Column(Integer, default=0)
    avg_response_time = Column(Float, default=0.0)
    error_rate = Column(Float, default=0.0)
    database_connections = Column(Integer, default=0)
    database_size_mb = Column(Float)
    log_file_size_mb = Column(Float)
    uptime_seconds = Column(Integer, default=0)
    load_average_1min = Column(Float)
    load_average_5min = Column(Float)
    load_average_15min = Column(Float)
    system_alerts = Column(JSON)  # Store system alerts/warnings
    health_status = Column(String(20), default="healthy")  # healthy, warning, critical
    created_at = Column(DateTime, default=datetime.utcnow)
    
    __table_args__ =
