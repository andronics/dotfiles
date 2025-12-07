# Remote Mount Script - Test Suite

Docker-based test environment for the remote mount script using real tools (rclone, systemd, mediainfo).

## Quick Start

```bash
cd /home/andronics/.dotfiles/remote/.local/test

# Build and run tests
docker-compose up --build

# Or run interactively
docker-compose run --rm remote-test zsh
```

## Test Structure

```
.local/test/
├── Dockerfile              # Arch Linux container with real tools
├── docker-compose.yml      # Container orchestration
├── README.md              # This file
├── config/                # Test configurations
│   ├── credentials.json   # Test Google Drive credentials
│   ├── units.json         # Test unit definitions
│   ├── roots.json         # Mount point roots
│   ├── filters2.json      # File filter rules
│   └── sandbox.json       # Sandbox mode config
├── fixtures/              # Sample media files for testing
│   └── README.md          # Instructions for creating test media
└── tests/                 # Test suites
    ├── run-tests.zsh      # Main test runner
    ├── 01-mount-unmount.zsh    # Basic operations
    ├── 02-mass-operations.zsh  # Bulk operations
    ├── 03-sync-filters.zsh     # Filter logic
    ├── 04-verify-cleanup.zsh   # Operational commands
    └── 05-dry-run.zsh          # Sandbox mode
```

## Test Suites

### 01 - Mount & Unmount
- Pattern matching (glob, comma-separated, wildcards)
- Unit configuration validation
- Directory creation
- Query helpers
- Dry-run behavior

### 02 - Mass Operations
- `mount-all`, `unmount-all`, `enable-all`, `disable-all`, `restart-all`
- Pattern filtering
- Bulk operation counting
- Error handling for non-existent patterns

### 03 - Sync & Filters
- Filter operators: eq, ne, lt, le, gt, ge, in
- Filename pattern matching (regex)
- Media property extraction (mimetype, audio/video metadata)
- Sync preview mode
- File filtering logic

### 04 - Verify & Cleanup
- Configuration verification
- Credential validation
- Mount status detection
- Stale config cleanup
- Empty cache removal
- Force cleanup mode

### 05 - Dry-Run & Sandbox
- Global `--dry-run` flag
- Prevention of destructive operations
- Sandbox command wrapper
- Read-only operations in dry-run
- Multiple operation isolation

## Test Framework

Simple zsh-based test framework with assertions:

- `test_start "description"` - Begin a test
- `test_pass "message"` - Mark test passed
- `test_fail "message" "expected" "actual"` - Mark test failed
- `assert_equals expected actual message` - Assert equality
- `assert_contains haystack needle message` - Assert substring
- `assert_file_exists path message` - Assert file exists
- `assert_dir_exists path message` - Assert directory exists
- `assert_success command message` - Assert command succeeds
- `assert_failure command message` - Assert command fails

## Running Tests

### Run All Tests
```bash
docker-compose up --build
```

### Run Specific Test Suite
```bash
docker-compose run --rm remote-test zsh -c "source /test/tests/01-mount-unmount.zsh"
```

### Interactive Mode
```bash
docker-compose run --rm remote-test zsh

# Inside container:
source /test/bin/remote
_remote list "*"
_remote --dry-run mount-all "test-*"
```

### Rebuild Container
```bash
docker-compose build --no-cache
```

## Test Configuration

### Test Units
- `test-unit-a`, `test-unit-b`, `test-unit-c` - Basic test units
- `media-test` - For sync/filter testing
- `invalid-unit` - For error testing (bad credentials)

### Test Credentials
- `test@example.com` - Test account with mock tokens
- **Note**: For real rclone tests, replace with actual test account credentials

### Test Filters
- `.mp3` files - Audio format and bitrate checks
- `.mp4` files - Video resolution checks
- `.jpg` files - Image mimetype checks
- `test-*.txt` files - Text file pattern matching

## Expected Results

When all tests pass:
```
╔════════════════════════════════════════════╗
║          ALL TESTS PASSED! ✓               ║
╚════════════════════════════════════════════╝

Total Tests:  100+
Passed:       100+
Failed:       0
```

## Extending Tests

To add new tests:

1. Create new test file: `tests/06-new-feature.zsh`
2. Use test framework functions
3. Source the remote script: `source /test/bin/remote`
4. Update `run-tests.zsh` to include new suite

Example:
```zsh
#!/usr/bin/env zsh

source /test/bin/remote

test_start "My new feature test"
_result=$(/test/bin/remote new-command)
assert_contains "${_result}" "expected output" "Feature works"
```

## Troubleshooting

### Container won't build
- Check Docker is running
- Try: `docker-compose build --no-cache`

### Tests fail with "command not found"
- Ensure helper scripts are executable
- Check PATH includes `/test/bin`

### FUSE errors
- Container needs `--privileged` flag
- Check device `/dev/fuse` is accessible

### Permission issues
- All operations run as `testuser` (UID 1000)
- Check volume mount permissions

## CI/CD Integration

Add to CI pipeline:
```yaml
test:
  script:
    - cd .local/test
    - docker-compose up --build --exit-code-from remote-test
```

Exit codes:
- `0` - All tests passed
- `1` - One or more tests failed

## Notes

- Tests use dry-run mode for most operations (no actual mounts)
- For real mount testing, configure valid rclone backend
- Helper scripts (`_log`, `_jq`, etc.) are minimal stubs
- Systemd integration tests require privileged container
- Filter tests need mediainfo for property extraction
