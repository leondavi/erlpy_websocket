#!/bin/bash
# Integration test script for erlpy_websocket

set -e

echo "🧪 erlpy_websocket Integration Test Suite"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_PORT=19999
SERVER_PID=""

# Cleanup function
cleanup() {
    echo -e "\n🧹 Cleaning up..."
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
    # Kill any remaining processes on test port
    lsof -ti:$TEST_PORT | xargs kill -9 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command_exists erl; then
    echo -e "${RED}❌ Erlang not found. Please install Erlang/OTP${NC}"
    exit 1
fi

if ! command_exists python3; then
    echo -e "${RED}❌ Python 3 not found. Please install Python 3${NC}"
    exit 1
fi

if ! python3 -c "import websockets" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Installing websockets dependency...${NC}"
    pip3 install websockets
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Test 1: Compile Erlang code
echo -e "\n📦 Test 1: Compiling Erlang code..."
if command_exists rebar3; then
    rebar3 compile
    echo -e "${GREEN}✅ rebar3 compile successful${NC}"
else
    echo -e "${YELLOW}⚠️  rebar3 not found, using erlc...${NC}"
    mkdir -p ebin
    erlc -pa ebin -o ebin src/*.erl
    echo -e "${GREEN}✅ erlc compile successful${NC}"
fi

# Test 2: Run Erlang unit tests
echo -e "\n🧪 Test 2: Running Erlang unit tests..."
if command_exists rebar3; then
    if rebar3 eunit --verbose; then
        echo -e "${GREEN}✅ Erlang unit tests passed${NC}"
    else
        echo -e "${RED}❌ Erlang unit tests failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Skipping Erlang unit tests (rebar3 not available)${NC}"
fi

# Test 3: Start WebSocket server
echo -e "\n🚀 Test 3: Starting WebSocket server on port $TEST_PORT..."

# Start server in background
if command_exists rebar3; then
    erl -pa _build/default/lib/*/ebin -eval "
        application:ensure_all_started(jsx),
        {ok, Pid} = berl_websocket_server:start_link($TEST_PORT),
        io:format('Server started with PID: ~p~n', [Pid]),
        receive stop -> ok end.
    " -noshell &
else
    erl -pa ebin -eval "
        application:ensure_all_started(jsx),
        {ok, Pid} = berl_websocket_server:start_link($TEST_PORT),
        io:format('Server started with PID: ~p~n', [Pid]),
        receive stop -> ok end.
    " -noshell &
fi

SERVER_PID=$!
echo "Server PID: $SERVER_PID"

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 3

# Check if server is still running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${RED}❌ Server failed to start${NC}"
    exit 1
fi

# Check if port is open
if ! lsof -i:$TEST_PORT >/dev/null 2>&1; then
    echo -e "${RED}❌ Server not listening on port $TEST_PORT${NC}"
    exit 1
fi

echo -e "${GREEN}✅ WebSocket server started successfully${NC}"

# Test 4: Python client connection test
echo -e "\n🐍 Test 4: Testing Python client connection..."

python3 -c "
import asyncio
import websockets
import json
import sys

async def test_connection():
    try:
        uri = f'ws://localhost:$TEST_PORT'
        print(f'Connecting to {uri}...')
        
        async with websockets.connect(uri) as websocket:
            print('✅ Connected successfully')
            
            # Send test message
            test_msg = {'type': 'ping', 'timestamp': '2025-01-01T00:00:00Z'}
            await websocket.send(json.dumps(test_msg))
            print('📤 Sent ping message')
            
            # Wait for response
            response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
            data = json.loads(response)
            print(f'📥 Received: {data}')
            
            if data.get('type') == 'pong':
                print('✅ Ping-pong test successful')
                return True
            else:
                print('❌ Unexpected response')
                return False
                
    except Exception as e:
        print(f'❌ Connection test failed: {e}')
        return False

success = asyncio.run(test_connection())
sys.exit(0 if success else 1)
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Python client connection test passed${NC}"
else
    echo -e "${RED}❌ Python client connection test failed${NC}"
    exit 1
fi

# Test 5: Message exchange test
echo -e "\n💬 Test 5: Testing message exchange..."

python3 -c "
import asyncio
import websockets
import json
import sys

async def test_messages():
    try:
        uri = f'ws://localhost:$TEST_PORT'
        
        async with websockets.connect(uri) as websocket:
            # Test different message types
            test_cases = [
                {'type': 'ping', 'timestamp': '2025-01-01T00:00:00Z'},
                {'command': 'echo', 'data': 'test message'},
                {'command': 'status', 'request_id': 'test_001'},
                {'type': 'greeting', 'message': 'Hello from integration test!'}
            ]
            
            responses = []
            
            # Send all test messages
            for i, test_msg in enumerate(test_cases):
                await websocket.send(json.dumps(test_msg))
                print(f'📤 Sent test message {i+1}: {test_msg[\"type\" if \"type\" in test_msg else \"command\"]}')
                
                # Wait for response
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=3.0)
                    data = json.loads(response)
                    responses.append(data)
                    print(f'📥 Received response {i+1}: {data.get(\"type\", \"unknown\")}')
                except asyncio.TimeoutError:
                    print(f'⏰ Timeout waiting for response {i+1}')
            
            if len(responses) == len(test_cases):
                print(f'✅ All {len(responses)} messages exchanged successfully')
                return True
            else:
                print(f'❌ Only {len(responses)}/{len(test_cases)} messages succeeded')
                return False
                
    except Exception as e:
        print(f'❌ Message exchange test failed: {e}')
        return False

success = asyncio.run(test_messages())
sys.exit(0 if success else 1)
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Message exchange test passed${NC}"
else
    echo -e "${RED}❌ Message exchange test failed${NC}"
    exit 1
fi

# Test summary
echo -e "\n🎉 Integration Test Summary"
echo "=========================="
echo -e "${GREEN}✅ All integration tests passed!${NC}"
echo ""
echo "The erlpy_websocket system is working correctly:"
echo "• Erlang WebSocket server starts and listens"
echo "• Python client can connect successfully"
echo "• Bidirectional message exchange works"
echo "• JSON message handling is functional"
echo ""
echo "Ready for production use! 🚀"
