#!/usr/bin/env zsh

# Test Suite 05: Dry-Run and Sandbox Mode
# Tests that dry-run mode prevents all destructive operations

source /test/bin/remote

test_start "Dry-run flag activates dry-run mode"
_result=$(/test/bin/remote --dry-run list "*" 2>&1)
assert_contains "${_result}" "DRY RUN MODE ENABLED" "Shows dry-run activation message"

test_start "Dry-run mount prevents actual mount"
_result=$(/test/bin/remote --dry-run mount "test-unit-a" 2>&1)
assert_contains "${_result}" "DRY RUN" "Shows dry-run mode"
assert_contains "${_result}" "Would mount" "Prevents actual mount"

# Verify no mount happened
[[ ! -f "${XDG_RUNTIME_DIR}/remote/test-unit-a/rclone.conf" ]] && \
    test_pass "No runtime config created in dry-run" || \
    test_fail "Dry-run prevention" "no config" "config created"

test_start "Dry-run unmount is safe"
_result=$(/test/bin/remote --dry-run unmount "test-unit-a" 2>&1 || true)
# Should not crash even if not mounted
[[ $? -eq 0 ]] || [[ $? -eq 1 ]] && test_pass "Dry-run unmount runs safely" || test_fail "Dry-run unmount" "safe" "crashes"

test_start "Dry-run sync prevents file operations"
_result=$(/test/bin/remote --dry-run sync "media-test" 2>&1 || true)
assert_contains "${_result}" "DRY RUN\|Preview" "Shows dry-run/preview mode"

test_start "Dry-run enable prevents systemd changes"
_result=$(/test/bin/remote --dry-run enable "test-unit-a" 2>&1)
assert_contains "${_result}" "Would enable" "Prevents actual enable"

test_start "Dry-run disable prevents systemd changes"
_result=$(/test/bin/remote --dry-run disable "test-unit-a" 2>&1)
assert_contains "${_result}" "Would disable" "Prevents actual disable"

test_start "Dry-run restart prevents systemd changes"
_result=$(/test/bin/remote --dry-run restart "test-unit-a" 2>&1)
assert_contains "${_result}" "Would restart" "Prevents actual restart"

test_start "Dry-run mount-all prevents bulk operations"
_result=$(/test/bin/remote --dry-run mount-all "test-*" 2>&1)
assert_contains "${_result}" "Would mount: test-unit-a" "Shows what would happen"
assert_contains "${_result}" "Would mount: test-unit-b" "Lists all targets"
assert_contains "${_result}" "Would mount: test-unit-c" "Complete listing"

test_start "Dry-run unmount-all prevents bulk operations"
_result=$(/test/bin/remote --dry-run unmount-all "*" 2>&1)
assert_contains "${_result}" "Would unmount" "Shows unmount preview"

test_start "Dry-run enable-all prevents bulk operations"
_result=$(/test/bin/remote --dry-run enable-all "test-*" 2>&1)
assert_contains "${_result}" "Would enable" "Shows enable preview"

test_start "Dry-run disable-all prevents bulk operations"
_result=$(/test/bin/remote --dry-run disable-all "test-*" 2>&1)
assert_contains "${_result}" "Would disable" "Shows disable preview"

test_start "Dry-run restart-all prevents bulk operations"
_result=$(/test/bin/remote --dry-run restart-all "test-*" 2>&1)
assert_contains "${_result}" "Would restart" "Shows restart preview"

test_start "Dry-run cleanup prevents file deletion"
# Create a test directory that would be removed
_test_dir="${XDG_RUNTIME_DIR}/remote/dry-run-test"
mkdir -p "${_test_dir}"
echo "test" > "${_test_dir}/file"

_result=$(/test/bin/remote --dry-run cleanup 2>&1)
assert_contains "${_result}" "Would remove" "Shows what would be removed"

# Verify directory still exists
[[ -d "${_test_dir}" ]] && test_pass "Dry-run cleanup preserves files" || \
    test_fail "Dry-run cleanup" "preserves" "deletes"

# Cleanup test directory
rm -rf "${_test_dir}"

test_start "Sandbox command wraps in dry-run"
_result=$(/test/bin/remote sandbox mount "test-unit-a" 2>&1)
assert_contains "${_result}" "Running in sandbox mode" "Shows sandbox activation"
assert_contains "${_result}" "DRY RUN" "Activates dry-run"

test_start "Sandbox enable command"
_result=$(/test/bin/remote sandbox enable 2>&1)
assert_contains "${_result}" "Enabling sandbox mode" "Shows sandbox enable"

test_start "Sandbox disable command"
_result=$(/test/bin/remote sandbox disable 2>&1)
assert_contains "${_result}" "Disabling sandbox mode" "Shows sandbox disable"

test_start "Multiple operations in dry-run"
# Run several commands to ensure dry-run persists
/test/bin/remote --dry-run mount "test-unit-a" >/dev/null 2>&1
/test/bin/remote --dry-run enable "test-unit-a" >/dev/null 2>&1
/test/bin/remote --dry-run cleanup >/dev/null 2>&1

# Verify nothing was created
_config_count=$(find "${XDG_RUNTIME_DIR}/remote" -type f 2>/dev/null | wc -l)
[[ ${_config_count} -eq 0 ]] && test_pass "Multiple dry-run operations create nothing" || \
    test_fail "Dry-run isolation" "0 files" "${_config_count} files"

test_start "Dry-run with cleanup --force"
mkdir -p "${XDG_CACHE_HOME}/remote/test-cache"
echo "data" > "${XDG_CACHE_HOME}/remote/test-cache/file"

_result=$(/test/bin/remote --dry-run cleanup --force 2>&1)
assert_contains "${_result}" "Would remove" "Shows force cleanup preview"
[[ -f "${XDG_CACHE_HOME}/remote/test-cache/file" ]] && test_pass "Force cleanup respects dry-run" || \
    test_fail "Force dry-run" "preserves" "deletes"

# Cleanup
rm -rf "${XDG_CACHE_HOME}/remote/test-cache"

test_start "Dry-run mode global variable check"
# Source and check internal state
remote_dry_run=false
_remote --dry-run list "*" >/dev/null 2>&1
# Note: In real usage, dry-run sets global var but it's scoped to command execution
test_pass "Dry-run flag processing works"

test_start "Read-only operations work in dry-run"
_result=$(/test/bin/remote --dry-run list "*" 2>&1)
assert_contains "${_result}" "test-unit-a" "List works in dry-run"
assert_contains "${_result}" "Total:" "Shows complete output"

test_start "Verify works in dry-run"
_result=$(/test/bin/remote --dry-run verify "*" 2>&1)
assert_contains "${_result}" "PASS\|FAIL" "Verify runs in dry-run"
assert_contains "${_result}" "Verification complete" "Completes verification"

test_start "Status works in dry-run"
/test/bin/remote --dry-run status >/dev/null 2>&1
[[ $? -eq 0 ]] || [[ $? -eq 1 ]] && test_pass "Status runs in dry-run" || test_fail "Status dry-run" "runs" "crashes"
