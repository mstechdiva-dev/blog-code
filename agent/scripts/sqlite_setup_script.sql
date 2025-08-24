-- SQLite Database Setup Script for Claude AI Agent
-- This script creates the complete database schema for the Claude AI Agent application
-- Compatible with the default SQLite configuration in the installation guide

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Set journal mode for better concurrency
PRAGMA journal_mode = WAL;

-- Set synchronous mode for balance of safety and performance
PRAGMA synchronous = NORMAL;

-- Set cache size (in KB) for better performance
PRAGMA cache_size = 10000;

-- =====================================
-- CONVERSATION LOGS TABLE
-- =====================================
-- Store all chat interactions and conversation data
CREATE TABLE IF NOT EXISTS conversation_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    user_message TEXT NOT NULL,
    assistant_response TEXT NOT NULL,
    tokens_used INTEGER DEFAULT 0 CHECK (tokens_used >= 0),
    processing_time REAL DEFAULT 0.0,
    model_used TEXT DEFAULT 'claude-3-sonnet-20240229',
    success INTEGER DEFAULT 1 CHECK (success IN (0, 1)),
    error_message TEXT,
    error_type TEXT,
    user_ip TEXT,
    user_agent TEXT,
    conversation_context TEXT, -- JSON string for conversation context
    metadata TEXT, -- JSON string for additional metadata
    created_at TEXT DEFAULT (datetime('now', 'utc'))
);

-- =====================================
-- USER SESSIONS TABLE
-- =====================================
-- Track user sessions and session-level statistics
CREATE TABLE IF NOT EXISTS user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_uuid TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    last_activity TEXT DEFAULT (datetime('now', 'utc')),
    session_status TEXT DEFAULT 'active' CHECK (session_status IN ('active', 'inactive', 'expired')),
    total_messages INTEGER DEFAULT 0 CHECK (total_messages >= 0),
    total_tokens INTEGER DEFAULT 0 CHECK (total_tokens >= 0),
    total_processing_time REAL DEFAULT 0.0,
    user_ip TEXT,
    user_agent TEXT,
    browser_info TEXT, -- JSON string for browser details
    device_info TEXT, -- JSON string for device details
    session_metadata TEXT, -- JSON string for session metadata
    total_errors INTEGER DEFAULT 0 CHECK (total_errors >= 0),
    avg_response_time REAL DEFAULT 0.0,
    peak_tokens_per_hour INTEGER DEFAULT 0,
    conversation_topics TEXT, -- JSON array of identified topics
    session_rating INTEGER CHECK (session_rating >= 1 AND session_rating <= 5),
    updated_at TEXT DEFAULT (datetime('now', 'utc'))
);

-- =====================================
-- SYSTEM METRICS TABLE
-- =====================================
-- Store comprehensive system performance and health metrics
CREATE TABLE IF NOT EXISTS system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    metric_date TEXT DEFAULT (date('now')),
    cpu_percent REAL CHECK (cpu_percent >= 0 AND cpu_percent <= 100),
    memory_percent REAL CHECK (memory_percent >= 0 AND memory_percent <= 100),
    memory_used_mb REAL,
    memory_total_mb REAL,
    disk_percent REAL CHECK (disk_percent >= 0 AND disk_percent <= 100),
    disk_used_gb REAL,
    disk_total_gb REAL,
    network_bytes_sent INTEGER DEFAULT 0,
    network_bytes_recv INTEGER DEFAULT 0,
    active_sessions INTEGER DEFAULT 0 CHECK (active_sessions >= 0),
    requests_per_minute REAL DEFAULT 0.0,
    requests_per_hour REAL DEFAULT 0.0,
    total_requests INTEGER DEFAULT 0,
    total_errors INTEGER DEFAULT 0,
    avg_response_time REAL DEFAULT 0.0,
    error_rate REAL DEFAULT 0.0,
    database_connections INTEGER DEFAULT 0,
    database_size_mb REAL,
    log_file_size_mb REAL,
    uptime_seconds INTEGER DEFAULT 0,
    load_average_1min REAL,
    load_average_5min REAL,
    load_average_15min REAL,
    system_alerts TEXT, -- JSON string for system alerts/warnings
    health_status TEXT DEFAULT 'healthy' CHECK (health_status IN ('healthy', 'warning', 'critical')),
    created_at TEXT DEFAULT (datetime('now', 'utc'))
);

