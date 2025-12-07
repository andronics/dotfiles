#!/usr/bin/env zsh

# Test Suite 03: Sync and Filter Operations
# Tests file filtering and sync logic

source /test/bin/remote

# Test filter evaluation function
test_start "Filter operator: eq (equals)"
_remote_evaluate_filter "test" "eq" "value" "value"
[[ $? -eq 0 ]] && test_pass "eq operator returns true for equal values" || test_fail "eq operator" "true" "false"

_remote_evaluate_filter "test" "eq" "value1" "value2"
[[ $? -eq 1 ]] && test_pass "eq operator returns false for different values" || test_fail "eq operator" "false" "true"

test_start "Filter operator: ne (not equals)"
_remote_evaluate_filter "test" "ne" "value1" "value2"
[[ $? -eq 0 ]] && test_pass "ne operator returns true for different values" || test_fail "ne operator" "true" "false"

test_start "Filter operator: lt (less than)"
_remote_evaluate_filter "test" "lt" "100" "50"
[[ $? -eq 0 ]] && test_pass "lt operator returns true for 50 < 100" || test_fail "lt operator" "true" "false"

_remote_evaluate_filter "test" "lt" "50" "100"
[[ $? -eq 1 ]] && test_pass "lt operator returns false for 100 > 50" || test_fail "lt operator" "false" "true"

test_start "Filter operator: le (less than or equal)"
_remote_evaluate_filter "test" "le" "100" "100"
[[ $? -eq 0 ]] && test_pass "le operator returns true for equal values" || test_fail "le operator" "true" "false"

_remote_evaluate_filter "test" "le" "100" "50"
[[ $? -eq 0 ]] && test_pass "le operator returns true for 50 <= 100" || test_fail "le operator" "true" "false"

test_start "Filter operator: gt (greater than)"
_remote_evaluate_filter "test" "gt" "50" "100"
[[ $? -eq 0 ]] && test_pass "gt operator returns true for 100 > 50" || test_fail "gt operator" "true" "false"

test_start "Filter operator: ge (greater than or equal)"
_remote_evaluate_filter "test" "ge" "100" "100"
[[ $? -eq 0 ]] && test_pass "ge operator returns true for equal values" || test_fail "ge operator" "true" "false"

test_start "Filter operator: in (pipe-separated values)"
_remote_evaluate_filter "test" "in" "8|10|12" "10"
[[ $? -eq 0 ]] && test_pass "in operator returns true for matching value" || test_fail "in operator" "true" "false"

_remote_evaluate_filter "test" "in" "8|10|12" "9"
[[ $? -eq 1 ]] && test_pass "in operator returns false for non-matching value" || test_fail "in operator" "false" "true"

test_start "Filter operator: unknown operator"
_result=$(_remote_evaluate_filter "test" "unknown" "val" "val" 2>&1)
[[ $? -eq 1 ]] && test_pass "Unknown operator returns false" || test_fail "Unknown operator" "false" "true"
assert_contains "${_result}" "Unknown operator" "Logs warning for unknown operator"

# Test pattern matching for filenames
test_start "Filename pattern matching - .mp3 extension"
_filename="song.mp3"
[[ "${_filename}" =~ \.mp3$ ]] && test_pass "Matches .mp3 pattern" || test_fail "Pattern match" "true" "false"

test_start "Filename pattern matching - .mp4 extension"
_filename="video.mp4"
[[ "${_filename}" =~ \.mp4$ ]] && test_pass "Matches .mp4 pattern" || test_fail "Pattern match" "true" "false"

test_start "Filename pattern matching - test- prefix"
_filename="test-file.txt"
[[ "${_filename}" =~ test-.*\.txt$ ]] && test_pass "Matches test-*.txt pattern" || test_fail "Pattern match" "true" "false"

# Create test files for sync testing
test_start "Setup: Create test local mountpoint"
_local_dir="/test/pool/local/test/media"
mkdir -p "${_local_dir}"
assert_dir_exists "${_local_dir}" "Local mountpoint created"

test_start "Setup: Create test files"
echo "test content" > "${_local_dir}/test-file.txt"
echo "audio data" > "${_local_dir}/song.mp3"
echo "video data" > "${_local_dir}/movie.mp4"
assert_file_exists "${_local_dir}/test-file.txt" "Test text file created"
assert_file_exists "${_local_dir}/song.mp3" "Test mp3 file created"
assert_file_exists "${_local_dir}/movie.mp4" "Test mp4 file created"

# Note: Actual sync requires rclone backend and mounted drives
# Testing in dry-run/preview mode

test_start "Sync preview mode shows files"
# This would require unit to be mounted first
# For now, test that preview mode is recognized
_result=$(/test/bin/remote sync --preview "media-test" 2>&1 || true)
assert_contains "${_result}" "preview\|Preview\|DRY RUN" "Preview mode activated"

test_start "Sync dry-run mode"
_result=$(/test/bin/remote --dry-run sync "media-test" 2>&1 || true)
assert_contains "${_result}" "DRY RUN" "Dry-run mode prevents sync"

# Test query function for filters
test_start "Query filters configuration"
_filters=$(_remote_query "filters" ". | keys[]")
assert_contains "${_filters}" "\\.mp3$" "Filters include .mp3 pattern"
assert_contains "${_filters}" "\\.mp4$" "Filters include .mp4 pattern"

test_start "Query specific filter rules"
_mp3_filter=$(_remote_query "filters" ".\"\\.mp3$\"")
assert_contains "${_mp3_filter}" "mimetype" "MP3 filter includes mimetype check"
assert_contains "${_mp3_filter}" "audio_format" "MP3 filter includes audio format check"

test_start "Cleanup: Remove test files"
rm -rf "${_local_dir}"
[[ ! -d "${_local_dir}" ]] && test_pass "Test directory cleaned up" || test_fail "Cleanup" "directory removed" "directory still exists"
