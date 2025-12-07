#!/usr/bin/env zsh

# Test Runner for Remote Mount Script
# Executes all test suites in order

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result tracking
typeset -a FAILED_TEST_NAMES

# ------------------------------
# Test Framework Functions
# ------------------------------

test_start() {
    echo -e "${YELLOW}► Running: $1${NC}"
    ((TOTAL_TESTS++))
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS${NC}: $1"
    ((PASSED_TESTS++))
}

test_fail() {
    echo -e "  ${RED}✗ FAIL${NC}: $1"
    echo -e "    ${RED}Expected: $2${NC}"
    echo -e "    ${RED}Got: $3${NC}"
    ((FAILED_TESTS++))
    FAILED_TEST_NAMES+=("$1")
}

assert_equals() {
    local _expected="$1"
    local _actual="$2"
    local _message="$3"

    if [[ "${_expected}" == "${_actual}" ]]; then
        test_pass "${_message}"
    else
        test_fail "${_message}" "${_expected}" "${_actual}"
    fi
}

assert_contains() {
    local _haystack="$1"
    local _needle="$2"
    local _message="$3"

    if [[ "${_haystack}" == *"${_needle}"* ]]; then
        test_pass "${_message}"
    else
        test_fail "${_message}" "contains '${_needle}'" "${_haystack}"
    fi
}

assert_file_exists() {
    local _file="$1"
    local _message="$2"

    if [[ -f "${_file}" ]]; then
        test_pass "${_message}"
    else
        test_fail "${_message}" "file exists" "file not found: ${_file}"
    fi
}

assert_dir_exists() {
    local _dir="$1"
    local _message="$2"

    if [[ -d "${_dir}" ]]; then
        test_pass "${_message}"
    else
        test_fail "${_message}" "directory exists" "directory not found: ${_dir}"
    fi
}

assert_success() {
    local _command="$1"
    local _message="$2"

    if eval "${_command}" >/dev/null 2>&1; then
        test_pass "${_message}"
    else
        test_fail "${_message}" "command succeeds" "command failed: ${_command}"
    fi
}

assert_failure() {
    local _command="$1"
    local _message="$2"

    if ! eval "${_command}" >/dev/null 2>&1; then
        test_pass "${_message}"
    else
        test_fail "${_message}" "command fails" "command succeeded: ${_command}"
    fi
}

# ------------------------------
# Test Suite Runner
# ------------------------------

run_test_suite() {
    local _suite_file="$1"
    local _suite_name=$(basename "${_suite_file}" .zsh)

    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Test Suite: ${_suite_name}${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    echo ""

    source "${_suite_file}"
}

# ------------------------------
# Main Test Execution
# ------------------------------

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Remote Mount Script Test Suite           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Setup test environment
export XDG_CONFIG_HOME=/test/config
export XDG_CACHE_HOME=/test/cache
export XDG_RUNTIME_DIR=/test/runtime
export XDG_DATA_HOME=/test/data

# Create necessary directories
mkdir -p "${XDG_CONFIG_HOME}/remote"
mkdir -p "${XDG_CACHE_HOME}/remote"
mkdir -p "${XDG_RUNTIME_DIR}/remote"
mkdir -p "/test/pool/local"
mkdir -p "/test/pool/remote"

# Copy test configurations
cp /test/workspace/config/*.json "${XDG_CONFIG_HOME}/remote/" 2>/dev/null || true

# Run test suites in order
TEST_DIR="/test/tests"

if [[ -f "${TEST_DIR}/01-mount-unmount.zsh" ]]; then
    run_test_suite "${TEST_DIR}/01-mount-unmount.zsh"
fi

if [[ -f "${TEST_DIR}/02-mass-operations.zsh" ]]; then
    run_test_suite "${TEST_DIR}/02-mass-operations.zsh"
fi

if [[ -f "${TEST_DIR}/03-sync-filters.zsh" ]]; then
    run_test_suite "${TEST_DIR}/03-sync-filters.zsh"
fi

if [[ -f "${TEST_DIR}/04-verify-cleanup.zsh" ]]; then
    run_test_suite "${TEST_DIR}/04-verify-cleanup.zsh"
fi

if [[ -f "${TEST_DIR}/05-dry-run.zsh" ]]; then
    run_test_suite "${TEST_DIR}/05-dry-run.zsh"
fi

# ------------------------------
# Test Summary
# ------------------------------

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Test Summary${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""
echo "Total Tests:  ${TOTAL_TESTS}"
echo -e "${GREEN}Passed:       ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed:       ${FAILED_TESTS}${NC}"
echo ""

if [[ ${FAILED_TESTS} -gt 0 ]]; then
    echo -e "${RED}Failed Tests:${NC}"
    for test_name in "${FAILED_TEST_NAMES[@]}"; do
        echo -e "  ${RED}✗${NC} ${test_name}"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ALL TESTS PASSED! ✓               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    exit 0
fi
