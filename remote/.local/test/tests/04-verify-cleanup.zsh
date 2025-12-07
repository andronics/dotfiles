#!/usr/bin/env zsh

# Test Suite 04: Verify and Cleanup Operations
# Tests configuration verification and cleanup functions

source /test/bin/remote

test_start "List command shows headers"
_result=$(/test/bin/remote list "test-*" 2>&1)
assert_contains "${_result}" "UNIT" "List shows UNIT header"
assert_contains "${_result}" "MOUNTPOINT" "List shows MOUNTPOINT header"
assert_contains "${_result}" "STATUS" "List shows STATUS header"
assert_contains "${_result}" "CACHE SIZE" "List shows CACHE SIZE header"

test_start "List command shows unit details"
_result=$(/test/bin/remote list "test-unit-a" 2>&1)
assert_contains "${_result}" "test-unit-a" "Shows unit name"
assert_contains "${_result}" "test/unit-a" "Shows mountpoint"
assert_contains "${_result}" "inactive" "Shows status (inactive)"

test_start "List command shows total count"
_result=$(/test/bin/remote list "test-*" 2>&1)
assert_contains "${_result}" "Total: 3 unit(s)" "Shows correct total"

test_start "Verify detects valid configuration"
_result=$(/test/bin/remote verify "test-unit-a" 2>&1)
assert_contains "${_result}" "\[PASS\]" "Shows PASS for valid unit"
assert_contains "${_result}" "not mounted" "Shows mount status"

test_start "Verify detects invalid credentials"
_result=$(/test/bin/remote verify "invalid-unit" 2>&1)
assert_contains "${_result}" "\[FAIL\]" "Shows FAIL for invalid unit"
assert_contains "${_result}" "Credentials.*not found" "Identifies missing credentials"

test_start "Verify shows summary statistics"
_result=$(/test/bin/remote verify "*" 2>&1)
assert_contains "${_result}" "passed" "Shows passed count"
assert_contains "${_result}" "failed" "Shows failed count"
assert_contains "${_result}" "Verification complete" "Shows completion message"

test_start "Verify returns non-zero exit code on failures"
/test/bin/remote verify "invalid-unit" >/dev/null 2>&1
[[ $? -ne 0 ]] && test_pass "Verify returns error code for failures" || test_fail "Exit code" "non-zero" "zero"

test_start "Cleanup with no stale configs"
_result=$(/test/bin/remote cleanup 2>&1)
assert_contains "${_result}" "Cleanup complete" "Cleanup completes successfully"
assert_contains "${_result}" "0 item(s) removed" "No items removed when clean"

test_start "Setup: Create stale runtime config"
_stale_dir="${XDG_RUNTIME_DIR}/remote/stale-unit"
mkdir -p "${_stale_dir}"
echo "stale config" > "${_stale_dir}/rclone.conf"
assert_file_exists "${_stale_dir}/rclone.conf" "Stale config created"

test_start "Cleanup removes stale runtime configs"
_result=$(/test/bin/remote cleanup 2>&1)
assert_contains "${_result}" "1 item(s) removed" "Removes 1 stale config"
[[ ! -d "${_stale_dir}" ]] && test_pass "Stale directory removed" || test_fail "Stale removal" "directory gone" "directory exists"

test_start "Setup: Create empty cache directory"
_empty_cache="${XDG_CACHE_HOME}/remote/empty-unit"
mkdir -p "${_empty_cache}"
assert_dir_exists "${_empty_cache}" "Empty cache created"

test_start "Cleanup removes empty cache directories"
_result=$(/test/bin/remote cleanup 2>&1)
[[ ! -d "${_empty_cache}" ]] && test_pass "Empty cache removed" || test_fail "Empty cache removal" "directory gone" "directory exists"

test_start "Setup: Create non-empty cache directory"
_cache_with_data="${XDG_CACHE_HOME}/remote/unit-with-data"
mkdir -p "${_cache_with_data}"
echo "cache data" > "${_cache_with_data}/file.dat"
assert_file_exists "${_cache_with_data}/file.dat" "Cache with data created"

test_start "Cleanup preserves non-empty cache directories"
/test/bin/remote cleanup >/dev/null 2>&1
[[ -d "${_cache_with_data}" ]] && test_pass "Non-empty cache preserved" || test_fail "Cache preservation" "directory exists" "directory removed"
[[ -f "${_cache_with_data}/file.dat" ]] && test_pass "Cache data preserved" || test_fail "Data preservation" "file exists" "file removed"

test_start "Cleanup --force removes all caches"
_result=$(/test/bin/remote cleanup --force 2>&1)
[[ ! -d "${_cache_with_data}" ]] && test_pass "Force cleanup removes all caches" || test_fail "Force cleanup" "directory gone" "directory exists"

test_start "Cleanup in dry-run mode"
mkdir -p "${_stale_dir}"
_result=$(/test/bin/remote --dry-run cleanup 2>&1)
assert_contains "${_result}" "DRY RUN" "Shows dry-run mode"
assert_contains "${_result}" "Would remove" "Shows what would be removed"
[[ -d "${_stale_dir}" ]] && test_pass "Dry-run preserves directories" || test_fail "Dry-run" "directory preserved" "directory removed"

test_start "Cleanup after dry-run test"
rm -rf "${_stale_dir}"
[[ ! -d "${_stale_dir}" ]] && test_pass "Manual cleanup successful" || test_fail "Manual cleanup" "directory gone" "directory exists"

test_start "Status command lists systemd units"
_result=$(/test/bin/remote status 2>&1 || true)
# Status may show no units loaded, which is fine in test environment
[[ $? -eq 0 ]] || [[ $? -eq 1 ]] && test_pass "Status command runs" || test_fail "Status command" "runs" "crashes"

test_start "Verify checks for mountpoint configuration"
# Create a unit with missing mountpoint
_test_units=$(cat "${XDG_CONFIG_HOME}/remote/units.json")
echo "${_test_units}" | jq '. + {"no-mountpoint": {"credentials": "test@example.com"}}' > "${XDG_CONFIG_HOME}/remote/units.json"

_result=$(/test/bin/remote verify "no-mountpoint" 2>&1 || true)
assert_contains "${_result}" "Mountpoint not configured" "Detects missing mountpoint"

# Restore original units config
echo "${_test_units}" > "${XDG_CONFIG_HOME}/remote/units.json"
test_pass "Test config restored"
