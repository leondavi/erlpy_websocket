%%%===================================================================
%%% @doc
%%% EUnit tests for berl_app command handler
%%% @end
%%%===================================================================

-module(berl_app_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test descriptions
%%====================================================================

berl_app_test_() ->
    [
        {"Handle ping command", fun test_ping_command/0},
        {"Handle echo command", fun test_echo_command/0},
        {"Handle status command", fun test_status_command/0},
        {"Handle greeting command", fun test_greeting_command/0},
        {"Handle unknown command", fun test_unknown_command/0},
        {"Handle invalid command format", fun test_invalid_command/0}
    ].

%%====================================================================
%% Tests
%%====================================================================

test_ping_command() ->
    Command = #{<<"type">> => <<"ping">>, <<"timestamp">> => <<"2025-01-01T00:00:00Z">>},
    Response = berl_app:handle_command(Command),
    
    ?assertEqual(<<"pong">>, maps:get(type, Response)),
    ?assertEqual(<<"2025-01-01T00:00:00Z">>, maps:get(timestamp, Response)),
    ?assert(maps:is_key(server_time, Response)).

test_echo_command() ->
    Command = #{<<"command">> => <<"echo">>, <<"data">> => <<"test message">>},
    Response = berl_app:handle_command(Command),
    
    ?assertEqual(<<"echo_response">>, maps:get(type, Response)),
    ?assertEqual(<<"test message">>, maps:get(original, Response)),
    ?assertEqual(<<"Echo: test message">>, maps:get(response, Response)).

test_status_command() ->
    Command = #{<<"command">> => <<"status">>, <<"request_id">> => <<"test123">>},
    Response = berl_app:handle_command(Command),
    
    ?assertEqual(<<"status_response">>, maps:get(type, Response)),
    ?assertEqual(<<"test123">>, maps:get(request_id, Response)),
    ?assertEqual(<<"online">>, maps:get(status, Response)),
    ?assertEqual(<<"berl_websocket_server">>, maps:get(server, Response)).

test_greeting_command() ->
    Command = #{<<"type">> => <<"greeting">>, <<"message">> => <<"Hello from test!">>},
    Response = berl_app:handle_command(Command),
    
    ?assertEqual(<<"greeting_response">>, maps:get(type, Response)),
    ?assertEqual(<<"Hello from test!">>, maps:get(received, Response)),
    ?assert(maps:is_key(message, Response)).

test_unknown_command() ->
    Command = #{<<"type">> => <<"unknown_type">>, <<"data">> => <<"test">>},
    Response = berl_app:handle_command(Command),
    
    ?assertEqual(<<"unknown_command_response">>, maps:get(type, Response)),
    ?assert(maps:is_key(available_commands, Response)).

test_invalid_command() ->
    Command = "invalid command format",
    Response = berl_app:handle_command(Command),
    
    ?assertEqual(<<"invalid_command_format">>, maps:get(error, Response)),
    ?assert(maps:is_key(details, Response)).
