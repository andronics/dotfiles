#!/usr/bin/env bash

# Quick Start Script for Remote Mount Tests
# Checks dependencies and runs tests

set -e

echo "╔════════════════════════════════════════════╗"
echo "║  Remote Mount Script - Test Quick Start   ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon not running. Please start Docker."
    exit 1
fi

echo "✓ Docker is running"

# Check docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found. Please install docker-compose."
    exit 1
fi

echo "✓ docker-compose is installed"
echo ""

# Build container
echo "Building test container..."
docker-compose build

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  Running Tests                             ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Run tests
docker-compose up --abort-on-container-exit

# Capture exit code
TEST_EXIT_CODE=$?

# Cleanup
docker-compose down

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "╔════════════════════════════════════════════╗"
    echo "║          ALL TESTS PASSED! ✓               ║"
    echo "╚════════════════════════════════════════════╝"
else
    echo "╔════════════════════════════════════════════╗"
    echo "║          TESTS FAILED! ✗                   ║"
    echo "╚════════════════════════════════════════════╝"
fi

echo ""
echo "Next steps:"
echo "  - View README.md for detailed documentation"
echo "  - Run 'make test' to run tests again"
echo "  - Run 'make shell' for interactive testing"
echo "  - Run 'make help' to see all options"
echo ""

exit $TEST_EXIT_CODE
