#!/bin/bash
# Run the Erlang WebSocket server

cd "$(dirname "$0")"

echo "Starting BERL WebSocket Server..."

# Ensure modules are compiled
mkdir -p ebin
echo "Compiling modules..."
erlc -pa ebin -o ebin src/*.erl

# Check if rebar3 is available
if command -v rebar3 &> /dev/null; then
    echo "Using rebar3 to run..."
    rebar3 shell --eval "
        {ok, Pid} = berl_websocket_server:start_link(),
        io:format('~nWebSocket server started on port 19765 (PID: ~p)~n', [Pid]),
        io:format('Connect from Python client or browser to ws://localhost:19765~n'),
        io:format('Press Ctrl+C twice to stop~n~n').
    " --config none
else
    echo "Using direct Erlang..."
    # Start with compiled modules
    erl -pa ebin -eval "
        application:ensure_all_started(jsx),
        {ok, Pid} = berl_websocket_server:start_link(),
        io:format('~nWebSocket server started on port 19765 (PID: ~p)~n', [Pid]),
        io:format('Connect from Python client or browser to ws://localhost:19765~n'),
        io:format('Press Ctrl+C twice to stop~n~n'),
        receive stop -> ok end.
    " -noshell
fi
