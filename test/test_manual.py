#!/usr/bin/env python3
"""
Manual test to debug the integration test.
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
        
        async with websockets.connect(uri) as websocket:
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
