%% Simple Erlang WebSocket server usage example

-module(simple_server_example).
-export([start_demo/0, custom_command_handler/1]).

%% Start a demo WebSocket server
start_demo() ->
    % Start the WebSocket server on default port
    {ok, Pid} = berl_websocket_server:start_link(),
    
    io:format("🚀 WebSocket server started on port 19765~n"),
    io:format("Server PID: ~p~n", [Pid]),
    io:format("Connect with Python client to test~n"),
    
    % Keep the server running
    receive
        stop -> 
            berl_websocket_server:stop(19765),
            io:format("Server stopped~n")
    end.

%% Example custom command handler
%% Replace berl_app:handle_command/1 with this for custom logic
custom_command_handler(#{<<"command">> := <<"custom">>, <<"data">> := Data}) ->
    % Handle custom command
    ProcessedData = process_custom_data(Data),
    #{
        type => <<"custom_response">>,
        result => ProcessedData,
        timestamp => get_timestamp()
    };

custom_command_handler(Command) ->
    % Fallback to default handler
    berl_app:handle_command(Command).

%% Helper functions
process_custom_data(Data) ->
    % Your custom business logic here
    <<"Processed: ", Data/binary>>.

get_timestamp() ->
    list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))).
