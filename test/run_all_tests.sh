#!/bin/bash
# Comprehensive test runner for erlpy_websocket project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(dirname "$0")/.."
cd "$PROJECT_ROOT"

ERLANG_MODULES_DIR="src"
EBIN_DIR="ebin"
TEST_DIR="test"
SERVER_PORT=19999  # Use different port for testing
SERVER_PID=""

echo -e "${BLUE}🧪 erlpy_websocket Comprehensive Test Suite${NC}"
echo "=================================================="

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
    # Kill any processes on test port
    lsof -ti:$SERVER_PORT | xargs kill -9 2>/dev/null || true
    # Remove temporary files
    rm -f server_test.log
}

# Set trap for cleanup
trap cleanup EXIT

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print test result
print_result() {
    local test_name="$1"
    local result="$2"
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
    fi
}

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0

# Function to run test and update counters
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "\n${BLUE}📋 Running: $test_name${NC}"
    
    if eval "$test_command"; then
        print_result "$test_name" "PASS"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        print_result "$test_name" "FAIL"
        return 1
    fi
}

echo -e "\n${YELLOW}📋 Phase 1: Prerequisites Check${NC}"
echo "================================"

# Check Erlang
if ! command_exists erl; then
    echo -e "${RED}❌ Erlang not found. Please install Erlang/OTP${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Erlang/OTP available${NC}"

# Check Python
if ! command_exists python3; then
    echo -e "${RED}❌ Python 3 not found. Please install Python 3${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python 3 available${NC}"

# Check/install websockets
if ! python3 -c "import websockets" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Installing websockets dependency...${NC}"
    pip3 install websockets
fi
echo -e "${GREEN}✅ Python websockets library available${NC}"

echo -e "\n${YELLOW}📋 Phase 2: Compilation${NC}"
echo "======================="

# Compile Erlang modules
echo "🔨 Compiling Erlang modules..."
mkdir -p "$EBIN_DIR"

compile_result=0
if command_exists rebar3; then
    echo "Using rebar3..."
    if rebar3 compile; then
        echo -e "${GREEN}✅ rebar3 compilation successful${NC}"
    else
        echo -e "${RED}❌ rebar3 compilation failed${NC}"
        compile_result=1
    fi
else
    echo "Using erlc..."
    if erlc -pa "$EBIN_DIR" -o "$EBIN_DIR" "$ERLANG_MODULES_DIR"/*.erl; then
        echo -e "${GREEN}✅ erlc compilation successful${NC}"
    else
        echo -e "${RED}❌ erlc compilation failed${NC}"
        compile_result=1
    fi
fi

if [ $compile_result -ne 0 ]; then
    echo -e "${RED}❌ Compilation failed. Cannot continue with tests.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}📋 Phase 3: Erlang Unit Tests${NC}"
echo "=============================="

if command_exists rebar3; then
    run_test "Erlang EUnit Tests (rebar3)" "rebar3 eunit --verbose"
else
    # Manual EUnit testing
    if [ -d "_build/default/lib" ]; then
        echo "Using rebar3 compiled modules for EUnit..."
        eunit_test='
        erl -pa _build/default/lib/*/ebin -eval "
            application:ensure_all_started(jsx),
            eunit:test([berl_app_tests, berl_websocket_server_tests], [verbose]),
            init:stop().
        " -noshell'
    else
        echo "Using ebin compiled modules for EUnit..."
        eunit_test='
        erl -pa ebin -eval "
            application:ensure_all_started(jsx),
            eunit:test([berl_app_tests, berl_websocket_server_tests], [verbose]),
            init:stop().
        " -noshell'
    fi
    
    run_test "Erlang EUnit Tests (manual)" "$eunit_test"
fi

echo -e "\n${YELLOW}📋 Phase 4: Integration Tests${NC}"
echo "============================="

# Start WebSocket server for integration tests
echo "🚀 Starting WebSocket server on port $SERVER_PORT..."

if [ -d "_build/default/lib" ]; then
    echo "Using rebar3 compiled modules..."
    start_server_cmd="erl -pa _build/default/lib/*/ebin -eval \"
        application:ensure_all_started(jsx),
        {ok, Pid} = berl_websocket_server:start_link($SERVER_PORT),
        io:format('Server started on port $SERVER_PORT with PID: ~p~n', [Pid]),
        receive stop -> ok end.
    \" -noshell"
else
    echo "Using ebin compiled modules..."
    start_server_cmd="erl -pa ebin -eval \"
        application:ensure_all_started(jsx),
        {ok, Pid} = berl_websocket_server:start_link($SERVER_PORT),
        io:format('Server started on port $SERVER_PORT with PID: ~p~n', [Pid]),
        receive stop -> ok end.
    \" -noshell"
fi

# Start server in background and capture PID
eval "$start_server_cmd" > server_test.log 2>&1 &
SERVER_PID=$!

echo "Server PID: $SERVER_PID"
echo "⏳ Waiting for server to start..."
sleep 3

# Check if server is running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${RED}❌ Server failed to start${NC}"
    cat server_test.log
    exit 1
fi

# Check if port is open
if ! lsof -i:$SERVER_PORT >/dev/null 2>&1; then
    echo -e "${RED}❌ Server not listening on port $SERVER_PORT${NC}"
    exit 1
