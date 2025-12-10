#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# NETREAPER - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 OFFTRACKMEDIA Studios (ABN: 84 290 819 896)
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# See LICENSE and NOTICE files in the project root for full details.
# ═══════════════════════════════════════════════════════════════════════════════
#
# Utility library: timestamps, backups, file generation, validation, tool execution
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_NETREAPER_UTILS_LOADED:-}" ]] && return 0
readonly _NETREAPER_UTILS_LOADED=1

# Source core library
source "${BASH_SOURCE%/*}/core.sh"

#═══════════════════════════════════════════════════════════════════════════════
# TIMESTAMP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Generate formatted timestamp
# Args: $1 = format (optional, defaults to ISO-like)
# Returns: formatted timestamp string
timestamp() {
    local format="${1:-%Y-%m-%d %H:%M:%S}"
    date +"$format"
}

# Generate timestamp for filenames (no special chars)
# Returns: YYYYMMDD_HHMMSS format
timestamp_filename() {
    date +"%Y%m%d_%H%M%S"
}

# Generate date-only timestamp
# Returns: YYYY-MM-DD format
timestamp_date() {
    date +"%Y-%m-%d"
}

# Generate ISO 8601 timestamp
# Returns: ISO 8601 format with timezone
timestamp_iso() {
    date -Iseconds
}

#═══════════════════════════════════════════════════════════════════════════════
# FILE BACKUP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Create timestamped backup of a file
# Args: $1 = file path
# Returns: path to backup file, or empty on failure
backup_file() {
    local file="$1"

    # Validate input
    if [[ -z "$file" ]]; then
        log_error "backup_file: No file specified"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "backup_file: File not found: $file"
        return 1
    fi

    # Generate backup filename
    local backup_name="${file}.backup.$(timestamp_filename)"

    # Create backup
    if cp "$file" "$backup_name" 2>/dev/null; then
        log_debug "Created backup: $backup_name"
        echo "$backup_name"
        return 0
    else
        log_error "backup_file: Failed to create backup of $file"
        return 1
    fi
}

