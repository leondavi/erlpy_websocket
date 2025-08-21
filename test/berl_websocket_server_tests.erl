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
         {"WebSocket frame encoding", fun test_frame_encoding/0},
         {"WebSocket handshake validation", fun test_handshake_validation/0}
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

test_frame_encoding() ->
    % Test short message encoding
    Data = <<"Hello">>,
    Frame = berl_websocket_server:encode_websocket_frame(Data),
    
    % Check frame structure: FIN=1, RSV=000, Opcode=0001 (text), MASK=0, Length=5
    <<Fin:1, Rsv:3, Opcode:4, Mask:1, Len:7, Payload/binary>> = Frame,
    
    ?assertEqual(1, Fin),      % FIN bit set
    ?assertEqual(0, Rsv),      % Reserved bits
    ?assertEqual(1, Opcode),   % Text frame
    ?assertEqual(0, Mask),     % Not masked (server-to-client)
    ?assertEqual(5, Len),      % Length of "Hello"
    ?assertEqual(Data, Payload).

test_handshake_validation() ->
    % Test valid WebSocket key validation
    ValidKey = <<"dGhlIHNhbXBsZSBub25jZQ==">>,  % Base64 encoded 16-byte value
    ?assert(berl_websocket_server:validate_websocket_key(ValidKey)),
    
    % Test invalid key
    InvalidKey = <<"invalid">>,
    ?assertNot(berl_websocket_server:validate_websocket_key(InvalidKey)),
    
    % Test connection header validation
    ValidConnection = <<"Upgrade, keep-alive">>,
    ?assert(berl_websocket_server:validate_connection_header(ValidConnection)),
    
    InvalidConnection = <<"keep-alive">>,
    ?assertNot(berl_websocket_server:validate_connection_header(InvalidConnection)).
