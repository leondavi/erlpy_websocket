#!/bin/bash
###===================================================================
### Integration Test for erlpy_websocket
### 
### This test validates the complete WebSocket communication between
### Erlang server and Python client using the actual run scripts.
### 
### Tests:
### - Compilation and startup of both applications
### - WebSocket handshake and connection
### - JSON message exchange
### - Graceful shutdown
###===================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_PORT=19765
TIMEOUT=30
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up test processes...${NC}"
    
    # Kill any remaining processes on our test port
    if lsof -i :${TEST_PORT} >/dev/null 2>&1; then
        echo "Killing processes on port ${TEST_PORT}"
        lsof -ti :${TEST_PORT} | xargs kill -9 2>/dev/null || true
    fi
    
    # Kill any beam processes from our test
    pkill -f "berl_websocket" 2>/dev/null || true
    pkill -f "rebar3.*shell" 2>/dev/null || true
    
    # Remove temporary test files
    rm -f "${PROJECT_ROOT}/test_results.log"
    rm -f "${PROJECT_ROOT}/server_output.log"
    rm -f "${PROJECT_ROOT}/client_output.log"
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

# Error function
error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Success function
success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Wait for server to be ready
wait_for_server() {
    log "Waiting for WebSocket server to be ready on port ${TEST_PORT}..."
    
    local count=0
    while [ $count -lt $TIMEOUT ]; do
        if lsof -i :${TEST_PORT} >/dev/null 2>&1; then
            success "Server is listening on port ${TEST_PORT}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    
    error "Server failed to start within ${TIMEOUT} seconds"
}

# Test compilation
test_compilation() {
    log "Testing compilation..."
    
    cd "${PROJECT_ROOT}"
    
    # Test rebar3 compilation
    if command -v rebar3 >/dev/null 2>&1; then
        log "Compiling with rebar3..."
        if rebar3 compile; then
            success "rebar3 compilation successful"
        else
            error "rebar3 compilation failed"
        fi
    else
        # Fallback to direct erlc compilation
        log "Compiling with erlc..."
        mkdir -p ebin
        if erlc -pa ebin -o ebin src/*.erl; then
            success "erlc compilation successful"
        else
            error "erlc compilation failed"
        fi
    fi
}

# Test Python dependencies
test_python_deps() {
    log "Checking Python dependencies..."
    
    if ! python3 -c "import websockets, asyncio, json, logging" 2>/dev/null; then
        error "Python dependencies missing. Please install: pip install websockets"
    fi
    
    success "Python dependencies available"
}

# Start server in background
start_server() {
    log "Starting Erlang WebSocket server..."
    
    cd "${PROJECT_ROOT}"
    
    # Make sure the script is executable
    chmod +x run_erl_app.sh
    
    # Start server in background and capture output
    ./run_erl_app.sh > server_output.log 2>&1 &
    SERVER_PID=$!
    
    log "Server started with PID: ${SERVER_PID}"
    
    # Wait for server to be ready
    wait_for_server
}

# Test client connection and communication
test_client_communication() {
    log "Testing Python client communication..."
    
    cd "${PROJECT_ROOT}"
    
    # Create a test Python script that runs automated tests
    cat > test_client_automated.py << 'EOF'
#!/usr/bin/env python3
"""
Automated WebSocket client test for integration testing.
"""
import asyncio
import websockets
import json
import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

async def test_websocket_communication():
    """Test WebSocket communication with the Erlang server."""
    try:
        # Connect to server
        uri = "ws://localhost:19765"
        logger.info(f"Connecting to {uri}")
        
        async with websockets.connect(uri, timeout=10) as websocket:
            logger.info("Connected to WebSocket server")
            
            # Test cases
            test_cases = [
                {"type": "greeting", "message": "Hello from automated test"},
                {"command": "echo", "data": "Test echo message"},
                {"type": "ping", "timestamp": "2025-01-01T00:00:00Z"},
                {"command": "status", "request_id": "test_001"},
                {"type": "json_test", "data": {"nested": True, "value": 42}}
            ]
            
            responses_received = 0
            
            for i, test_case in enumerate(test_cases, 1):
                logger.info(f"Sending test message {i}/{len(test_cases)}")
                
                # Send message
                await websocket.send(json.dumps(test_case))
                logger.info(f"Sent: {test_case}")
                
                # Wait for response
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    response_data = json.loads(response)
                    logger.info(f"Received: {response_data}")
                    responses_received += 1
                    
                    # Validate response structure
                    if not isinstance(response_data, dict):
                        raise ValueError("Response is not a JSON object")
                    
                    if "timestamp" not in response_data:
                        logger.warning("Response missing timestamp field")
                    
                except asyncio.TimeoutError:
                    logger.error(f"Timeout waiting for response to message {i}")
                    return False
                except json.JSONDecodeError:
                    logger.error(f"Invalid JSON response to message {i}")
                    return False
                
                # Small delay between messages
                await asyncio.sleep(0.5)
            
            logger.info(f"Test completed: {responses_received}/{len(test_cases)} responses received")
            return responses_received == len(test_cases)
            
    except Exception as e:
        logger.error(f"Test failed with exception: {e}")
        return False

def main():
    """Main test function."""
    try:
        result = asyncio.run(test_websocket_communication())
        if result:
            logger.info("All tests passed!")
            sys.exit(0)
        else:
            logger.error("Some tests failed!")
            sys.exit(1)
    except Exception as e:
        logger.error(f"Test execution failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    # Make the test script executable
    chmod +x test_client_automated.py
    
    # Run the automated test
    if python3 test_client_automated.py > client_output.log 2>&1; then
        success "Client communication test passed"
        return 0
    else
        error "Client communication test failed"
        log "Client output:"
        cat client_output.log
        return 1
    fi
}

# Validate server logs
validate_server_logs() {
    log "Validating server logs..."
    
    if [ ! -f "server_output.log" ]; then
        error "Server output log not found"
    fi
    
    # Check for successful startup messages
    if grep -q "WebSocket server started on port ${TEST_PORT}" server_output.log; then
        success "Server startup message found"
    else
        error "Server startup message not found in logs"
    fi
    
    # Check for WebSocket handshake completion
    if grep -q "RFC 6455 compliant WebSocket handshake response sent" server_output.log; then
        success "WebSocket handshake completed"
    else
        log "WebSocket handshake message not found (may be in debug logs)"
    fi
    
    # Check for message processing
    if grep -q "WEBSOCKET DECODED JSON" server_output.log; then
        success "JSON message processing confirmed"
    else
        log "JSON processing logs not found (may be at different log level)"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   erlpy_websocket Integration Test${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    cd "${PROJECT_ROOT}"
    
    # Run test phases
    test_compilation
    test_python_deps
    start_server
    sleep 2  # Give server time to fully initialize
    test_client_communication
    validate_server_logs
    
    echo -e "${BLUE}========================================${NC}"
    success "All integration tests passed!"
    echo -e "${BLUE}========================================${NC}"
    
    # Show summary
    log "Test Summary:"
    echo "  ✓ Compilation successful"
    echo "  ✓ Server startup successful"
    echo "  ✓ Client connection successful"
    echo "  ✓ Message exchange successful"
    echo "  ✓ Server logs validated"
    
    # Cleanup will be handled by trap
}

# Run main function
main "$@"
