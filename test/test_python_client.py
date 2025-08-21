#!/usr/bin/env python3
"""
Test script for Python WebSocket client
"""

import asyncio
import websockets
import json
import sys
import time
from src_py.websocket_client import BerlWebSocketClient

async def test_connection():
    """Test basic connection"""
    print("Testing connection...")
    client = BerlWebSocketClient()
    
    connected = await client.connect()
    if not connected:
        print("❌ Connection test failed")
        return False
        
    await client.disconnect()
    print("✅ Connection test passed")
    return True

async def test_message_exchange():
    """Test message exchange"""
    print("Testing message exchange...")
    client = BerlWebSocketClient()
    
    if not await client.connect():
        print("❌ Could not connect for message test")
        return False
    
    # Test messages
    test_messages = [
        {'type': 'ping', 'timestamp': '2025-01-01T00:00:00Z'},
        {'command': 'echo', 'data': 'test echo'},
        {'command': 'status', 'request_id': 'test_001'},
        {'type': 'greeting', 'message': 'Hello from test!'}
    ]
    
    responses = []
    
    # Start listening
    async def collect_responses():
        try:
            while len(responses) < len(test_messages):
                message = await asyncio.wait_for(client.websocket.recv(), timeout=5.0)
                responses.append(json.loads(message))
        except asyncio.TimeoutError:
            pass
        except Exception as e:
            print(f"Error collecting responses: {e}")
    
    listen_task = asyncio.create_task(collect_responses())
    
    # Send test messages
    for message in test_messages:
        await client.send_message(message)
        await asyncio.sleep(0.1)
    
    # Wait for responses
    await asyncio.sleep(2)
    listen_task.cancel()
    
    await client.disconnect()
    
    if len(responses) == len(test_messages):
        print(f"✅ Message exchange test passed ({len(responses)} responses)")
        return True
    else:
        print(f"❌ Message exchange test failed ({len(responses)}/{len(test_messages)} responses)")
        return False

async def test_json_handling():
    """Test JSON message handling"""
    print("Testing JSON handling...")
    client = BerlWebSocketClient()
    
    if not await client.connect():
        print("❌ Could not connect for JSON test")
        return False
    
    # Test complex JSON
    complex_message = {
        'type': 'json_test',
        'data': {
            'nested': True,
            'array': [1, 2, 3],
            'string': 'test string',
            'number': 42.5,
            'boolean': False
        }
    }
    
    response_received = False
    
    async def wait_for_response():
        nonlocal response_received
        try:
            message = await asyncio.wait_for(client.websocket.recv(), timeout=5.0)
            data = json.loads(message)
            if data.get('type') == 'json_test_response':
                response_received = True
                print(f"Received JSON response: {data}")
        except Exception as e:
            print(f"Error waiting for JSON response: {e}")
    
    listen_task = asyncio.create_task(wait_for_response())
    await client.send_message(complex_message)
    await asyncio.sleep(1)
    listen_task.cancel()
    
    await client.disconnect()
    
    if response_received:
        print("✅ JSON handling test passed")
        return True
    else:
        print("❌ JSON handling test failed")
        return False

async def run_all_tests():
    """Run all tests"""
    print("🧪 Running Python WebSocket Client Tests")
    print("=" * 50)
    
    tests = [
        ("Connection Test", test_connection),
        ("Message Exchange Test", test_message_exchange),
        ("JSON Handling Test", test_json_handling)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n📋 {test_name}")
        try:
            result = await test_func()
            if result:
                passed += 1
        except Exception as e:
            print(f"❌ {test_name} failed with exception: {e}")
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed!")
        return True
    else:
        print("💥 Some tests failed!")
        return False

if __name__ == "__main__":
    try:
        success = asyncio.run(run_all_tests())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n🛑 Tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n💥 Test suite failed: {e}")
        sys.exit(1)
