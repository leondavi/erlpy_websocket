#!/usr/bin/env python3
import asyncio
import websockets
import json

async def test_ping():
    print("🐍 Testing WebSocket ping...")
    try:
        async with websockets.connect('ws://localhost:19765') as websocket:
            print("✅ Connected to WebSocket server")
            
            # Send ping
            ping_msg = {'type': 'ping', 'timestamp': '2025-08-21T23:22:00Z'}
            await websocket.send(json.dumps(ping_msg))
            print(f"📤 Sent: {ping_msg}")
            
            # Receive response
            response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
            data = json.loads(response)
            print(f"📥 Received: {data}")
            
            if data.get('type') == 'pong':
                print("✅ Ping-pong test PASSED")
                return True
            else:
                print("❌ Unexpected response")
                return False
                
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(test_ping())
    print(f"Result: {'SUCCESS' if success else 'FAILED'}")
