#!/usr/bin/env python3
import asyncio
import websockets
import json

async def test_detailed():
    print("🐍 Testing WebSocket connection with detailed logging...")
    
    try:
        print("📡 Attempting connection to ws://localhost:19765")
        
        # Try with explicit headers
        extra_headers = {
            "Sec-WebSocket-Version": "13",
            "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
        }
        
        websocket = await websockets.connect(
            'ws://localhost:19765',
            extra_headers=extra_headers,
            ping_interval=None,
            ping_timeout=None
        )
        
        print("✅ WebSocket handshake successful!")
        
        # Test communication
        ping_msg = {'type': 'ping', 'timestamp': '2025-08-21T23:22:00Z'}
        await websocket.send(json.dumps(ping_msg))
        print(f"📤 Sent: {ping_msg}")
        
        response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
        data = json.loads(response)
        print(f"📥 Received: {data}")
        
        await websocket.close()
        print("✅ Connection closed cleanly")
        return True
        
    except websockets.exceptions.InvalidHandshake as e:
        print(f"❌ Handshake failed: {e}")
        return False
    except websockets.exceptions.ConnectionClosed as e:
        print(f"❌ Connection closed: {e}")
        return False
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(test_detailed())
    print(f"Result: {'SUCCESS' if success else 'FAILED'}")
