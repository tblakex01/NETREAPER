#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# NETREAPER - Test Suite: Input Validation
# ═══════════════════════════════════════════════════════════════════════════════
# Tests for IP, port, CIDR, and hostname validation functions
# ═══════════════════════════════════════════════════════════════════════════════

# Get the project root directory
NETREAPER_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Setup test environment
setup() {
    # Source the libraries
    source "$NETREAPER_ROOT/lib/core.sh"
    source "$NETREAPER_ROOT/lib/utils.sh"
}

#───────────────────────────────────────────────────────────────────────────────
# IP Validation Tests
#───────────────────────────────────────────────────────────────────────────────

@test "validate_ip accepts valid standard IP" {
    run validate_ip "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts IP with leading zeros" {
    run validate_ip "08.08.08.08"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts IP with mixed leading zeros" {
    run validate_ip "192.168.001.001"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts minimum IP" {
    run validate_ip "0.0.0.0"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts maximum IP" {
    run validate_ip "255.255.255.255"
    [ "$status" -eq 0 ]
}

@test "validate_ip rejects IP with octet > 255" {
    run validate_ip "192.168.256.1"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects IP with large octet" {
    run validate_ip "192.168.1.999"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects IP with all octets > 255" {
    run validate_ip "256.256.256.256"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects incomplete IP" {
    run validate_ip "192.168.1"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects IP with too many octets" {
    run validate_ip "192.168.1.1.1"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects non-numeric characters" {
    run validate_ip "192.168.1.a"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects empty string" {
    run validate_ip ""
    [ "$status" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Port Validation Tests
#───────────────────────────────────────────────────────────────────────────────

@test "validate_port accepts valid port 80" {
    run validate_port "80"
    [ "$status" -eq 0 ]
}

@test "validate_port accepts minimum port 1" {
    run validate_port "1"
    [ "$status" -eq 0 ]
}

@test "validate_port accepts maximum port 65535" {
    run validate_port "65535"
    [ "$status" -eq 0 ]
}

@test "validate_port rejects port 0" {
    run validate_port "0"
    [ "$status" -eq 1 ]
}

@test "validate_port rejects port > 65535" {
    run validate_port "65536"
    [ "$status" -eq 1 ]
}

@test "validate_port rejects negative port" {
    run validate_port "-1"
    [ "$status" -eq 1 ]
}

@test "validate_port rejects non-numeric port" {
    run validate_port "abc"
    [ "$status" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# CIDR Validation Tests
#───────────────────────────────────────────────────────────────────────────────

@test "validate_cidr accepts valid CIDR /24" {
    run validate_cidr "192.168.1.0/24"
    [ "$status" -eq 0 ]
}

@test "validate_cidr accepts valid CIDR /32" {
    run validate_cidr "192.168.1.1/32"
    [ "$status" -eq 0 ]
}

@test "validate_cidr accepts valid CIDR /0" {
    run validate_cidr "0.0.0.0/0"
    [ "$status" -eq 0 ]
}

@test "validate_cidr rejects invalid prefix > 32" {
    run validate_cidr "192.168.1.0/33"
    [ "$status" -eq 1 ]
}

@test "validate_cidr rejects invalid IP in CIDR" {
    run validate_cidr "192.168.256.0/24"
    [ "$status" -eq 1 ]
}

@test "validate_cidr rejects CIDR without prefix" {
    run validate_cidr "192.168.1.0"
    [ "$status" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Hostname Validation Tests
#───────────────────────────────────────────────────────────────────────────────

@test "validate_hostname accepts simple hostname" {
    run validate_hostname "example"
    [ "$status" -eq 0 ]
}

@test "validate_hostname accepts FQDN" {
    run validate_hostname "example.com"
    [ "$status" -eq 0 ]
}

@test "validate_hostname accepts subdomain" {
    run validate_hostname "sub.example.com"
    [ "$status" -eq 0 ]
}

@test "validate_hostname accepts hostname with hyphens" {
    run validate_hostname "my-server.example.com"
    [ "$status" -eq 0 ]
}

@test "validate_hostname rejects hostname starting with hyphen" {
    run validate_hostname "-invalid.com"
    [ "$status" -eq 1 ]
}

@test "validate_hostname rejects hostname ending with hyphen" {
    run validate_hostname "invalid-.com"
    [ "$status" -eq 1 ]
}

@test "validate_hostname rejects hostname with special characters" {
    run validate_hostname "invalid_host.com"
    [ "$status" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Port Spec Validation Tests  
#───────────────────────────────────────────────────────────────────────────────

@test "validate_port_spec accepts single port" {
    run validate_port_spec "80"
    [ "$status" -eq 0 ]
}

@test "validate_port_spec accepts port range" {
    run validate_port_spec "1-1024"
    [ "$status" -eq 0 ]
}

@test "validate_port_spec accepts comma-separated ports" {
    run validate_port_spec "80,443,8080"
    [ "$status" -eq 0 ]
}

@test "validate_port_spec rejects invalid range (start > end)" {
    run validate_port_spec "1024-1"
    [ "$status" -eq 1 ]
}

@test "validate_port_spec rejects range with invalid port" {
    run validate_port_spec "1-70000"
    [ "$status" -eq 1 ]
}
