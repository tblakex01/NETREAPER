# Bug Fix: Octal Interpretation in IP Validation

## Summary
Fixed a critical bug in IP address validation functions where IPv4 addresses with leading zeros (e.g., `08.08.08.08`) caused bash arithmetic errors due to octal interpretation.

## Bug Details

### Affected Functions
- `validate_ip()` in `lib/utils.sh`
- `is_valid_ip()` in `bin/netreaper`

### Root Cause
Bash arithmetic operators (`-lt`, `-gt`, `<`, `>`) interpret numbers with leading zeros as **octal** (base-8) numbers. Since octal only uses digits 0-7, numbers like `08` and `09` are invalid and cause errors:

```bash
$ bash -c 'octet="08"; if [[ $octet -gt 255 ]]; then echo fail; fi'
bash: [[: 08: value too great for base (error token is "08")
```

### Impact
- IP addresses like `08.08.08.08` (Google DNS with leading zeros) would generate errors
- IP addresses like `192.168.001.001` would work but generate errors for octets 08 or 09
- Despite errors, the validation would sometimes incorrectly pass due to error suppression

## The Fix

### Before
```bash
for octet in "${octets[@]}"; do
    if [[ "$octet" -lt 0 ]] || [[ "$octet" -gt 255 ]]; then
        return 1
    fi
done
```

### After  
```bash
for octet in "${octets[@]}"; do
    # Strip leading zeros to avoid octal interpretation issues
    # This prevents errors with IPs like 08.08.08.08 where bash
    # tries to interpret 08 and 09 as invalid octal numbers
    octet=$((10#$octet))
    
    if (( octet < 0 || octet > 255 )); then
        return 1
    fi
done
```

### Explanation
- `$((10#$octet))` forces bash to interpret the number as base-10 (decimal), stripping leading zeros
- Changed from `[[ ]]` test to `(( ))` arithmetic evaluation for cleaner integer comparison
- The `10#` prefix tells bash to treat the following number as base-10, regardless of leading zeros

## Test Cases

### Valid IPs (Should Pass)
- ✓ `192.168.1.1` - Standard IP
- ✓ `08.08.08.08` - Leading zeros (fixed by this patch)
- ✓ `192.168.001.001` - Mixed leading zeros (fixed by this patch)
- ✓ `0.0.0.0` - Minimum IP
- ✓ `255.255.255.255` - Maximum IP

### Invalid IPs (Should Fail)
- ✓ `192.168.256.1` - Octet > 255
- ✓ `192.168.1.999` - Large octet
- ✓ `256.256.256.256` - All octets > 255
- ✓ `192.168.1` - Incomplete IP
- ✓ `192.168.1.a` - Non-numeric

## Files Changed
- `lib/utils.sh` - Fixed `validate_ip()` function (lines 229-236)
- `bin/netreaper` - Fixed `is_valid_ip()` function (lines 1285-1290)
- `tests/validation.bats` - Added comprehensive test suite for validation functions

## Verification
All test cases pass with no errors:
```bash
$ bash tests/manual_validation_test.sh
Running IP Validation Tests
============================
✓ PASS: Standard IP
✓ PASS: IP with leading zeros (08)
✓ PASS: IP with mixed leading zeros
✓ PASS: Minimum IP
✓ PASS: Maximum IP
✓ PASS: IP with octet > 255
...
Total: 12, Passed: 12, Failed: 0
✓ All tests passed!
```

## Recommendations
Consider auditing other numeric comparisons in the codebase for similar issues:
- Port validation
- Subnet mask validation  
- Any arithmetic on user-provided numeric strings

## References
- Bash Manual: Arithmetic Expansion
- Issue: Leading zeros cause octal interpretation in bash arithmetic
- Solution: Use `10#` prefix to force decimal interpretation