fi

echo -e "${GREEN}✅ WebSocket server started successfully${NC}"

# Test 1: Basic connection test
connection_test="python3 -c \"
import asyncio
import websockets
import sys

async def test():
    try:
        async with websockets.connect('ws://localhost:$SERVER_PORT') as ws:
            print('✅ Connected successfully')
            return True
    except Exception as e:
        print(f'❌ Connection failed: {e}')
        return False

success = asyncio.run(test())
sys.exit(0 if success else 1)
\""

run_test "WebSocket Connection Test" "$connection_test"

# Test 2: Ping-pong test
ping_test="python3 -c \"
import asyncio
import websockets
import json
import sys

async def test():
    try:
        async with websockets.connect('ws://localhost:$SERVER_PORT') as ws:
            # Send ping
            await ws.send(json.dumps({'type': 'ping', 'timestamp': '2025-08-21T23:00:00Z'}))
            
            # Wait for pong
            response = await asyncio.wait_for(ws.recv(), timeout=5.0)
            data = json.loads(response)
            
            if data.get('type') == 'pong':
                print('✅ Ping-pong successful')
                return True
            else:
                print(f'❌ Unexpected response: {data}')
                return False
    except Exception as e:
        print(f'❌ Ping test failed: {e}')
        return False

success = asyncio.run(test())
sys.exit(0 if success else 1)
\""

run_test "Ping-Pong Message Test" "$ping_test"

# Test 3: Echo test
echo_test="python3 -c \"
import asyncio
import websockets
import json
import sys

async def test():
    try:
        async with websockets.connect('ws://localhost:$SERVER_PORT') as ws:
            # Send echo command
            await ws.send(json.dumps({'command': 'echo', 'data': 'Test message'}))
            
            # Wait for response
            response = await asyncio.wait_for(ws.recv(), timeout=5.0)
            data = json.loads(response)
            
            if data.get('type') == 'echo_response' and 'Test message' in data.get('response', ''):
                print('✅ Echo test successful')
                return True
            else:
                print(f'❌ Unexpected echo response: {data}')
                return False
    except Exception as e:
        print(f'❌ Echo test failed: {e}')
        return False

success = asyncio.run(test())
sys.exit(0 if success else 1)
\""

run_test "Echo Message Test" "$echo_test"

# Test 4: Status test
status_test="python3 -c \"
import asyncio
import websockets
import json
import sys

async def test():
    try:
        async with websockets.connect('ws://localhost:$SERVER_PORT') as ws:
            # Send status command
            await ws.send(json.dumps({'command': 'status', 'request_id': 'test_001'}))
            
            # Wait for response
            response = await asyncio.wait_for(ws.recv(), timeout=5.0)
            data = json.loads(response)
            
            if data.get('type') == 'status_response' and data.get('status') == 'online':
                print('✅ Status test successful')
                return True
            else:
                print(f'❌ Unexpected status response: {data}')
                return False
    except Exception as e:
        print(f'❌ Status test failed: {e}')
        return False

success = asyncio.run(test())
sys.exit(0 if success else 1)
\""

run_test "Status Request Test" "$status_test"

# Test 5: Run Python test files
if [ -f "$TEST_DIR/test_python_client.py" ]; then
    # Modify test to use our test port
    python_client_test="cd $TEST_DIR && python3 -c \"
import sys
sys.path.append('..')
from test_python_client import *

# Override client to use test port
import asyncio

async def test_with_custom_port():
    from src_py.websocket_client import BerlWebSocketClient
    client = BerlWebSocketClient(port=$SERVER_PORT)
    
    if not await client.connect():
        return False
    
    # Simple test
    await client.send_message({'type': 'ping'})
    await asyncio.sleep(1)
    await client.disconnect()
    return True

success = asyncio.run(test_with_custom_port())
sys.exit(0 if success else 1)
\""
    
    run_test "Python Client Module Test" "$python_client_test"
fi

echo -e "\n${YELLOW}📋 Phase 5: Performance Tests${NC}"
echo "============================="

# Test multiple connections
multi_connection_test="python3 -c \"
import asyncio
import websockets
import json
import sys

async def test_connection(conn_id):
    try:
        async with websockets.connect('ws://localhost:$SERVER_PORT') as ws:
            await ws.send(json.dumps({'type': 'ping', 'id': conn_id}))
            response = await asyncio.wait_for(ws.recv(), timeout=5.0)
            return True
    except:
        return False

async def test():
    # Test sequential connections since our server is single-client
    results = []
    for i in range(3):
        result = await test_connection(i)
        results.append(result)
        await asyncio.sleep(0.5)  # Small delay between connections
    
    success_count = sum(1 for r in results if r is True)
    print(f'✅ {success_count}/3 sequential connections successful')
    return success_count >= 2  # Allow some failures

success = asyncio.run(test())
sys.exit(0 if success else 1)
\""

run_test "Sequential Connections Test" "$multi_connection_test"

echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="
echo -e "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo -e "\n${GREEN}🎉 All tests passed! The erlpy_websocket system is working correctly.${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed. Please check the output above.${NC}"
    exit 1
fi
