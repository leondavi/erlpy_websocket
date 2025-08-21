# Makefile for erlpy_websocket project

.PHONY: all compile test clean deps shell server client help

# Default target
all: deps compile

# Install dependencies
deps:
	@echo "📦 Installing dependencies..."
	rebar3 get-deps
	pip3 install -r requirements.txt

# Compile Erlang code
compile:
	@echo "🔨 Compiling Erlang code..."
	rebar3 compile

# Run tests
test: compile
	@echo "🧪 Running Erlang tests..."
	rebar3 eunit
	@echo "🐍 Running Python tests..."
	@echo "Note: Start Erlang server first with 'make server' in another terminal"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	rebar3 clean
	rm -rf _build
	find . -name "*.beam" -delete
	find . -name "*.pyc" -delete
	rm -rf __pycache__

# Start Erlang shell with application loaded
shell: compile
	@echo "🐚 Starting Erlang shell..."
	rebar3 shell

# Start WebSocket server
server: compile
	@echo "🚀 Starting WebSocket server..."
	./run_erl_app.sh

# Start Python client
client:
	@echo "🐍 Starting Python client..."
	./run_py_app.sh

# Show help
help:
	@echo "erlpy_websocket Makefile Commands:"
	@echo ""
	@echo "  make deps     - Install dependencies (rebar3 + pip)"
	@echo "  make compile  - Compile Erlang code"
	@echo "  make test     - Run test suites"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make shell    - Start Erlang shell with app loaded"
	@echo "  make server   - Start WebSocket server"
	@echo "  make client   - Start Python client"
	@echo "  make all      - Install deps and compile (default)"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make deps"
	@echo "  2. make server  (in one terminal)"
	@echo "  3. make client  (in another terminal)"
