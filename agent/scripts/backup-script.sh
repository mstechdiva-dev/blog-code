#!/bin/bash

# Claude AI Agent Backup Script
# Creates comprehensive backups with extensive error handling and validation

set -e  # Exit on any error
set -u  # Exit on undefined variables

echo "========================================"
echo "Claude AI Agent - Backup System"
echo "========================================"
echo "Starting backup at $(date)"
echo

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_DIR="$PROJECT_ROOT/backups"
readonly DATE=$(date +%Y%m%d_%H%M%S)
readonly LOG_FILE="$PROJECT_ROOT/logs/backup.log"
readonly RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Backup file paths
readonly DB_BACKUP="$BACKUP_DIR/database_$DATE.db"
readonly CONFIG_BACKUP="$BACKUP_DIR/config_$DATE.tar.gz"
readonly CODE_BACKUP="$BACKUP_DIR/code_$DATE.tar.gz"
readonly LOGS_BACKUP="$BACKUP_DIR/logs_$DATE.tar.gz"
readonly SYSINFO_BACKUP="$BACKUP_DIR/sysinfo_$DATE.txt"
readonly MANIFEST_FILE="$BACKUP_DIR/manifest_$DATE.txt"

# Ensure required directories exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to print colored output and log
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$(date): INFO - $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date): WARNING - $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date): ERROR - $1" >> "$LOG_FILE"
    exit 1
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
    echo "$(date): DEBUG - $1" >> "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get file size in human readable format
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        if command_exists du; then
            du -h "$file" | cut -f1
        else
            ls -lh "$file" | awk '{print $5}'
        fi
    else
        echo "0B"
    fi
}

# Function to validate backup integrity
validate_backup_file() {
    local file="$1"
    local type="$2"
    
    if [ ! -f "$file" ]; then
        print_warning "Backup file not created: $file"
        return 1
    fi
    
    case "$type" in
        "database")
            if command_exists sqlite3; then
                if sqlite3 "$file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
                    print_status "Database backup validated: $(basename "$file")"
                    return 0
                else
                    print_error "Database backup validation failed: $file"
                    return 1
                fi
            else
                print_warning "Cannot validate database backup (sqlite3 not available)"
                return 0
            fi
            ;;
        "archive")
            if command_exists tar; then
                if tar -tzf "$file" >/dev/null 2>&1; then
                    print_status "Archive backup validated: $(basename "$file")"
                    return 0
                else
                    print_error "Archive backup validation failed: $file"
                    return 1
                fi
            else
                print_warning "Cannot validate archive backup (tar not available)"
                return 0
            fi
            ;;
        "text")
            if [ -s "$file" ]; then
                print_status "Text backup validated: $(basename "$file")"
                return 0
            else
                print_warning "Text backup is empty: $file"
                return 1
            fi
            ;;
        *)
            print_warning "Unknown backup type for validation: $type"
            return 0
            ;;
    esac
}

# Function to check available disk space
check_disk_space() {
    print_status "Checking available disk space..."
    
    if ! command_exists df; then
        print_warning "df command not available, skipping disk space check"
        return 0
    fi
    
    local available_kb
    available_kb=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    local required_kb=1048576  # 1GB in KB
    
    if [ -z "$available_kb" ] || ! [[ "$available_kb" =~ ^[0-9]+$ ]]; then
        print_warning "Could not determine available disk space"
        return 0
    fi
    
    if [ "$available_kb" -lt "$required_kb" ]; then
        local available_mb=$((available_kb / 1024))
        print_warning "Low disk space. Available: ${available_mb}MB. Recommended: 1GB+"
        
        read -p "Continue with backup anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Backup cancelled due to insufficient disk space"
        fi
    else
        local available_gb=$((available_kb / 1024 / 1024))
        print_status "Sufficient disk space available: ${available_gb}GB"
    fi
}

# Function to backup database
backup_database() {
    print_status "Backing up database..."
    
    local db_path="$PROJECT_ROOT/data/agent_database.db"
    
    if [ ! -f "$db_path" ]; then
        print_warning "Database file not found: $db_path"
        return 1
    fi
    
    if [ ! -r "$db_path" ]; then
        print_error "Database file not readable: $db_path"
        return 1
    fi
    
    # Check database integrity before backup
    if command_exists sqlite3; then
        print_status "Checking database integrity..."
        if ! sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            print_error "Source database integrity check failed. Cannot create reliable backup."
            return 1
        fi
    else
        print_warning "Cannot verify database integrity (sqlite3 not available)"
    fi
    
    # Create database backup
    print_status "Creating database backup..."
    if ! cp "$db_path" "$DB_BACKUP"; then
        print_error "Failed to copy database file"
        return 1
    fi
    
    # Validate backup
    if validate_backup_file "$DB_BACKUP" "database"; then
        local db_size
        db_size=$(get_file_size "$DB_BACKUP")
        print_status "✅ Database backup created: database_$DATE.db ($db_size)"
        return 0
    else
        rm -f "$DB_BACKUP"
        return 1
    fi
}

