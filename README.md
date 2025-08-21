# erlpy_websocket

A comprehensive WebSocket communication system demonstrating bidirectional data exchange between an Erlang server and Python client. The Erlang WebSocket server is RFC 6455 compliant and designed for easy integration into existing Erlang projects using rebar3.

## 🏗️ Architecture

```
┌─────────────────┐    WebSocket    ┌─────────────────┐
│   Python Client │ ◄──────────────► │  Erlang Server  │
│                 │    (RFC 6455)   │                 │
│ - websockets    │                 │ - gen_server    │
│ - JSON messages │                 │ - Frame masking │
│ - Async I/O     │                 │ - JSON handling │
└─────────────────┘                 └─────────────────┘
```

## 📁 Project Structure

```
erlpy_websocket/
├── README.md                    # This file
├── rebar.config                 # rebar3 configuration
├── run_erl_app.sh              # Erlang server startup script
├── run_py_app.sh               # Python client startup script
├── src/                        # rebar3 standard source directory
│   ├── berl_websocket.app.src  # Erlang application metadata
│   ├── berl_websocket_server.erl # Main WebSocket server
│   └── berl_app.erl            # Command handler (demo)
├── src_erl/                    # Original Erlang source (backup)
├── src_py/                     # Python source
│   └── websocket_client.py     # Python WebSocket client
└── test/                       # Test suites
    ├── berl_websocket_server_tests.erl  # Erlang server tests
    ├── berl_app_tests.erl              # Command handler tests
    └── test_python_client.py           # Python client tests
```

## 🚀 Quick Start

### Prerequisites

- **Erlang/OTP 24+** with `jsx` dependency
- **Python 3.7+** with `websockets` library
- **rebar3** (optional, for proper Erlang development)

### 1. Start the Erlang WebSocket Server

```bash
./run_erl_app.sh
```

The server will start on `localhost:19765` by default.

### 2. Start the Python Client

In a new terminal:

```bash
./run_py_app.sh
```

This will run the client in demo mode with test messages and interactive input.

## 🎮 Usage Modes

### Python Client Modes

```bash
# Demo mode (default) - sends test messages then goes interactive
./run_py_app.sh

# Test mode only - sends test messages and exits
./run_py_app.sh --mode test

# Interactive mode only
./run_py_app.sh --mode interactive

# Custom host/port
./run_py_app.sh --host 192.168.1.100 --port 8080
```

### Erlang Server

```erlang
% Start programmatically
{ok, Pid} = berl_websocket_server:start_link().     % Default port 19765
{ok, Pid} = berl_websocket_server:start_link(8080). % Custom port

% Send messages to connected clients
berl_websocket_server:send_message(19765, #{type => <<"notification">>, 
                                           message => <<"Hello!">>}).

% Stop server
berl_websocket_server:stop(19765).
```

## 📨 Message Protocol

### Supported Message Types

#### 1. Ping/Pong
```json
// Client -> Server
{"type": "ping", "timestamp": "2025-01-01T00:00:00Z"}

// Server -> Client
{"type": "pong", "timestamp": "2025-01-01T00:00:00Z", "server_time": "2025-01-01T00:00:01Z"}
```

#### 2. Echo
```json
// Client -> Server
{"command": "echo", "data": "Hello World"}

// Server -> Client
{"type": "echo_response", "original": "Hello World", "response": "Echo: Hello World"}
```

#### 3. Status
```json
// Client -> Server
{"command": "status", "request_id": "req_001"}

// Server -> Client
{
  "type": "status_response",
  "request_id": "req_001",
  "status": "online",
  "server": "berl_websocket_server",
  "version": "1.0.0",
  "uptime_seconds": 3600
}
```

#### 4. Greeting
```json
// Client -> Server
{"type": "greeting", "message": "Hello from Python!"}

// Server -> Client
{"type": "greeting_response", "message": "Hello from Erlang WebSocket server!", "received": "Hello from Python!"}
```

## 🧪 Testing

### Run Erlang Tests

```bash
cd /path/to/erlpy_websocket
rebar3 eunit
```

### Run Python Tests

```bash
# Start Erlang server first
./run_erl_app.sh

# In another terminal, run Python tests
python3 test/test_python_client.py
```

### Manual Testing

1. Start the server: `./run_erl_app.sh`
2. In another terminal: `./run_py_app.sh --mode interactive`
3. Type JSON messages like: `{"type": "ping", "timestamp": "2025-01-01T00:00:00Z"}`

## 🔧 Integration with rebar3 Projects

To integrate the WebSocket server into your existing Erlang project:

### Method 1: Copy Source Files

1. Copy `src/berl_websocket_server.erl` to your project's `src/` directory
2. Copy `src/berl_app.erl` or replace with your own command handler
3. Add to your `rebar.config`:
   ```erlang
   {deps, [
       {jsx, "3.1.0"}  % For JSON handling
   ]}.
   ```
4. Add modules to your `.app.src`:
   ```erlang
   {modules, [berl_websocket_server, your_app, ...]},
   {applications, [kernel, stdlib, jsx, ...]},
   ```

### Method 2: Git Dependency

Add to your `rebar.config`:
```erlang
{deps, [
    {berl_websocket, {git, "https://github.com/yourusername/erlpy_websocket.git", {branch, "main"}}}
]}.
```

### Method 3: Use as Library

1. Clone this repository
2. Run `rebar3 compile` to build
3. Add to your Erlang code path: `erl -pa /path/to/erlpy_websocket/_build/default/lib/*/ebin`

## ⚙️ Configuration

### Erlang Server Configuration

```erlang
% Custom port
{ok, Pid} = berl_websocket_server:start_link(8080).

% Multiple servers
{ok, Pid1} = berl_websocket_server:start_link(8080).
{ok, Pid2} = berl_websocket_server:start_link(8081).
```

### Python Client Configuration

```python
from src_py.websocket_client import BerlWebSocketClient

# Custom configuration
client = BerlWebSocketClient(host='192.168.1.100', port=8080)
await client.connect()
```

## 🔒 Security Features

- **RFC 6455 Compliance**: Full WebSocket standard implementation
- **Frame Masking**: Proper client-to-server frame masking validation
- **Input Validation**: JSON schema validation and error handling
- **Connection Management**: Graceful connection handling and cleanup

## 📊 Performance Characteristics

- **Single Client per Port**: Each server instance handles one client
- **Non-blocking I/O**: Asynchronous message handling
- **JSON Processing**: Efficient binary JSON encoding/decoding
- **Memory Efficient**: Minimal memory footprint per connection

## 🐛 Troubleshooting

### Common Issues

1. **Port already in use**
   ```bash
   # Check what's using the port
   lsof -i :19765
   
   # Use a different port
   ./run_erl_app.sh
   ./run_py_app.sh --port 8080
   ```

2. **JSX dependency missing**
   ```bash
   rebar3 deps
   rebar3 compile
   ```

3. **Python websockets not installed**
   ```bash
   pip3 install websockets
   ```

4. **Connection refused**
   - Ensure Erlang server is running
   - Check firewall settings
   - Verify port number matches

### Debug Mode

Enable detailed logging in Erlang:
```erlang
logger:set_primary_config(level, debug).
```

## 📝 License

MIT License - see individual source files for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📚 References

- [RFC 6455 - The WebSocket Protocol](https://tools.ietf.org/html/rfc6455)
- [Erlang gen_server Behavior](https://erlang.org/doc/man/gen_server.html)
- [Python websockets Library](https://websockets.readthedocs.io/)
- [rebar3 Documentation](https://rebar3.org/docs/)

---

*Built with ❤️ using Erlang/OTP and Python*