-- =====================================
-- API USAGE TABLE
-- =====================================
-- Track detailed API usage, costs, and billing information
CREATE TABLE IF NOT EXISTS api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    usage_date TEXT DEFAULT (date('now')),
    hour_of_day INTEGER CHECK (hour_of_day >= 0 AND hour_of_day <= 23),
    total_tokens INTEGER DEFAULT 0 CHECK (total_tokens >= 0),
    input_tokens INTEGER DEFAULT 0 CHECK (input_tokens >= 0),
    output_tokens INTEGER DEFAULT 0 CHECK (output_tokens >= 0),
    total_requests INTEGER DEFAULT 0 CHECK (total_requests >= 0),
    successful_requests INTEGER DEFAULT 0 CHECK (successful_requests >= 0),
    failed_requests INTEGER DEFAULT 0 CHECK (failed_requests >= 0),
    rate_limited_requests INTEGER DEFAULT 0,
    estimated_cost_usd REAL DEFAULT 0.0,
    actual_cost_usd REAL,
    model_usage TEXT, -- JSON string for per-model usage breakdown
    cost_breakdown TEXT, -- JSON string for detailed cost analysis
    billing_tier TEXT, -- API billing tier information
    cost_alerts TEXT, -- JSON string for cost threshold alerts
    peak_requests_per_minute INTEGER DEFAULT 0,
    unique_sessions INTEGER DEFAULT 0,
    avg_tokens_per_request REAL DEFAULT 0.0,
    cost_per_request REAL DEFAULT 0.0,
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    updated_at TEXT DEFAULT (datetime('now', 'utc')),
    
    -- Ensure we don't have duplicate date/hour combinations
    UNIQUE(usage_date, hour_of_day)
);

-- =====================================
-- ERROR LOGS TABLE
-- =====================================
-- Dedicated table for tracking and analyzing errors
CREATE TABLE IF NOT EXISTS error_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    error_type TEXT NOT NULL,
    error_code TEXT,
    error_message TEXT NOT NULL,
    error_context TEXT, -- JSON string for error context
    session_id TEXT,
    request_id TEXT,
    user_ip TEXT,
    user_agent TEXT,
    stack_trace TEXT,
    resolution_status TEXT DEFAULT 'open' CHECK (resolution_status IN ('open', 'investigating', 'resolved', 'ignored')),
    resolution_notes TEXT,
    severity_level INTEGER DEFAULT 3 CHECK (severity_level >= 1 AND severity_level <= 5), -- 1=critical, 5=minor
    affected_users INTEGER DEFAULT 1,
    resolved_at TEXT,
    created_at TEXT DEFAULT (datetime('now', 'utc'))
);

-- =====================================
-- PERFORMANCE ANALYTICS TABLE
-- =====================================
-- Store aggregated performance data for analytics and reporting
CREATE TABLE IF NOT EXISTS performance_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_date TEXT DEFAULT (date('now')),
    analysis_period TEXT DEFAULT 'daily' CHECK (analysis_period IN ('hourly', 'daily', 'weekly', 'monthly')),
    total_requests INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    avg_response_time REAL DEFAULT 0.0,
    median_response_time REAL DEFAULT 0.0,
    p95_response_time REAL DEFAULT 0.0,
    total_tokens INTEGER DEFAULT 0,
    avg_tokens_per_request REAL DEFAULT 0.0,
    total_cost_usd REAL DEFAULT 0.0,
    unique_sessions INTEGER DEFAULT 0,
    avg_session_duration REAL DEFAULT 0.0,
    peak_concurrent_users INTEGER DEFAULT 0,
    error_rate REAL DEFAULT 0.0,
    uptime_percentage REAL DEFAULT 100.0,
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    updated_at TEXT DEFAULT (datetime('now', 'utc')),
    
    -- Ensure unique analysis periods per date
    UNIQUE(analysis_date, analysis_period)
);

