#!/bin/bash

# Liquibase Installer Test Runner
# Runs comprehensive tests on different operating systems

set -e

TEST_OS="${TEST_OS:-unknown}"
SCRIPT_PATH="/test/install.sh"
TEST_RESULTS_FILE="/test/results.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
}

# Install required dependencies for testing
install_dependencies() {
    log_info "Installing dependencies for $TEST_OS..."
    
    case "$TEST_OS" in
        ubuntu-*|debian-*)
            apt-get update -y > /dev/null 2>&1
            apt-get install -y curl wget tar gzip ca-certificates > /dev/null 2>&1
            # Try to install jq if available
            apt-get install -y jq > /dev/null 2>&1 || log_warn "jq not available"
            ;;
        centos-7)
            yum update -y > /dev/null 2>&1
            yum install -y curl wget tar gzip ca-certificates > /dev/null 2>&1
            # Try to install jq if available
            yum install -y epel-release > /dev/null 2>&1 || true
            yum install -y jq > /dev/null 2>&1 || log_warn "jq not available"
            ;;
        rocky-*|fedora-*)
            if command -v dnf >/dev/null 2>&1; then
                dnf update -y > /dev/null 2>&1
                dnf install -y curl wget tar gzip ca-certificates > /dev/null 2>&1
                dnf install -y jq > /dev/null 2>&1 || log_warn "jq not available"
            else
                yum update -y > /dev/null 2>&1
                yum install -y curl wget tar gzip ca-certificates > /dev/null 2>&1
                yum install -y jq > /dev/null 2>&1 || log_warn "jq not available"
            fi
            ;;
        alpine-*)
            apk update > /dev/null 2>&1
            apk add --no-cache curl wget tar gzip ca-certificates bash > /dev/null 2>&1
            apk add --no-cache jq > /dev/null 2>&1 || log_warn "jq not available"
            ;;
        amazonlinux-*)
            yum update -y > /dev/null 2>&1
            yum install -y curl wget tar gzip ca-certificates > /dev/null 2>&1
            yum install -y jq > /dev/null 2>&1 || log_warn "jq not available"
            ;;
        archlinux)
            pacman -Sy --noconfirm > /dev/null 2>&1
            pacman -S --noconfirm curl wget tar gzip ca-certificates > /dev/null 2>&1
            pacman -S --noconfirm jq > /dev/null 2>&1 || log_warn "jq not available"
            ;;
        opensuse-*)
            zypper refresh > /dev/null 2>&1
            zypper install -y curl wget tar gzip ca-certificates > /dev/null 2>&1
            zypper install -y jq > /dev/null 2>&1 || log_warn "jq not available"
            ;;
        *)
            log_warn "Unknown OS: $TEST_OS, attempting generic setup"
            ;;
    esac
}

# Test basic script functionality
test_help() {
    log_info "Testing --help functionality..."
    
    if bash "$SCRIPT_PATH" --help > /dev/null 2>&1; then
        log_success "Help command works"
        return 0
    else
        log_error "Help command failed"
        return 1
    fi
}

# Test platform detection
test_platform_detection() {
    log_info "Testing platform detection..."
    
    if DRY_RUN=true VERBOSE=true bash "$SCRIPT_PATH" 2>&1 | grep -q "Detecting platform and architecture"; then
        log_success "Platform detection works"
        return 0
    else
        log_error "Platform detection failed"
        return 1
    fi
}

# Test OSS version detection
test_oss_version_detection() {
    log_info "Testing OSS latest version detection..."
    
    if DRY_RUN=true bash "$SCRIPT_PATH" latest oss > /dev/null 2>&1; then
        log_success "OSS version detection works"
        return 0
    else
        log_error "OSS version detection failed"
        return 1
    fi
}

# Test Secure version handling
test_secure_version_handling() {
    log_info "Testing Secure version handling..."
    
    # Test 4.33.0 secure (should use pro URL)
    local output
    output=$(DRY_RUN=true VERBOSE=true bash "$SCRIPT_PATH" 4.33.0 secure 2>&1)
    
    if echo "$output" | grep -q "repo.liquibase.com/releases/pro/4.33.0/liquibase-pro-4.33.0.tar.gz"; then
        log_success "Pro version URL (4.33.0) correct"
    else
        log_error "Pro version URL (4.33.0) incorrect"
        echo "$output" | grep "Download URL" || echo "No Download URL found"
        return 1
    fi
    
    # Test 5.0.0 secure (should use secure URL)
    output=$(DRY_RUN=true VERBOSE=true bash "$SCRIPT_PATH" 5.0.0 secure 2>&1)
    
    if echo "$output" | grep -q "repo.liquibase.com/releases/secure/5.0.0/liquibase-secure-5.0.0.tar.gz"; then
        log_success "Secure version URL (5.0.0) correct"
        return 0
    else
        log_error "Secure version URL (5.0.0) incorrect"
        echo "$output" | grep "Download URL" || echo "No Download URL found"
        return 1
    fi
}

