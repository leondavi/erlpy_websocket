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
{ok, Pid} = websocket_server:start_link().     % Default port 19765
{ok, Pid} = websocket_server:start_link(8080). % Custom port

% Send messages to connected clients
berl_websocket_server:send_message(19765, #{type => <<"notification">>, 
                                           message => <<"Hello!">>}).

% Stop server
websocket_server:stop(19765).
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


### Debug Mode

Enable detailed logging in Erlang:
```erlang
logger:set_primary_config(level, debug).
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Citation

If you use this software in academic research or publications, please cite:

```
Leon, David. "erlpy_websocket: RFC 6455 compliant WebSocket server for Erlang/Python communication." 2025. GitHub repository: https://github.com/leondavi/erlpy_websocket
```

BibTeX:
```bibtex
@misc{leon2025erlpy,
  title={erlpy\_websocket: RFC 6455 compliant WebSocket server for Erlang/Python communication},
  author={Leon, David},
  year={2025},
  publisher={GitHub},
  url={https://github.com/leondavi/erlpy_websocket}
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Add tests for new functionality
4. Ensure all tests pass (`rebar3 eunit` and `python -m pytest`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📚 References

- [RFC 6455 - The WebSocket Protocol](https://tools.ietf.org/html/rfc6455)
- [Erlang gen_server Behavior](https://erlang.org/doc/man/gen_server.html)
- [Python websockets Library](https://websockets.readthedocs.io/)
- [rebar3 Documentation](https://rebar3.org/docs/)

---
