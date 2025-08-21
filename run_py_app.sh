#!/bin/bash
# Run the Python WebSocket client

cd "$(dirname "$0")"

echo "Starting Python WebSocket Client..."

# Check if websockets is installed
if ! python3 -c "import websockets" &> /dev/null; then
    echo "Installing websockets dependency..."
    pip3 install websockets
fi

# Run the client
echo "Connecting to Erlang WebSocket server..."
python3 src_py/websocket_client.py "$@"
