# Liquibase Installer Testing Makefile

.PHONY: test test-quick test-full test-ubuntu test-debian test-rhel test-alpine test-arm64 clean help

# Default target
test: test-quick

# Quick test on popular distributions  
test-quick:
	@echo "Running quick test suite..."
	./run-tests.sh --quick --coordinator --clean

# Full test suite
test-full:
	@echo "Running full test suite..."
	./run-tests.sh --full --coordinator --clean

# Test specific OS families
test-ubuntu:
	@echo "Testing Ubuntu distributions..."
	./run-tests.sh ubuntu --coordinator --clean

test-debian:
	@echo "Testing Debian distributions..."
	./run-tests.sh debian --coordinator --clean

test-rhel:
	@echo "Testing RHEL-like distributions..."
	./run-tests.sh rhel --coordinator --clean

test-alpine:
	@echo "Testing Alpine distributions..."  
	./run-tests.sh alpine --coordinator --clean

# ARM64 architecture tests
test-arm64:
	@echo "Testing ARM64 architectures..."
	./run-tests.sh --arm64 --coordinator --clean

# Test installer functionality without containers
test-local:
	@echo "Testing installer locally..."
	./install.sh --help
	@echo "✅ Help command works"
	DRY_RUN=true ./install.sh latest oss > /dev/null
	@echo "✅ OSS dry run works"
	DRY_RUN=true ./install.sh 5.0.0 secure > /dev/null
	@echo "✅ Secure dry run works"
	@echo "🎉 Local tests passed!"

# Clean up containers
clean:
	@echo "Cleaning up test containers..."
	docker-compose -f docker-compose.test.yml down --remove-orphans || true
	docker system prune -f
	@echo "✅ Cleanup completed"

# Show test results from last run
results:
	@echo "Recent test container results:"
	@docker ps -a --filter "name=liquibase-test-" --format "table {{.Names}}\t{{.Status}}" || echo "No test containers found"

# Show help
help:
	@echo "Liquibase Installer Testing"
	@echo ""
	@echo "Available targets:"
	@echo "  test          Run quick test suite (default)"
	@echo "  test-quick    Test popular distributions (6 containers)"
	@echo "  test-full     Test all distributions (16+ containers)"
	@echo "  test-ubuntu   Test Ubuntu variants only"
	@echo "  test-debian   Test Debian variants only"
	@echo "  test-rhel     Test RHEL-like variants only" 
	@echo "  test-alpine   Test Alpine variants only"
	@echo "  test-arm64    Test ARM64 architectures"
	@echo "  test-local    Test installer locally without containers"
	@echo "  clean         Clean up test containers"
	@echo "  results       Show recent test results"
	@echo "  help          Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Quick test"
	@echo "  make test-full         # Comprehensive test"
	@echo "  make test-ubuntu       # Ubuntu only"
	@echo "  make clean             # Cleanup"