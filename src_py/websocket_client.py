#!/usr/bin/env python3
"""
Python WebSocket Client for BERL WebSocket Server

This client connects to the Erlang WebSocket server and demonstrates
bidirectional communication with JSON message exchange.
"""

import asyncio
import websockets
import json
import logging
import sys

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class BerlWebSocketClient:
    def __init__(self, host='localhost', port=19765):
        self.host = host
        self.port = port
        self.websocket = None
        self.running = False
        
    async def connect(self):
        """Connect to the WebSocket server"""
        uri = f"ws://{self.host}:{self.port}"
        logger.info(f"Connecting to {uri}")
        
        try:
            self.websocket = await websockets.connect(uri)
            self.running = True
            logger.info("✅ Connected to WebSocket server")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to connect: {e}")
            return False
            
    async def disconnect(self):
        """Disconnect from the WebSocket server"""
        if self.websocket:
            self.running = False
            await self.websocket.close()
            logger.info("Disconnected from WebSocket server")
            
    async def send_message(self, message):
        """Send a message to the server"""
        if not self.websocket:
            logger.error("Not connected to server")
            return
            
        try:
            if isinstance(message, dict):
                message_str = json.dumps(message)
            else:
                message_str = str(message)
                
            await self.websocket.send(message_str)
            logger.info(f"📤 Sent: {message}")
        except Exception as e:
            logger.error(f"❌ Failed to send message: {e}")
            
    async def listen_for_messages(self):
        """Listen for incoming messages from the server"""
        try:
            while self.running and self.websocket:
                message = await self.websocket.recv()
                logger.info(f"📥 Received: {message}")
                
                try:
                    # Try to parse as JSON
                    data = json.loads(message)
                    await self.handle_message(data)
                except json.JSONDecodeError:
                    # Handle as plain text
                    await self.handle_message(message)
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("Connection closed by server")
        except Exception as e:
            logger.error(f"❌ Error listening for messages: {e}")
            
    async def handle_message(self, message):
        """Handle incoming messages from the server"""
        logger.info(f"Processing message: {message}")
        
        # Example: Echo back with timestamp
        if isinstance(message, dict):
            if message.get('type') == 'ping':
                await self.send_message({
                    'type': 'pong',
                    'timestamp': message.get('timestamp')
                })
            elif message.get('command') == 'echo':
                await self.send_message({
                    'type': 'echo_response',
                    'original': message.get('data'),
                    'response': f"Echo: {message.get('data')}"
                })
                
    async def send_test_messages(self):
        """Send a series of test messages"""
        test_messages = [
            {'type': 'greeting', 'message': 'Hello from Python client!'},
            {'command': 'echo', 'data': 'Test echo message'},
            {'type': 'ping', 'timestamp': '2025-01-01T00:00:00Z'},
            {'command': 'status', 'request_id': 'test_001'},
            {'type': 'json_test', 'data': {'nested': True, 'value': 42}},
        ]
        
        for i, message in enumerate(test_messages):
            logger.info(f"Sending test message {i+1}/{len(test_messages)}")
            await self.send_message(message)
            await asyncio.sleep(1)  # Wait 1 second between messages
            
    async def interactive_mode(self):
        """Interactive mode for manual message sending"""
        logger.info("Interactive mode started. Type messages (JSON format) or 'quit' to exit:")
        
        while self.running:
            try:
                user_input = await asyncio.get_event_loop().run_in_executor(
                    None, input, "Enter message: "
                )
                
                if user_input.lower() in ['quit', 'exit', 'q']:
                    break
                    
                try:
                    # Try to parse as JSON
                    message = json.loads(user_input)
                except json.JSONDecodeError:
                    # Send as plain text message
                    message = {'type': 'text', 'message': user_input}
                    
                await self.send_message(message)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Error in interactive mode: {e}")
                
    async def run_demo(self):
        """Run the demo client"""
        if not await self.connect():
            return
            
        try:
            # Start listening for messages in the background
            listen_task = asyncio.create_task(self.listen_for_messages())
            
            # Send test messages
            logger.info("Sending test messages...")
            await self.send_test_messages()
            
            # Wait a bit for responses
            await asyncio.sleep(2)
            
            # Start interactive mode
            await self.interactive_mode()
            
        finally:
            await self.disconnect()
            listen_task.cancel()

async def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='BERL WebSocket Client')
    parser.add_argument('--host', default='localhost', help='Server host (default: localhost)')
    parser.add_argument('--port', type=int, default=19765, help='Server port (default: 19765)')
    parser.add_argument('--mode', choices=['demo', 'test', 'interactive'], default='demo',
                       help='Client mode (default: demo)')
    
    args = parser.parse_args()
    
    client = BerlWebSocketClient(args.host, args.port)
    
    if args.mode == 'demo':
        await client.run_demo()
    elif args.mode == 'test':
        if await client.connect():
            listen_task = asyncio.create_task(client.listen_for_messages())
            await client.send_test_messages()
            await asyncio.sleep(3)
            await client.disconnect()
            listen_task.cancel()
    elif args.mode == 'interactive':
        if await client.connect():
            listen_task = asyncio.create_task(client.listen_for_messages())
            await client.interactive_mode()
            await client.disconnect()
            listen_task.cancel()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Client stopped by user")
    except Exception as e:
        logger.error(f"Client error: {e}")
        sys.exit(1)
