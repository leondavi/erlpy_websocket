#!/usr/bin/env python3
"""
Simple WebSocket test to verify Erlang server communication
"""

import asyncio
import websockets
import json
import sys

async def test_websocket_simple():
    """Simple WebSocket connection and message test"""
    try:
        print("🔗 Connecting to ws://localhost:19765...")
        async with websockets.connect("ws://localhost:19765") as websocket:
            print("✅ Connected successfully!")
            
            # Test 1: Send ping
            ping_msg = {"type": "ping", "timestamp": "2025-08-21T23:26:00Z"}
            await websocket.send(json.dumps(ping_msg))
            print(f"📤 Sent: {ping_msg}")
            
            # Wait for response
            response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
            data = json.loads(response)
            print(f"📥 Received: {data}")
            
            if data.get("type") == "pong":
                print("✅ Ping-pong test PASSED")
                return True
            else:
                print("❌ Unexpected response")
                return False
                
    except websockets.exceptions.ConnectionRefused:
        print("❌ Connection refused - server not running?")
        return False
    except asyncio.TimeoutError:
        print("❌ Timeout waiting for response")
        return False
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Simple WebSocket Test")
    print("========================")
    success = asyncio.run(test_websocket_simple())
    print("========================")
    if success:
        print("🎉 Test PASSED")
        sys.exit(0)
    else:
        print("💥 Test FAILED")
        sys.exit(1)