# Test error handling
test_error_handling() {
    log_info "Testing error handling..."
    
    local failed=0
    
    # Test invalid version format
    if bash "$SCRIPT_PATH" invalid.version 2>&1 | grep -q "Unknown argument"; then
        log_success "Invalid version handling works"
    else
        log_error "Invalid version handling failed"
        failed=1
    fi
    
    # Test invalid edition
    if bash "$SCRIPT_PATH" 4.33.0 invalid 2>&1 | grep -q "Unknown argument"; then
        log_success "Invalid edition handling works"
    else
        log_error "Invalid edition handling failed"
        failed=1
    fi
    
    return $failed
}

# Test actual installation (OSS only to avoid auth issues)
test_actual_installation() {
    log_info "Testing actual OSS installation..."
    
    # Only test if we have sufficient space and permissions
    if [ ! -w "/usr/local" ] && [ ! -w "$HOME" ]; then
        log_warn "No write permissions for installation test, skipping"
        return 0
    fi
    
    # Install latest OSS
    if bash "$SCRIPT_PATH" latest oss > /dev/null 2>&1; then
        log_success "OSS installation completed"
        
        # Test if liquibase command works
        if command -v liquibase >/dev/null 2>&1; then
            local version_output
            version_output=$(liquibase --version 2>&1 | head -1 || echo "Version check failed")
            log_success "Liquibase installed and working: $version_output"
            return 0
        else
            log_error "Liquibase installed but command not available in PATH"
            return 1
        fi
    else
        log_error "OSS installation failed"
        return 1
    fi
}

# Test dependency detection
test_dependency_detection() {
    log_info "Testing dependency detection..."
    
    local output
    output=$(DRY_RUN=true VERBOSE=true bash "$SCRIPT_PATH" 2>&1)
    
    local failed=0
    
    if echo "$output" | grep -q "Found curl\|Found wget"; then
        log_success "Download tool detection works"
    else
        log_error "Download tool detection failed"
        failed=1
    fi
    
    if echo "$output" | grep -q "Found jq\|jq not found"; then
        log_success "jq detection works"
    else
        log_error "jq detection failed"
        failed=1
    fi
    
    return $failed
}

# Run all tests
run_tests() {
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo "=========================================" | tee "$TEST_RESULTS_FILE"
    echo "LIQUIBASE INSTALLER TEST SUITE" | tee -a "$TEST_RESULTS_FILE"
    echo "OS: $TEST_OS" | tee -a "$TEST_RESULTS_FILE"
    echo "Date: $(date)" | tee -a "$TEST_RESULTS_FILE"
    echo "=========================================" | tee -a "$TEST_RESULTS_FILE"
    
    # System information
    log_info "System Information:"
    log_info "  OS: $(uname -s)"
    log_info "  Architecture: $(uname -m)"
    log_info "  Kernel: $(uname -r)"
    
    # Install dependencies first
    install_dependencies
    
    # Test suite
    local tests=(
        "test_help"
        "test_dependency_detection" 
        "test_platform_detection"
        "test_oss_version_detection"
        "test_secure_version_handling"
        "test_error_handling"
        "test_actual_installation"
    )
    
    for test in "${tests[@]}"; do
        total_tests=$((total_tests + 1))
        log_info "Running $test..."
        
        if $test; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
        
        echo "" >> "$TEST_RESULTS_FILE"
    done
    
    # Summary
    echo "=========================================" | tee -a "$TEST_RESULTS_FILE"
    echo "TEST SUMMARY FOR $TEST_OS" | tee -a "$TEST_RESULTS_FILE"
    echo "=========================================" | tee -a "$TEST_RESULTS_FILE"
    echo "Total Tests: $total_tests" | tee -a "$TEST_RESULTS_FILE"
    echo "Passed: $passed_tests" | tee -a "$TEST_RESULTS_FILE"
    echo "Failed: $failed_tests" | tee -a "$TEST_RESULTS_FILE"
    
    if [ $failed_tests -eq 0 ]; then
        log_success "ALL TESTS PASSED for $TEST_OS!"
        echo "RESULT: PASS" | tee -a "$TEST_RESULTS_FILE"
        exit 0
    else
        log_error "SOME TESTS FAILED for $TEST_OS"
        echo "RESULT: FAIL" | tee -a "$TEST_RESULTS_FILE"
        exit 1
    fi
}

# Ensure script is executable
chmod +x "$SCRIPT_PATH"

# Run the test suite
run_tests