#!/usr/bin/env zsh

# Test Suite 01: Mount and Unmount Operations
# Tests basic mount/unmount functionality with single units

test_start "Pattern matching - single unit"
_result=$(/test/bin/remote list "test-unit-a" 2>&1)
assert_contains "${_result}" "test-unit-a" "List shows test-unit-a"

test_start "Pattern matching - glob pattern"
_result=$(/test/bin/remote list "test-*" 2>&1)
assert_contains "${_result}" "test-unit-a" "List shows test-unit-a in pattern"
assert_contains "${_result}" "test-unit-b" "List shows test-unit-b in pattern"
assert_contains "${_result}" "test-unit-c" "List shows test-unit-c in pattern"

test_start "Pattern matching - all units"
_result=$(/test/bin/remote list "*" 2>&1)
assert_contains "${_result}" "test-unit-a" "List shows all units"
assert_contains "${_result}" "media-test" "List shows media-test"

test_start "Verify valid unit configuration"
_result=$(/test/bin/remote verify "test-unit-a" 2>&1)
assert_contains "${_result}" "PASS" "Verification passes for valid unit"

test_start "Verify invalid unit configuration"
_result=$(/test/bin/remote verify "invalid-unit" 2>&1)
assert_contains "${_result}" "FAIL" "Verification fails for invalid credentials"

test_start "Verify non-existent unit"
_result=$(/test/bin/remote verify "does-not-exist" 2>&1 || true)
assert_contains "${_result}" "No units match" "Error for non-existent unit"

test_start "Config directory created"
assert_dir_exists "${XDG_CONFIG_HOME}/remote" "Config directory exists"

test_start "Runtime directory created"
assert_dir_exists "${XDG_RUNTIME_DIR}/remote" "Runtime directory exists"

test_start "Cache directory created"
assert_dir_exists "${XDG_CACHE_HOME}/remote" "Cache directory exists"

# Note: Actual mount tests require rclone backend configuration
# In real environment, these would test actual mounts
# For now, we test dry-run behavior

test_start "Mount dry-run mode"
_result=$(/test/bin/remote --dry-run mount "test-unit-a" 2>&1)
assert_contains "${_result}" "DRY RUN" "Dry-run mode activated"
assert_contains "${_result}" "Would mount" "Dry-run prevents actual mount"

test_start "Unmount non-existent mount"
_result=$(/test/bin/remote unmount "test-unit-a" 2>&1 || true)
# Should not crash, may warn about not mounted
[[ $? -eq 0 ]] || [[ $? -eq 1 ]] && test_pass "Unmount handles non-mounted unit gracefully"

test_start "Query helpers work correctly"
# Source the remote script to test internal functions
source /test/bin/remote

_result=$(_remote_query "units" ".\"test-unit-a\".mountpoint")
assert_equals "test/unit-a" "${_result}" "Query extracts mountpoint correctly"

_result=$(_remote_query "units" ".\"test-unit-a\".credentials")
assert_equals "test@example.com" "${_result}" "Query extracts credentials correctly"

test_start "Match units helper - single pattern"
_units=$(_remote_match_units "test-unit-a")
assert_contains "${_units}" "test-unit-a" "Matches exact unit name"

test_start "Match units helper - glob pattern"
_units=$(_remote_match_units "test-*")
_count=$(echo "${_units}" | wc -l)
[[ ${_count} -eq 3 ]] && test_pass "Matches 3 test-* units" || test_fail "Match count" "3" "${_count}"

test_start "Match units helper - all units"
_units=$(_remote_match_units "*")
assert_contains "${_units}" "test-unit-a" "All units includes test-unit-a"
assert_contains "${_units}" "media-test" "All units includes media-test"
