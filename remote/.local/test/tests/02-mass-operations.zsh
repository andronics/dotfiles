#!/usr/bin/env zsh

# Test Suite 02: Mass Operations
# Tests bulk mount/unmount/enable/disable operations with patterns

source /test/bin/remote

test_start "Mount-all with pattern (dry-run)"
_result=$(/test/bin/remote --dry-run mount-all "test-*" 2>&1)
assert_contains "${_result}" "DRY RUN" "Dry-run mode active"
assert_contains "${_result}" "Mounting units matching: test-*" "Shows pattern being matched"
assert_contains "${_result}" "Would mount: test-unit-a" "Would mount test-unit-a"
assert_contains "${_result}" "Would mount: test-unit-b" "Would mount test-unit-b"
assert_contains "${_result}" "Would mount: test-unit-c" "Would mount test-unit-c"
assert_contains "${_result}" "Mounted 3 unit(s)" "Reports 3 units"

test_start "Unmount-all with pattern (dry-run)"
_result=$(/test/bin/remote --dry-run unmount-all "test-*" 2>&1)
assert_contains "${_result}" "Unmounting units matching: test-*" "Shows pattern"
assert_contains "${_result}" "Would unmount: test-unit-a" "Would unmount test-unit-a"
assert_contains "${_result}" "Unmounted 3 unit(s)" "Reports 3 units"

test_start "Enable-all with comma-separated pattern (dry-run)"
_result=$(/test/bin/remote --dry-run enable-all "test-unit-a,test-unit-b" 2>&1)
assert_contains "${_result}" "Would enable: test-unit-a" "Would enable test-unit-a"
assert_contains "${_result}" "Would enable: test-unit-b" "Would enable test-unit-b"
assert_contains "${_result}" "Enabled 2 unit(s)" "Reports 2 units"

test_start "Disable-all with pattern (dry-run)"
_result=$(/test/bin/remote --dry-run disable-all "media-*" 2>&1)
assert_contains "${_result}" "Would disable: media-test" "Would disable media-test"
assert_contains "${_result}" "Disabled 1 unit(s)" "Reports 1 unit"

test_start "Restart-all with all units pattern (dry-run)"
_result=$(/test/bin/remote --dry-run restart-all "*" 2>&1)
assert_contains "${_result}" "Restarting units matching: *" "Shows wildcard pattern"
assert_contains "${_result}" "Would restart: test-unit-a" "Would restart test-unit-a"
assert_contains "${_result}" "Would restart: media-test" "Would restart media-test"
_count=$(echo "${_result}" | grep -c "Would restart:" || true)
[[ ${_count} -eq 5 ]] && test_pass "Restarts all 5 units" || test_fail "Restart count" "5" "${_count}"

test_start "Mount-all with no matching pattern"
_result=$(/test/bin/remote --dry-run mount-all "nonexistent-*" 2>&1 || true)
assert_contains "${_result}" "No units match pattern" "Error for no matches"

test_start "Mass operation with empty pattern defaults to all"
_result=$(/test/bin/remote --dry-run mount-all 2>&1)
assert_contains "${_result}" "test-unit-a" "Defaults to all units"
assert_contains "${_result}" "media-test" "Includes all units"

test_start "List shows correct count"
_result=$(/test/bin/remote list "*" 2>&1)
assert_contains "${_result}" "Total: 5 unit(s)" "Shows total count of 5 units"

test_start "List with pattern filters correctly"
_result=$(/test/bin/remote list "test-*" 2>&1)
assert_contains "${_result}" "Total: 3 unit(s)" "Shows 3 test units"
[[ ! "${_result}" =~ "media-test" ]] && test_pass "Excludes non-matching units" || test_fail "Pattern filtering" "excludes media-test" "includes media-test"

test_start "Verify-all shows pass/fail summary"
_result=$(/test/bin/remote verify "*" 2>&1)
assert_contains "${_result}" "passed" "Shows passed count"
assert_contains "${_result}" "failed" "Shows failed count"
assert_contains "${_result}" "PASS.*test-unit-a" "test-unit-a passes"
assert_contains "${_result}" "FAIL.*invalid-unit" "invalid-unit fails"

test_start "Single enable command (dry-run)"
_result=$(/test/bin/remote --dry-run enable "test-unit-a" 2>&1)
assert_contains "${_result}" "Would enable: test-unit-a" "Single enable respects dry-run"

test_start "Single disable command (dry-run)"
_result=$(/test/bin/remote --dry-run disable "test-unit-a" 2>&1)
assert_contains "${_result}" "Would disable: test-unit-a" "Single disable respects dry-run"

test_start "Single restart command (dry-run)"
_result=$(/test/bin/remote --dry-run restart "test-unit-a" 2>&1)
assert_contains "${_result}" "Would restart: test-unit-a" "Single restart respects dry-run"