# Function to backup configuration
backup_configuration() {
    print_status "Backing up configuration..."
    
    # Check if essential config files exist
    local config_files=("$PROJECT_ROOT/.env")
    local found_configs=()
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            found_configs+=("$(basename "$config_file")")
        fi
    done
    
    if [ ${#found_configs[@]} -eq 0 ]; then
        print_warning "No configuration files found to backup"
        return 1
    fi
    
    # Create configuration backup
    print_status "Creating configuration backup..."
    if ! tar -czf "$CONFIG_BACKUP" \
        --exclude="*.pyc" \
        --exclude="__pycache__" \
        --exclude="venv" \
        --exclude="node_modules" \
        -C "$PROJECT_ROOT" \
        .env \
        2>/dev/null; then
        print_warning "Some configuration files may be missing, but backup created"
    fi
    
    # Validate backup
    if validate_backup_file "$CONFIG_BACKUP" "archive"; then
        local config_size
        config_size=$(get_file_size "$CONFIG_BACKUP")
        print_status "✅ Configuration backup created: config_$DATE.tar.gz ($config_size)"
        return 0
    else
        rm -f "$CONFIG_BACKUP"
        return 1
    fi
}

# Function to backup application code
backup_application_code() {
    print_status "Backing up application code..."
    
    if ! command_exists tar; then
        print_error "tar command not available for creating code backup"
        return 1
    fi
    
    # Create application code backup
    print_status "Creating application code backup..."
    if ! tar -czf "$CODE_BACKUP" \
        --exclude="*.log" \
        --exclude="*.db" \
        --exclude="*.sqlite*" \
        --exclude="venv" \
        --exclude="node_modules" \
        --exclude="build" \
        --exclude="dist" \
        --exclude=".git" \
        --exclude="backups" \
        --exclude="data" \
        --exclude="logs" \
        --exclude="__pycache__" \
        --exclude="*.pyc" \
        --exclude="*.tmp" \
        --exclude="tmp" \
        --exclude="temp" \
        -C "$(dirname "$PROJECT_ROOT")" \
        "$(basename "$PROJECT_ROOT")" \
        2>/dev/null; then
        print_error "Failed to create application code backup"
        return 1
    fi
    
    # Validate backup
    if validate_backup_file "$CODE_BACKUP" "archive"; then
        local code_size
        code_size=$(get_file_size "$CODE_BACKUP")
        print_status "✅ Application code backup created: code_$DATE.tar.gz ($code_size)"
        return 0
    else
        rm -f "$CODE_BACKUP"
        return 1
    fi
}

# Function to backup logs
backup_logs() {
    print_status "Backing up logs..."
    
    local logs_dir="$PROJECT_ROOT/logs"
    
    if [ ! -d "$logs_dir" ]; then
        print_warning "Logs directory not found: $logs_dir"
        return 1
    fi
    
    if [ -z "$(ls -A "$logs_dir" 2>/dev/null)" ]; then
        print_warning "No log files found to backup"
        return 1
    fi
    
    # Create logs backup
    print_status "Creating logs backup..."
    if ! tar -czf "$LOGS_BACKUP" \
        -C "$PROJECT_ROOT" \
        logs/ \
        2>/dev/null; then
        print_warning "Some log files may be inaccessible, but backup created"
    fi
    
    # Validate backup
    if validate_backup_file "$LOGS_BACKUP" "archive"; then
        local logs_size
        logs_size=$(get_file_size "$LOGS_BACKUP")
        print_status "✅ Logs backup created: logs_$DATE.tar.gz ($logs_size)"
        return 0
    else
        rm -f "$LOGS_BACKUP"
        return 1
    fi
}

# Function to create system information backup
backup_system_info() {
    print_status "Creating system information backup..."
    
    local sysinfo_content=""
    
    # Build system information safely
    sysinfo_content+="=== SYSTEM INFORMATION BACKUP ===\n"
    sysinfo_content+="Backup Date: $(date)\n"
    sysinfo_content+="Hostname: $(hostname 2>/dev/null || echo 'Unknown')\n"
    
    if command_exists uptime; then
        sysinfo_content+="Uptime: $(uptime 2>/dev/null || echo 'Unknown')\n"
    fi
    sysinfo_content+="\n"
    
    sysinfo_content+="=== SYSTEM RESOURCES ===\n"
    if command_exists lscpu; then
        sysinfo_content+="CPU Info:\n$(lscpu 2>/dev/null | head -20 || echo 'Not available')\n\n"
    fi
    
    if command_exists free; then
        sysinfo_content+="Memory Info:\n$(free -h 2>/dev/null || echo 'Not available')\n\n"
    fi
    
    if command_exists df; then
        sysinfo_content+="Disk Info:\n$(df -h 2>/dev/null || echo 'Not available')\n\n"
    fi
    
    sysinfo_content+="=== NETWORK CONFIGURATION ===\n"
    if command_exists ip; then
        sysinfo_content+="$(ip addr show 2>/dev/null | grep -E '(inet|link)' | head -20 || echo 'Not available')\n\n"
    fi
    
    sysinfo_content+="=== PROCESS STATUS ===\n"
    if command_exists pm2; then
        sysinfo_content+="$(pm2 status 2>/dev/null || echo 'PM2 not available')\n\n"
    fi
    
    sysinfo_content+="=== SERVICE STATUS ===\n"
    if command_exists systemctl; then
        sysinfo_content+="$(systemctl status nginx --no-pager -l 2>/dev/null || echo 'Nginx status unavailable')\n\n"
    fi
    
    sysinfo_content+="=== PACKAGE VERSIONS ===\n"
    sysinfo_content+="Python: $(python3 --version 2>/dev/null || echo 'Not available')\n"
    sysinfo_content+="Node.js: $(node --version 2>/dev/null || echo 'Not available')\n"
    sysinfo_content+="npm: $(npm --version 2>/dev/null || echo 'Not available')\n"
    sysinfo_content+="PM2: $(pm2 --version 2>/dev/null || echo 'Not available')\n"
    sysinfo_content+="Nginx: $(nginx -v 2>&1 || echo 'Not available')\n\n"
    
    # Database statistics
    sysinfo_content+="=== DATABASE STATISTICS ===\n"
    local db_path="$PROJECT_ROOT/data/agent_database.db"
    if [ -f "$db_path" ]; then
        sysinfo_content+="Database size: $(get_file_size "$db_path")\n"
        if command_exists sqlite3; then
            sysinfo_content+="$(sqlite3 "$db_path" "
SELECT 'Total conversations: ' || COUNT(*) FROM conversation_logs;
SELECT 'Total sessions: ' || COUNT(*) FROM user_sessions;
SELECT 'Total system metrics: ' || COUNT(*) FROM system_metrics;
SELECT 'Database created: ' || datetime('now');
" 2>/dev/null || echo 'Database query failed')\n"
        fi
    else
        sysinfo_content+="Database not found\n"
    fi
    
    # Write system information to file
    if ! echo -e "$sysinfo_content" > "$SYSINFO_BACKUP"; then
        print_error "Failed to create system information backup"
        return 1
    fi
    
    # Validate backup
    if validate_backup_file "$SYSINFO_BACKUP" "text"; then
        local sysinfo_size
        sysinfo_size=$(get_file_size "$SYSINFO_BACKUP")
        print_status "✅ System information backup created: sysinfo_$DATE.txt ($sysinfo_size)"
        return 0
    else
        rm -f "$SYSINFO_BACKUP"
        return 1
    fi
}

# Function to create backup manifest
create_backup_manifest() {
    print_status "Creating backup manifest..."
    
    local manifest_content=""
    local total_files=0
    local successful_files=0
    
    manifest_content+="=== BACKUP MANIFEST ===\n"
    manifest_content+="Backup Set: backup_$DATE\n"
    manifest_content+="Created: $(date)\n"
    manifest_content+="Host: $(hostname 2>/dev/null || echo 'Unknown')\n"
    manifest_content+="Backup Directory: $BACKUP_DIR\n"
    manifest_content+="Retention Policy: $RETENTION_DAYS days\n\n"
    
    manifest_content+="=== FILES IN BACKUP SET ===\n"
    
    # Check each backup file
    local backup_files=(
        "database_$DATE.db"
        "config_$DATE.tar.gz"
        "code_$DATE.tar.gz"
        "logs_$DATE.tar.gz"
        "sysinfo_$DATE.txt"
    )
    
    for file in "${backup_files[@]}"; do
        total_files=$((total_files + 1))
        if [ -f "$BACKUP_DIR/$file" ]; then
            local file_size
            file_size=$(get_file_size "$BACKUP_DIR/$file")
            manifest_content+="✅ $file ($file_size)\n"
            successful_files=$((successful_files + 1))
        else
            manifest_content+="❌ $file (missing)\n"
        fi
    done
    
    manifest_content+="\n=== BACKUP VERIFICATION ===\n"
    
    # Verify database backup
    if [ -f "$DB_BACKUP" ]; then
        if command_exists sqlite3 && sqlite3 "$DB_BACKUP" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            manifest_content+="✅ Database backup integrity verified\n"
        else
            manifest_content+="❌ Database backup integrity check failed\n"
        fi
    fi
    
    # Verify archive files
    local archive_files=("config_$DATE.tar.gz" "code_$DATE.tar.gz" "logs_$DATE.tar.gz")
    for tarfile in "${archive_files[@]}"; do
        if [ -f "$BACKUP_DIR/$tarfile" ]; then
            if command_exists tar && tar -tzf "$BACKUP_DIR/$tarfile" >/dev/null 2>&1; then
                manifest_content+="✅ $tarfile archive integrity verified\n"
            else
                manifest_content+="❌ $tarfile archive integrity check failed\n"
            fi
        fi
    done
    
    manifest_content+="\n=== BACKUP STATISTICS ===\n"
    manifest_content+="Files Created: $successful_files/$total_files\n"
    manifest_content+="Success Rate: $(( successful_files * 100 / total_files ))%\n"
    
    # Calculate total backup size
    if command_exists du; then
        local total_size
        total_size=$(du -sh "$BACKUP_DIR"/*_$DATE.* 2>/dev/null | awk '{sum+=$1} END {print NR " files"}' || echo "Unknown")
        local total_bytes
        total_bytes=$(du -sb "$BACKUP_DIR"/*_$DATE.* 2>/dev/null | awk '{sum+=$1} END {printf "%.2f MB", sum/1024/1024}' || echo "Unknown")
        manifest_content+="Total Backup Size: $total_bytes\n"
    fi
    
    manifest_content+="\n=== RESTORATION INSTRUCTIONS ===\n"
    manifest_content+="To restore from this backup:\n"
    manifest_content+="1. Run: ./scripts/restore.sh backup_$DATE\n"
    manifest_content+="2. Or manually extract files as needed\n"
    manifest_content+="3. Verify restored data integrity\n"
    manifest_content+="4. Restart services if necessary\n\n"
    
    manifest_content+="=== FILE DETAILS ===\n"
    if command_exists ls; then
        manifest_content+="$(ls -la "$BACKUP_DIR"/*_$DATE.* 2>/dev/null || echo 'No backup files found')\n"
    fi
    
    # Write manifest to file
    if ! echo -e "$manifest_content" > "$MANIFEST_FILE"; then
        print_error "Failed to create backup manifest"
        return 1
    fi
    
    if validate_backup_file "$MANIFEST_FILE" "text"; then
        local manifest_size
        manifest_size=$(get_file_size "$MANIFEST_FILE")
        print_status "✅ Backup manifest created: manifest_$DATE.txt ($manifest_size)"
        return 0
    else
        rm -f "$MANIFEST_FILE"
        return 1
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    print_status "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
    
    if ! command_exists find; then
        print_warning "find command not available, skipping cleanup"
        return 0
    fi
    
    local deleted_count=0
    local backup_patterns=(
        "database_*.db"
        "config_*.tar.gz"
        "code_*.tar.gz"
        "logs_*.tar.gz"
        "sysinfo_*.txt"
        "manifest_*.txt"
    )
    
    for pattern in "${backup_patterns[@]}"; do
        # Find and delete old files
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                print_debug "Removing old backup: $(basename "$file")"
                if rm "$file"; then
                    deleted_count=$((deleted_count + 1))
                else
                    print_warning "Failed to remove old backup: $file"
                fi
            fi
        done < <(find "$BACKUP_DIR" -name "$pattern" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    done
    
    if [ $deleted_count -gt 0 ]; then
        print_status "🗑️ Cleaned up $deleted_count old backup files"
    else
        print_status "No old backup files to clean up"
    fi
}

# Function to display backup summary
show_backup_summary() {
    echo
    echo "========================================"
    echo "✅ Backup completed successfully!"
    echo "========================================"
    echo
    
    print_status "Backup Summary:"
    echo "  📅 Backup Date: $(date)"
    echo "  📁 Backup Set: backup_$DATE"
    echo "  📂 Location: $BACKUP_DIR"
    echo
    
    echo "  📦 Files Created:"
    
    # List created files with sizes
    local backup_files=(
        "$DB_BACKUP:database_$DATE.db"
        "$CONFIG_BACKUP:config_$DATE.tar.gz"
        "$CODE_BACKUP:code_$DATE.tar.gz"
        "$LOGS_BACKUP:logs_$DATE.tar.gz"
        "$SYSINFO_BACKUP:sysinfo_$DATE.txt"
        "$MANIFEST_FILE:manifest_$DATE.txt"
    )
    
    for file_info in "${backup_files[@]}"; do
        local file_path="${file_info%:*}"
        local file_name="${file_info#*:}"
        
        if [ -f "$file_path" ]; then
            local file_size
            file_size=$(get_file_size "$file_path")
            echo "    • $file_name ($file_size)"
        fi
    done
    
    echo
    echo "  🔍 To restore from this backup:"
    echo "    ./scripts/restore.sh backup_$DATE"
    echo
    echo "  📋 To view backup details:"
    echo "    cat $MANIFEST_FILE"
    echo
    echo "  🗂️ All backups in: $BACKUP_DIR"
    echo
    
    # Final disk space check
    if command_exists df; then
        local final_space
        final_space=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $4}' 2>/dev/null || echo "Unknown")
        echo "  💾 Remaining disk space: ${final_space}B"
    fi
    
    echo
    echo "Backup process completed at $(date)"
}

# Function to handle backup errors
handle_backup_error() {
    local error_msg="$1"
    local exit_code="${2:-1}"
    
    print_error "$error_msg"
    
    # Cleanup partial backup files
    print_status "Cleaning up partial backup files..."
    local partial_files=(
        "$DB_BACKUP"
        "$CONFIG_BACKUP"
        "$CODE_BACKUP"
        "$LOGS_BACKUP"
        "$SYSINFO_BACKUP"
        "$MANIFEST_FILE"
    )
    
    for file in "${partial_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file" && print_debug "Removed partial file: $(basename "$file")"
        fi
    done
    
    echo "$(date): Backup failed - $error_msg" >> "$LOG_FILE"
    exit "$exit_code"
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating backup prerequisites..."
    
    # Check if project directory exists
    if [ ! -d "$PROJECT_ROOT" ]; then
        handle_backup_error "Project root directory not found: $PROJECT_ROOT"
    fi
    
    # Check write permissions for backup directory
    if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        handle_backup_error "Cannot create backup directory: $BACKUP_DIR"
    fi
    
    if [ ! -w "$BACKUP_DIR" ]; then
        handle_backup_error "No write permission for backup directory: $BACKUP_DIR"
    fi
    
    # Check essential commands
    local required_commands=("cp" "tar" "date")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        handle_backup_error "Missing required commands: ${missing_commands[*]}"
    fi
    
    print_status "Prerequisites validation passed"
}

# Main backup function
main() {
    local backup_success=true
    local failed_components=()
    
    print_status "Starting Claude AI Agent backup process"
    echo "$(date): Backup started - backup_$DATE" >> "$LOG_FILE"
    
    # Validate environment
    validate_prerequisites
    check_disk_space
    
    # Perform backup components
    print_status "Creating backup set: backup_$DATE"
    
    # Database backup
    if ! backup_database; then
        backup_success=false
        failed_components+=("database")
    fi
    
    # Configuration backup
    if ! backup_configuration; then
        backup_success=false
        failed_components+=("configuration")
    fi
    
    # Application code backup
    if ! backup_application_code; then
        backup_success=false
        failed_components+=("application code")
    fi
    
    # Logs backup
    if ! backup_logs; then
        backup_success=false
        failed_components+=("logs")
    fi
    
    # System information backup
    if ! backup_system_info; then
        backup_success=false
        failed_components+=("system information")
    fi
    
    # Create manifest even if some backups failed
    if ! create_backup_manifest; then
        backup_success=false
        failed_components+=("manifest")
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Show results
    if [ "$backup_success" = true ]; then
        show_backup_summary
        print_status "Backup completed successfully"
        echo "$(date): Backup completed successfully - backup_$DATE" >> "$LOG_FILE"
        exit 0
    else
        echo
        echo "========================================"
        echo "⚠️ Backup completed with issues!"
        echo "========================================"
        echo
        print_warning "Failed components: ${failed_components[*]}"
        echo
        echo "Partial backup created: backup_$DATE"
        echo "Check logs for details: $LOG_FILE"
        echo "Review manifest: $MANIFEST_FILE"
        echo
        echo "$(date): Backup completed with issues - backup_$DATE - Failed: ${failed_components[*]}" >> "$LOG_FILE"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
