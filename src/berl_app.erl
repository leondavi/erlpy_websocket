%%%===================================================================
%%% @doc
%%% BERL Application Command Handler
%%% 
%%% Simple command handler for demonstration purposes.
%%% In a real application, this would be replaced with your actual
%%% business logic.
%%% @end
%%%===================================================================

-module(berl_app).

%% API
-export([handle_command/1]).

%%====================================================================
%% API
%%====================================================================

%% @doc Handle incoming commands from WebSocket clients
-spec handle_command(map()) -> map().
handle_command(Command) when is_map(Command) ->
    try
        handle_command_type(Command)
    catch
        Error:Reason ->
            logger:error("Error handling command ~p: ~p:~p", [Command, Error, Reason]),
            #{
                error => <<"command_error">>,
                details => list_to_binary(io_lib:format("~p:~p", [Error, Reason])),
                original_command => Command
            }
    end;
handle_command(Command) ->
    logger:warning("Invalid command format: ~p", [Command]),
    #{
        error => <<"invalid_command_format">>,
        details => <<"Command must be a JSON object">>,
        received => Command
    }.

%%====================================================================
%% Internal functions
%%====================================================================

%% @doc Handle different types of commands
handle_command_type(#{<<"type">> := <<"ping">>} = Command) ->
    Timestamp = maps:get(<<"timestamp">>, Command, get_timestamp()),
    #{
        type => <<"pong">>,
        timestamp => Timestamp,
        server_time => get_timestamp()
    };

handle_command_type(#{<<"command">> := <<"echo">>, <<"data">> := Data} = _Command) ->
    #{
        type => <<"echo_response">>,
        original => Data,
        response => <<"Echo: ", Data/binary>>,
        timestamp => get_timestamp()
    };

handle_command_type(#{<<"command">> := <<"status">>} = Command) ->
    RequestId = maps:get(<<"request_id">>, Command, <<"unknown">>),
    #{
        type => <<"status_response">>,
        request_id => RequestId,
        status => <<"online">>,
        server => <<"berl_websocket_server">>,
        version => <<"1.0.0">>,
        timestamp => get_timestamp(),
        uptime_seconds => get_uptime_seconds()
    };

handle_command_type(#{<<"type">> := <<"greeting">>} = Command) ->
    Message = maps:get(<<"message">>, Command, <<"Hello!">>),
    #{
        type => <<"greeting_response">>,
        message => <<"Hello from Erlang WebSocket server!">>,
        received => Message,
        timestamp => get_timestamp()
    };

handle_command_type(#{<<"type">> := <<"json_test">>} = Command) ->
    Data = maps:get(<<"data">>, Command, #{}),
    #{
        type => <<"json_test_response">>,
        received_data => Data,
        processed => true,
        server_data => #{
            random_number => rand:uniform(1000),
            server_pid => list_to_binary(pid_to_list(self())),
            node_name => atom_to_binary(node(), utf8)
        },
        timestamp => get_timestamp()
    };

handle_command_type(#{<<"type">> := <<"text">>} = Command) ->
    Message = maps:get(<<"message">>, Command, <<"No message">>),
    #{
        type => <<"text_response">>,
        received => Message,
        response => <<"Received your message: ", Message/binary>>,
        timestamp => get_timestamp()
    };

handle_command_type(Command) ->
    logger:info("Unknown command type: ~p", [Command]),
    #{
        type => <<"unknown_command_response">>,
        message => <<"Unknown command type">>,
        received_command => Command,
        available_commands => [
            <<"ping">>, <<"echo">>, <<"status">>, <<"greeting">>, <<"json_test">>, <<"text">>
        ],
        timestamp => get_timestamp()
    }.

%% @doc Get current timestamp in ISO 8601 format
get_timestamp() ->
    list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))).

%% @doc Get system uptime in seconds (simplified)
get_uptime_seconds() ->
    {UpTime, _} = erlang:statistics(wall_clock),
    UpTime div 1000.