-- =====================================
-- SYSTEM ALERTS TABLE
-- =====================================
-- Store system alerts and notifications
CREATE TABLE IF NOT EXISTS system_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    alert_type TEXT NOT NULL,
    severity TEXT CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    title TEXT NOT NULL,
    description TEXT,
    source_component TEXT,
    alert_data TEXT, -- JSON string for additional alert data
    is_resolved INTEGER DEFAULT 0 CHECK (is_resolved IN (0, 1)),
    resolved_at TEXT,
    resolved_by TEXT,
    acknowledgment_required INTEGER DEFAULT 0 CHECK (acknowledgment_required IN (0, 1)),
    acknowledged_at TEXT,
    acknowledged_by TEXT,
    escalation_level INTEGER DEFAULT 1 CHECK (escalation_level >= 1 AND escalation_level <= 5),
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    updated_at TEXT DEFAULT (datetime('now', 'utc'))
);

-- =====================================
-- INDEXES FOR PERFORMANCE
-- =====================================

-- Conversation logs indexes
CREATE INDEX IF NOT EXISTS idx_conversation_session_id ON conversation_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_conversation_timestamp ON conversation_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_success ON conversation_logs(success, timestamp);
CREATE INDEX IF NOT EXISTS idx_conversation_tokens ON conversation_logs(tokens_used) WHERE tokens_used > 0;
CREATE INDEX IF NOT EXISTS idx_conversation_processing_time ON conversation_logs(processing_time) WHERE processing_time > 0;
CREATE INDEX IF NOT EXISTS idx_conversation_model ON conversation_logs(model_used, timestamp);
CREATE INDEX IF NOT EXISTS idx_conversation_error_type ON conversation_logs(error_type) WHERE error_type IS NOT NULL;