# Create backup in a specific directory
# Args: $1 = file path, $2 = backup directory
# Returns: path to backup file
backup_file_to() {
    local file="$1"
    local backup_dir="${2:-$OUTPUT_DIR}"

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        log_error "backup_file_to: Invalid file: $file"
        return 1
    fi

    mkdir -p "$backup_dir" 2>/dev/null

    local basename=$(basename "$file")
    local backup_name="${backup_dir}/${basename}.backup.$(timestamp_filename)"

    if cp "$file" "$backup_name" 2>/dev/null; then
        log_debug "Created backup: $backup_name"
        echo "$backup_name"
        return 0
    else
        log_error "backup_file_to: Failed to create backup"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Global array for cleanup tasks
declare -ga _CLEANUP_TASKS=()

# Register a cleanup task
# Args: $1 = command to run on cleanup
register_cleanup() {
    local task="$1"
    [[ -z "$task" ]] && return
    _CLEANUP_TASKS+=("$task")
    log_debug "Registered cleanup task: $task"
}

# Cleanup handler for exit trap
# Runs all registered cleanup tasks
cleanup_on_exit() {
    local exit_code=$?

    log_debug "Running cleanup tasks (exit code: $exit_code)"

    # Run cleanup tasks in reverse order
    local i
    for ((i=${#_CLEANUP_TASKS[@]}-1; i>=0; i--)); do
        local task="${_CLEANUP_TASKS[$i]}"
        log_debug "Cleanup: $task"
        eval "$task" 2>/dev/null || true
    done

    # Clean temp files
    if [[ -n "${TMP_DIR:-}" ]] && [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"/* 2>/dev/null || true
    fi

    log_debug "Cleanup complete"
    return $exit_code
}

# Clear all registered cleanup tasks
clear_cleanup_tasks() {
    _CLEANUP_TASKS=()
    log_debug "Cleared all cleanup tasks"
}

#═══════════════════════════════════════════════════════════════════════════════
# FILENAME GENERATION
#═══════════════════════════════════════════════════════════════════════════════

# Generate unique report/output filename
# Args: $1 = prefix, $2 = extension (optional, default: txt)
# Returns: unique filename path
generate_report_name() {
    local prefix="${1:-report}"
    local extension="${2:-txt}"
    local output_dir="${OUTPUT_DIR:-/tmp}"

    # Sanitize prefix
    prefix=$(echo "$prefix" | tr -cd '[:alnum:]._-')

    # Generate unique name
    local filename="${prefix}_$(timestamp_filename).${extension}"
    local filepath="${output_dir}/${filename}"

    # Ensure output dir exists
    mkdir -p "$output_dir" 2>/dev/null

    echo "$filepath"
}

# Generate unique filename with target in name
# Args: $1 = target, $2 = prefix, $3 = extension
# Returns: unique filename path
generate_target_filename() {
    local target="${1:-unknown}"
    local prefix="${2:-scan}"
    local extension="${3:-txt}"

    # Sanitize target for filename
    local safe_target=$(echo "$target" | tr -cd '[:alnum:]._-' | cut -c1-50)

    generate_report_name "${prefix}_${safe_target}" "$extension"
}

#═══════════════════════════════════════════════════════════════════════════════
# INPUT VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate IPv4 address format
# Args: $1 = IP address
# Returns: 0 if valid, 1 if invalid
validate_ip() {
    local ip="$1"

    # Basic regex check
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi

    # Check each octet is 0-255
    local IFS='.'
    read -ra octets <<< "$ip"

    for octet in "${octets[@]}"; do
        # Strip leading zeros to avoid octal interpretation issues
        # This prevents errors with IPs like 08.08.08.08 where bash
        # tries to interpret 08 and 09 as invalid octal numbers
        octet=$((10#$octet))
        
        if (( octet < 0 || octet > 255 )); then
            return 1
        fi
    done

    return 0
}

# Validate CIDR notation
# Args: $1 = CIDR (e.g., 192.168.1.0/24)
# Returns: 0 if valid, 1 if invalid
validate_cidr() {
    local cidr="$1"

    # Check format
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi

    # Split IP and prefix
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    # Validate IP part
    if ! validate_ip "$ip"; then
        return 1
    fi

    # Validate prefix (0-32 for IPv4)
    if [[ "$prefix" -lt 0 ]] || [[ "$prefix" -gt 32 ]]; then
        return 1
    fi

    return 0
}

# Validate hostname format
# Args: $1 = hostname
# Returns: 0 if valid, 1 if invalid
validate_hostname() {
    local hostname="$1"

    # Check format (alphanumeric, hyphens, dots)
    if [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi

    return 1
}

# Validate port number
# Args: $1 = port
# Returns: 0 if valid, 1 if invalid
validate_port() {
    local port="$1"

    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    fi

    return 1
}

# Validate port range (e.g., 1-1024 or 80,443,8080)
# Args: $1 = port specification
# Returns: 0 if valid, 1 if invalid
validate_port_spec() {
    local spec="$1"

    # Single port
    if [[ "$spec" =~ ^[0-9]+$ ]]; then
        validate_port "$spec"
        return $?
    fi

    # Range (e.g., 1-1024)
    if [[ "$spec" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start="${spec%-*}"
        local end="${spec#*-}"
        validate_port "$start" && validate_port "$end" && [[ "$start" -le "$end" ]]
        return $?
    fi

    # Comma-separated list
    if [[ "$spec" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        local IFS=','
        read -ra ports <<< "$spec"
        for port in "${ports[@]}"; do
            validate_port "$port" || return 1
        done
        return 0
    fi

    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL EXECUTION
#═══════════════════════════════════════════════════════════════════════════════

# Run a tool with logging
# Args: $1 = tool name, $2+ = arguments
# Returns: tool's exit code
run_tool() {
    local tool="$1"
    shift
    local args=("$@")

    # Check tool exists
    if ! command -v "$tool" &>/dev/null; then
        log_error "Tool not found: $tool"
        return 127
    fi

    # Log command
    local cmd_str="$tool ${args[*]}"
    log_command_preview "$cmd_str"
    log_audit "TOOL_EXEC" "$tool" "started"

    # Execute
    local start_time=$(date +%s)
    "$tool" "${args[@]}"
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Log result
    if [[ $exit_code -eq 0 ]]; then
        log_debug "$tool completed successfully in ${duration}s"
        log_audit "TOOL_EXEC" "$tool" "success"
    else
        log_debug "$tool failed with exit code $exit_code after ${duration}s"
        log_audit "TOOL_EXEC" "$tool" "failed:$exit_code"
    fi

    return $exit_code
}

# Run a tool silently (no output)
# Args: $1 = tool name, $2+ = arguments
# Returns: tool's exit code
run_tool_silent() {
    local tool="$1"
    shift

    if ! command -v "$tool" &>/dev/null; then
        return 127
    fi

    "$tool" "$@" &>/dev/null
    return $?
}

# Run a tool with timeout
# Args: $1 = timeout (seconds), $2 = tool name, $3+ = arguments
# Returns: tool's exit code or 124 on timeout
run_tool_timeout() {
    local timeout_sec="$1"
    local tool="$2"
    shift 2

    if ! command -v timeout &>/dev/null; then
        log_warning "timeout command not available, running without timeout"
        run_tool "$tool" "$@"
        return $?
    fi

    log_command_preview "timeout $timeout_sec $tool $*"
    timeout "$timeout_sec" "$tool" "$@"
    local exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        log_warning "$tool timed out after ${timeout_sec}s"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# MISC UTILITIES
#═══════════════════════════════════════════════════════════════════════════════

# Check if string is numeric
# Args: $1 = string
# Returns: 0 if numeric, 1 if not
is_numeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Generate random string
# Args: $1 = length (default: 16)
# Returns: random alphanumeric string
random_string() {
    local length="${1:-16}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Calculate elapsed time in human-readable format
# Args: $1 = start timestamp (epoch), $2 = end timestamp (optional, defaults to now)
# Returns: human-readable duration
elapsed_time() {
    local start="$1"
    local end="${2:-$(date +%s)}"
    local duration=$((end - start))

    if [[ $duration -lt 60 ]]; then
        echo "${duration}s"
    elif [[ $duration -lt 3600 ]]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "$((duration / 3600))h $((duration % 3600 / 60))m"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Timestamps
export -f timestamp timestamp_filename timestamp_date timestamp_iso

# Backups
export -f backup_file backup_file_to

# Cleanup
export -f register_cleanup cleanup_on_exit clear_cleanup_tasks

# Filename generation
export -f generate_report_name generate_target_filename

# Validation
export -f validate_ip validate_cidr validate_hostname validate_port validate_port_spec

# Tool execution
export -f run_tool run_tool_silent run_tool_timeout

# Misc
export -f is_numeric random_string elapsed_time
