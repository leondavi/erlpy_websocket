# Quick Start Example

This directory contains simple examples to get you started with erlpy_websocket.

## Files

- `simple_client.py` - Basic Python WebSocket client
- `simple_server_example.erl` - Erlang server usage examples

## Quick Demo

1. **Start the server**:
   ```bash
   cd /path/to/erlpy_websocket
   ./run_erl_app.sh
   ```

2. **In another terminal, run the simple client**:
   ```bash
   python3 examples/simple_client.py
   ```

## Expected Output

**Server output:**
```
🚀 Starting BERL WebSocket Server...
🔨 Compiling modules...
✅ WebSocket server started on port 19765 (PID: <0.123.0>)
🔗 Connect from Python client or browser to ws://localhost:19765
```

**Client output:**
```
✅ Connected to WebSocket server
📤 Sent: {'type': 'greeting', 'message': 'Hello from simple client!'}
📥 Received: {'type': 'greeting_response', 'message': 'Hello from Erlang WebSocket server!', 'received': 'Hello from simple client!', 'timestamp': '2025-08-21T23:14:00Z'}
```

## Customization

To create your own message handlers, modify the `berl_app:handle_command/1` function in `src/berl_app.erl` or replace it entirely with your business logic.

For more complex examples, see the main Python client in `src_py/websocket_client.py`.
