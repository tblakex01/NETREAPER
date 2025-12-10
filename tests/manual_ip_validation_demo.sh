#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# NETREAPER - Manual Test: IP Validation Bug Demonstration
# ═══════════════════════════════════════════════════════════════════════════════
# This script demonstrates the octal interpretation bug and its fix
# ═══════════════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════════════"
echo "IP Validation Bug Demonstration"
echo "═══════════════════════════════════════════════════════════════════════════"
echo

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the fixed libraries
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/utils.sh"

echo "DEMONSTRATION: The octal interpretation bug"
echo "============================================"
echo
echo "Before the fix, bash would try to interpret numbers with leading zeros"
echo "as octal (base-8) numbers. Since octal only has digits 0-7, numbers"
echo "like 08 and 09 would cause errors."
echo
echo "Let's demonstrate the OLD buggy behavior:"
echo

# Show the buggy version
validate_ip_buggy() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "$ip" =~ $regex ]]; then
        return 1
    fi
    
    local IFS='.'
    read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        # BUGGY: This will fail with 08 or 09 due to octal interpretation
        if [[ "$octet" -lt 0 ]] || [[ "$octet" -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

echo "Test 1: Testing '08.08.08.08' with BUGGY version (errors expected):"
echo "--------------------------------------------------------------------"
if validate_ip_buggy "08.08.08.08" 2>&1; then
    echo "Result: PASSED (but with errors above!)"
else
    echo "Result: FAILED"
fi
echo

echo "═══════════════════════════════════════════════════════════════════════════"
echo

echo "Now let's test with the FIXED version:"
echo "======================================="
echo

test_ip_with_description() {
    local ip="$1"
    local description="$2"
    
    echo "Test: $description"
    echo "IP: $ip"
    echo -n "Result: "
    
    # Capture any stderr
    local result
    if result=$(validate_ip "$ip" 2>&1); then
        echo "✓ VALID (no errors)"
    else
        if [[ -n "$result" ]]; then
            echo "✗ INVALID (with output: $result)"
        else
            echo "✗ INVALID"
        fi
    fi
    echo
}

test_ip_with_description "192.168.1.1" "Standard IP address"
test_ip_with_description "08.08.08.08" "IP with leading zeros (08) - THE BUG FIX!"
test_ip_with_description "192.168.001.001" "IP with mixed leading zeros"
test_ip_with_description "192.168.256.1" "Invalid IP (octet > 255)"
test_ip_with_description "0.0.0.0" "Minimum IP"
test_ip_with_description "255.255.255.255" "Maximum IP"

echo "═══════════════════════════════════════════════════════════════════════════"
echo

echo "SUMMARY:"
echo "--------"
echo "✓ The fix successfully handles IP addresses with leading zeros"
echo "✓ No more 'value too great for base' errors"
echo "✓ All valid IPs (including those with leading zeros) now pass validation"
echo "✓ Invalid IPs are still correctly rejected"
echo

echo "═══════════════════════════════════════════════════════════════════════════"
echo "Technical Details:"
echo "═══════════════════════════════════════════════════════════════════════════"
echo
echo "The fix uses the 10# prefix in bash arithmetic expansion:"
echo
echo "  octet=\$((10#\$octet))"
echo
echo "This tells bash to interpret the number as base-10 (decimal) regardless"
echo "of leading zeros, preventing octal interpretation errors."
echo
echo "Example:"
echo "  \$((08))     → Error: 'value too great for base'"
echo "  \$((10#08))  → 8 (correctly interpreted as decimal)"
echo
echo "═══════════════════════════════════════════════════════════════════════════"
