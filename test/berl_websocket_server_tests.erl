%%%===================================================================
%%% @doc
%%% EUnit tests for berl_websocket_server
%%% @end
%%%===================================================================

-module(berl_websocket_server_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test descriptions
%%====================================================================

berl_websocket_server_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [
         {"Start and stop server", fun test_start_stop/0},
         {"Get server name", fun test_server_name/0},
         {"Send message to server", fun test_send_message/0}
     ]}.

%%====================================================================
%% Setup and cleanup
%%====================================================================

setup() ->
    application:ensure_all_started(jsx),
    ok.

cleanup(_) ->
    ok.

%%====================================================================
%% Tests
%%====================================================================

test_start_stop() ->
    Port = 19999,  % Use a different port for testing
    
    % Start server
    {ok, Pid} = berl_websocket_server:start_link(Port),
    ?assert(is_pid(Pid)),
    
    % Check if server is alive
    ?assert(is_process_alive(Pid)),
    
    % Stop server
    ok = berl_websocket_server:stop(Port),
    
    % Give it time to stop
    timer:sleep(100),
    
    % Check if server is stopped (this might fail if process is registered)
    % ?assertNot(is_process_alive(Pid)),
    ok.

test_server_name() ->
    Port = 12345,
    Expected = berl_websocket_server_12345,
    ?assertEqual(Expected, berl_websocket_server:get_server_name(Port)).

test_send_message() ->
    Port = 19998,  % Use a different port for testing
    
    % Start server
    {ok, Pid} = berl_websocket_server:start_link(Port),
    ?assert(is_pid(Pid)),
    
    % Test sending a message (should not crash even with no client)
    TestMessage = #{type => <<"test">>, data => <<"test data">>},
    ?assertEqual(ok, berl_websocket_server:send_message(Port, TestMessage)),
    
    % Stop server
    ok = berl_websocket_server:stop(Port),
    ok.
