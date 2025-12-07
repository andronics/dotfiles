.PHONY: help build test run clean shell

help:
	@echo "Remote Mount Script - Test Suite"
	@echo ""
	@echo "Available targets:"
	@echo "  make build   - Build Docker test environment"
	@echo "  make test    - Run all tests"
	@echo "  make run     - Run specific test (TEST=01)"
	@echo "  make shell   - Start interactive shell"
	@echo "  make clean   - Remove containers and volumes"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make run TEST=01"
	@echo "  make shell"

build:
	@echo "Building Docker test environment..."
	docker-compose build

test: build
	@echo "Running all tests..."
	docker-compose up --abort-on-container-exit
	docker-compose down

run: build
	@echo "Running test suite $(TEST)..."
	docker-compose run --rm remote-test zsh /test/tests/$(TEST)-*.zsh

shell: build
	@echo "Starting interactive shell..."
	docker-compose run --rm remote-test zsh

clean:
	@echo "Cleaning up Docker resources..."
	docker-compose down -v
	rm -rf cache runtime config/*.json pool

rebuild:
	@echo "Rebuilding from scratch..."
	docker-compose build --no-cache

logs:
	docker-compose logs -f

# Quick test specific suites
test-mount:
	@make run TEST=01

test-mass:
	@make run TEST=02

test-filters:
	@make run TEST=03

test-verify:
	@make run TEST=04

test-dryrun:
	@make run TEST=05
