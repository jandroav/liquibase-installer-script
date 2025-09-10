#!/bin/bash

# Liquibase Installer Test Runner
# Convenient script to run tests across all platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Liquibase Installer Test Runner

USAGE:
    ./run-tests.sh [OPTIONS] [TARGETS]

OPTIONS:
    --quick          Run tests on a subset of popular distributions
    --full           Run tests on all distributions (default)
    --arm64          Include ARM64 architecture tests
    --coordinator    Run with test coordinator for summary
    --clean          Clean up containers after tests
    --help           Show this help

TARGETS:
    ubuntu           Test Ubuntu variants only
    debian           Test Debian variants only
    rhel             Test RHEL-like variants only (CentOS, Rocky, Fedora)
    alpine           Test Alpine variants only
    all              Test all distributions (default)

EXAMPLES:
    # Quick test on popular distributions
    ./run-tests.sh --quick

    # Full test suite with cleanup
    ./run-tests.sh --full --clean

    # Test Ubuntu variants only
    ./run-tests.sh ubuntu

    # Test with ARM64 support
    ./run-tests.sh --arm64

    # Test with coordinator summary
    ./run-tests.sh --coordinator

EOF
}

# Parse arguments
QUICK=false
FULL=true
ARM64=false
COORDINATOR=false
CLEAN=false
TARGET="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK=true
            FULL=false
            shift
            ;;
        --full)
            FULL=true
            QUICK=false
            shift
            ;;
        --arm64)
            ARM64=true
            shift
            ;;
        --coordinator)
            COORDINATOR=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        ubuntu|debian|rhel|alpine|all)
            TARGET="$1"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is required but not installed"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker compose >/dev/null 2>&1; then
    log_error "Docker Compose is required but not installed"
    exit 1
fi

# Determine compose command
COMPOSE_CMD="docker-compose"
if command -v "docker compose" >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
fi

# Build service list based on options
SERVICES=()

if [ "$QUICK" = "true" ]; then
    log_info "Running quick test suite (popular distributions only)"
    SERVICES=(
        "ubuntu-22-04"
        "debian-12" 
        "rocky-9"
        "fedora-39"
        "alpine-3-19"
        "amazonlinux-2023"
    )
elif [ "$TARGET" != "all" ]; then
    case "$TARGET" in
        ubuntu)
            SERVICES=("ubuntu-20-04" "ubuntu-22-04" "ubuntu-24-04")
            ;;
        debian)
            SERVICES=("debian-11" "debian-12")
            ;;
        rhel)
            SERVICES=("centos-7" "rocky-8" "rocky-9" "fedora-38" "fedora-39")
            ;;
        alpine)
            SERVICES=("alpine-3-18" "alpine-3-19")
            ;;
    esac
    log_info "Running tests for $TARGET distributions only"
else
    log_info "Running full test suite (all distributions)"
    SERVICES=(
        "ubuntu-20-04" "ubuntu-22-04" "ubuntu-24-04"
        "debian-11" "debian-12"
        "centos-7" "rocky-8" "rocky-9"
        "fedora-38" "fedora-39"
        "alpine-3-18" "alpine-3-19"
        "amazonlinux-2" "amazonlinux-2023"
        "archlinux"
        "opensuse-leap"
    )
fi

# Add ARM64 services if requested
if [ "$ARM64" = "true" ]; then
    log_info "Including ARM64 architecture tests"
    SERVICES+=("ubuntu-22-04-arm64" "alpine-3-19-arm64")
    ARM64_PROFILE="--profile arm64"
else
    ARM64_PROFILE=""
fi

# Clean up any existing containers
log_info "Cleaning up any existing test containers..."
$COMPOSE_CMD -f docker-compose.test.yml down --remove-orphans > /dev/null 2>&1 || true

# Run tests
log_info "Starting tests on ${#SERVICES[@]} distributions..."
log_info "Services to test: ${SERVICES[*]}"

echo ""
echo "========================================"
echo "LIQUIBASE INSTALLER TEST EXECUTION"
echo "========================================"
echo "Date: $(date)"
echo "Target: $TARGET"
echo "Quick: $QUICK"
echo "ARM64: $ARM64"
echo "Coordinator: $COORDINATOR"
echo "Services: ${#SERVICES[@]} containers"
echo "========================================"
echo ""

# Start tests
if [ "$COORDINATOR" = "true" ]; then
    log_info "Running tests with coordinator..."
    $COMPOSE_CMD -f docker-compose.test.yml $ARM64_PROFILE --profile coordinator up --abort-on-container-exit "${SERVICES[@]}" test-coordinator
else
    log_info "Running tests without coordinator..."
    $COMPOSE_CMD -f docker-compose.test.yml $ARM64_PROFILE up --abort-on-container-exit "${SERVICES[@]}"
fi

test_result=$?

# Show results
echo ""
echo "========================================"
echo "TEST EXECUTION COMPLETED"
echo "========================================"

if [ $test_result -eq 0 ]; then
    log_success "All tests completed successfully!"
else
    log_error "Some tests failed (exit code: $test_result)"
fi

# Show individual container results
echo ""
log_info "Individual container results:"
for service in "${SERVICES[@]}"; do
    container_name="liquibase-test-${service}"
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        exit_code=$(docker inspect "$container_name" --format='{{.State.ExitCode}}' 2>/dev/null || echo "N/A")
        if [ "$exit_code" = "0" ]; then
            echo "  ✅ $service: PASSED"
        elif [ "$exit_code" = "N/A" ]; then
            echo "  ❓ $service: UNKNOWN"
        else
            echo "  ❌ $service: FAILED (exit code: $exit_code)"
        fi
    else
        echo "  ❓ $service: NOT FOUND"
    fi
done

# Cleanup if requested
if [ "$CLEAN" = "true" ]; then
    log_info "Cleaning up containers..."
    $COMPOSE_CMD -f docker-compose.test.yml down --remove-orphans > /dev/null 2>&1
    log_success "Cleanup completed"
fi

echo ""
if [ $test_result -eq 0 ]; then
    log_success "🎉 All tests passed! The installer works across all tested platforms."
else
    log_error "⚠️  Some tests failed. Check the logs above for details."
fi

exit $test_result