#!/usr/bin/env python3
"""
Simple Python WebSocket client example
"""

import asyncio
import websockets
import json

async def simple_client():
    uri = "ws://localhost:19765"
    
    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to WebSocket server")
            
            # Send a simple message
            message = {
                "type": "greeting",
                "message": "Hello from simple client!"
            }
            
            await websocket.send(json.dumps(message))
            print(f"📤 Sent: {message}")
            
            # Wait for response
            response = await websocket.recv()
            data = json.loads(response)
            print(f"📥 Received: {data}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(simple_client())
