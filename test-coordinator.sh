#!/bin/sh

# Test Coordinator Script
# Coordinates and reports on all test container results

echo "========================================"
echo "LIQUIBASE INSTALLER TEST COORDINATOR"
echo "========================================"
echo "Date: $(date)"
echo ""

# Install required tools
apk add --no-cache docker-cli > /dev/null 2>&1

# Wait for all containers to complete
echo "Waiting for all test containers to complete..."
sleep 30

# Collect results from all containers
echo ""
echo "COLLECTING RESULTS FROM ALL CONTAINERS:"
echo "========================================"

containers=$(docker ps -a --filter "name=liquibase-test-" --format "{{.Names}}")

total_containers=0
passed_containers=0
failed_containers=0

for container in $containers; do
    if [ "$container" != "liquibase-test-coordinator" ]; then
        total_containers=$((total_containers + 1))
        
        echo ""
        echo "--- Results from $container ---"
        
        # Get container exit code
        exit_code=$(docker inspect "$container" --format='{{.State.ExitCode}}')
        
        if [ "$exit_code" = "0" ]; then
            echo "✅ PASSED"
            passed_containers=$((passed_containers + 1))
        else
            echo "❌ FAILED (Exit code: $exit_code)"
            failed_containers=$((failed_containers + 1))
            
            # Show container logs for failed tests
            echo "Error logs:"
            docker logs "$container" 2>&1 | tail -20
        fi
    fi
done

echo ""
echo "========================================"
echo "FINAL SUMMARY"
echo "========================================"
echo "Total Containers: $total_containers"
echo "Passed: $passed_containers"
echo "Failed: $failed_containers"

if [ $failed_containers -eq 0 ]; then
    echo ""
    echo "🎉 ALL TESTS PASSED ACROSS ALL PLATFORMS!"
    echo "The Liquibase installer works correctly on all tested operating systems."
    exit 0
else
    echo ""
    echo "⚠️  SOME TESTS FAILED"
    echo "Check the logs above for details on failed containers."
    exit 1
fi