-- User sessions indexes
CREATE INDEX IF NOT EXISTS idx_session_activity ON user_sessions(last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_session_status ON user_sessions(session_status, created_at);
CREATE INDEX IF NOT EXISTS idx_session_uuid ON user_sessions(session_uuid);
CREATE INDEX IF NOT EXISTS idx_session_ip ON user_sessions(user_ip) WHERE user_ip IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_session_tokens ON user_sessions(total_tokens) WHERE total_tokens > 0;

-- System metrics indexes
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON system_metrics(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_date ON system_metrics(metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_cpu ON system_metrics(cpu_percent) WHERE cpu_percent > 80;
CREATE INDEX IF NOT EXISTS idx_metrics_memory ON system_metrics(memory_percent) WHERE memory_percent > 80;
CREATE INDEX IF NOT EXISTS idx_metrics_health ON system_metrics(health_status, timestamp);

-- API usage indexes
CREATE INDEX IF NOT EXISTS idx_api_usage_date ON api_usage(usage_date DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_cost ON api_usage(estimated_cost_usd) WHERE estimated_cost_usd > 0;
CREATE INDEX IF NOT EXISTS idx_api_usage_tokens ON api_usage(total_tokens) WHERE total_tokens > 0;
CREATE INDEX IF NOT EXISTS idx_api_usage_requests ON api_usage(total_requests) WHERE total_requests > 0;

-- Error logs indexes
CREATE INDEX IF NOT EXISTS idx_error_timestamp ON error_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_error_type ON error_logs(error_type, timestamp);
CREATE INDEX IF NOT EXISTS idx_error_severity ON error_logs(severity_level, timestamp);
CREATE INDEX IF NOT EXISTS idx_error_resolution ON error_logs(resolution_status, timestamp);
CREATE INDEX IF NOT EXISTS idx_error_session ON error_logs(session_id) WHERE session_id IS NOT NULL;

-- Performance analytics indexes
CREATE INDEX IF NOT EXISTS idx_analytics_date ON performance_analytics(analysis_date DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_period ON performance_analytics(analysis_period, analysis_date);

-- System alerts indexes
CREATE INDEX IF NOT EXISTS idx_alerts_timestamp ON system_alerts(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON system_alerts(severity, timestamp);
CREATE INDEX IF NOT EXISTS idx_alerts_resolved ON system_alerts(is_resolved, timestamp);
CREATE INDEX IF NOT EXISTS idx_alerts_type ON system_alerts(alert_type, timestamp);

-- =====================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================

-- Trigger to update user_sessions.updated_at on any change
CREATE TRIGGER IF NOT EXISTS update_session_timestamp 
    AFTER UPDATE ON user_sessions
    FOR EACH ROW
BEGIN
    UPDATE user_sessions 
    SET updated_at = datetime('now', 'utc')
    WHERE id = NEW.id;
END;

-- Trigger to update user_sessions.last_activity when new conversation is added
CREATE TRIGGER IF NOT EXISTS update_session_activity 
    AFTER INSERT ON conversation_logs
    FOR EACH ROW
BEGIN
    UPDATE user_sessions 
    SET last_activity = datetime('now', 'utc'),
        total_messages = total_messages + 1,
        total_tokens = total_tokens + COALESCE(NEW.tokens_used, 0),
        total_processing_time = total_processing_time + COALESCE(NEW.processing_time, 0),
        total_errors = total_errors + CASE WHEN NEW.success = 0 THEN 1 ELSE 0 END,
        updated_at = datetime('now', 'utc')
    WHERE session_uuid = NEW.session_id;
    
    -- If session doesn't exist, create it
    INSERT OR IGNORE INTO user_sessions (session_uuid, user_ip, user_agent, created_at)
    VALUES (NEW.session_id, NEW.user_ip, NEW.user_agent, datetime('now', 'utc'));
END;

-- Trigger to update system_alerts.updated_at on any change
CREATE TRIGGER IF NOT EXISTS update_alert_timestamp 
    AFTER UPDATE ON system_alerts
    FOR EACH ROW
BEGIN
    UPDATE system_alerts 
    SET updated_at = datetime('now', 'utc')
    WHERE id = NEW.id;
END;

-- =====================================
-- VIEWS FOR ANALYTICS
-- =====================================

-- View for daily usage statistics
CREATE VIEW IF NOT EXISTS daily_usage_stats AS
SELECT 
    date(timestamp) as usage_date,
    COUNT(*) as total_conversations,
    COUNT(DISTINCT session_id) as unique_sessions,
    SUM(tokens_used) as total_tokens,
    AVG(tokens_used) as avg_tokens_per_conversation,
    AVG(processing_time) as avg_response_time,
    COUNT(*) FILTER (WHERE success = 1) as successful_conversations,
    COUNT(*) FILTER (WHERE success = 0) as failed_conversations,
    ROUND(COUNT(*) FILTER (WHERE success = 0) * 100.0 / COUNT(*), 2) as error_rate_percent
FROM conversation_logs
GROUP BY date(timestamp)
ORDER BY usage_date DESC;

-- View for session analytics
CREATE VIEW IF NOT EXISTS session_analytics AS
SELECT 
    s.session_uuid,
    s.created_at,
    s.last_activity,
    s.session_status,
    s.total_messages,
    s.total_tokens,
    s.total_processing_time,
    s.avg_response_time,
    s.total_errors,
    ROUND(s.total_errors * 100.0 / CASE WHEN s.total_messages > 0 THEN s.total_messages ELSE 1 END, 2) as session_error_rate,
    ROUND((julianday(s.last_activity) - julianday(s.created_at)) * 24 * 60, 2) as session_duration_minutes,
    s.user_ip,
    COALESCE(s.session_rating, 0) as session_rating
FROM user_sessions s
WHERE s.total_messages > 0
ORDER BY s.last_activity DESC;

-- View for system health dashboard
CREATE VIEW IF NOT EXISTS system_health_dashboard AS
SELECT 
    datetime(timestamp, 'start of hour') as metric_hour,
    AVG(cpu_percent) as avg_cpu_percent,
    MAX(cpu_percent) as max_cpu_percent,
    AVG(memory_percent) as avg_memory_percent,
    MAX(memory_percent) as max_memory_percent,
    AVG(disk_percent) as avg_disk_percent,
    AVG(active_sessions) as avg_active_sessions,
    MAX(active_sessions) as max_active_sessions,
    AVG(requests_per_minute) as avg_requests_per_minute,
    MAX(requests_per_minute) as max_requests_per_minute,
    AVG(avg_response_time) as avg_response_time,
    AVG(error_rate) as avg_error_rate
FROM system_metrics
WHERE timestamp >= datetime('now', '-24 hours')
GROUP BY datetime(timestamp, 'start of hour')
ORDER BY metric_hour DESC;

-- =====================================
-- INITIAL DATA AND CONFIGURATION
-- =====================================

-- Insert initial performance analytics record
INSERT OR IGNORE INTO performance_analytics (
    analysis_date, 
    analysis_period, 
    total_requests, 
    successful_requests, 
    failed_requests
) VALUES (
    date('now'), 
    'daily', 
    0, 
    0, 
    0
);

-- Insert system initialization alert
INSERT OR IGNORE INTO system_alerts (
    alert_type,
    severity,
    title,
    description,
    is_resolved
) VALUES (
    'system_init',
    'info',
    'Database Initialized',
    'Claude AI Agent SQLite database has been successfully initialized with all tables, indexes, and triggers.',
    1
);

-- =====================================
-- UTILITY FUNCTIONS (Using SQL only)
-- =====================================

-- Analyze database performance
-- Run this query to check database statistics:
-- SELECT 
--     'Tables Created' as metric,
--     COUNT(*) as value
-- FROM sqlite_master 
-- WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
-- UNION ALL
-- SELECT 
--     'Indexes Created' as metric,
--     COUNT(*) as value
-- FROM sqlite_master 
-- WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
-- UNION ALL
-- SELECT 
--     'Views Created' as metric,
--     COUNT(*) as value
-- FROM sqlite_master 
-- WHERE type = 'view'
-- UNION ALL
-- SELECT 
--     'Triggers Created' as metric,
--     COUNT(*) as value
-- FROM sqlite_master 
-- WHERE type = 'trigger';

-- =====================================
-- VACUUM AND OPTIMIZE
-- =====================================

-- Analyze the database for query optimization
ANALYZE;

-- Clean up any fragmentation (optional, can be run periodically)
-- VACUUM;

-- =====================================
-- COMPLETION MESSAGE
-- =====================================

SELECT '=====================================';
SELECT 'Claude AI Agent SQLite Database Setup Complete!';
SELECT '=====================================';
SELECT '';
SELECT 'Tables Created:';
SELECT '- conversation_logs (chat interactions)';
SELECT '- user_sessions (session tracking)';
SELECT '- system_metrics (performance data)';
SELECT '- api_usage (cost tracking)';
SELECT '- error_logs (error tracking)';
SELECT '- performance_analytics (analytics)';
SELECT '- system_alerts (system notifications)';
SELECT '';
SELECT 'Features Enabled:';
SELECT '- Comprehensive indexing for performance';
SELECT '- Automatic timestamp triggers';
SELECT '- Session statistics automation';
SELECT '- Analytics views';
SELECT '- WAL mode for better concurrency';
SELECT '';
SELECT 'Next Steps:';
SELECT '1. Verify your .env file DATABASE_URL points to this SQLite file';
SELECT '2. Test the database connection from your application';
SELECT '3. Run your application and verify data is being stored';
SELECT '4. Set up periodic cleanup using the views and analytics';
SELECT '';
SELECT 'Database file should be located at:';
SELECT '/home/ubuntu/claude-ai-agent/data/agent_database.db';
SELECT '';
SELECT '=====================================';
