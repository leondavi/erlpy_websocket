#!/bin/bash
# Main test runner wrapper that calls the test suite from the test directory

echo "🧪 Running erlpy_websocket Test Suite"
echo "====================================="

# Change to the test directory and run the comprehensive test suite
cd "$(dirname "$0")/test" && ./run_all_tests.sh "$@"
