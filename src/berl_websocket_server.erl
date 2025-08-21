%%%===================================================================
%%% @doc
%%% BERL WebSocket Server
%%% 
%%% Implements RFC 6455 compliant WebSocket server for communication
%%% between the Erlang backend and Python GUI frontend.
%%% 
%%% Key Features:
%%% - Full WebSocket frame masking support (client-to-server)
%%% - JSON command processing via berl_app:handle_command/1
%%% - Multiple client support (one per port)
%%% - Proper WebSocket handshake per RFC 6455
%%% 
%%% Frame Masking:
%%% - Supports both masked and unmasked frames for robustness
%%% - Proper RFC 6455 compliance for client-to-server masking
%%% - See docs/websocket-frame-masking.md for detailed explanation
%%% 
%%% @see docs/websocket-frame-masking.md
%%% @end
%%%===================================================================

-module(berl_websocket_server).
-behaviour(gen_server).

%% API
-export([start_link/0, start_link/1, stop/1, send_message/2, get_server_name/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% Default port for WebSocket server
-define(DEFAULT_PORT, 19765).
-define(WEBSOCKET_MAGIC, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").

-record(state, {
    listen_socket,
    port,
    server_name,
    client_socket = undefined,
    client_pid = undefined
}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    start_link(?DEFAULT_PORT).

start_link(Port) ->
    ServerName = get_server_name(Port),
    logger:info("🎯 ATTEMPTING TO START WebSocket server ~p on port ~p", [ServerName, Port]),
    case gen_server:start_link(?MODULE, [Port], []) of
        {ok, Pid} ->
            logger:info("✅ WebSocket server started successfully (PID: ~p), now registering name ~p", [Pid, ServerName]),
            % Register the name manually after successful start
            case catch register(ServerName, Pid) of
                true ->
                    logger:info("✅ Successfully registered name ~p for PID ~p", [ServerName, Pid]),
                    {ok, Pid};
                {'EXIT', {badarg, _}} ->
                    logger:error("❌ Failed to register name ~p - already exists", [ServerName]),
                    {ok, Pid};  % Return success anyway, but warn
                Error ->
                    logger:error("❌ Unexpected error registering name ~p: ~p", [ServerName, Error]),
                    {ok, Pid}
            end;
        Error ->
            logger:error("❌ Failed to start WebSocket server: ~p", [Error]),
            Error
    end.

%% Get the registered name for a WebSocket server on a specific port
get_server_name(Port) ->
    list_to_atom("berl_websocket_server_" ++ integer_to_list(Port)).

stop(Port) ->
    ServerName = get_server_name(Port),
    gen_server:call(ServerName, stop).

send_message(Port, Message) ->
    ServerName = get_server_name(Port),
    gen_server:cast(ServerName, {send_message, Message}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([Port]) ->
    process_flag(trap_exit, true),
    ServerName = get_server_name(Port),
    
    logger:info("🚀 WebSocket server INIT starting for port ~p", [Port]),
    
    % Register with orchestrator
    case whereis(berl_orchestrator) of
        undefined ->
            logger:warning("Orchestrator not available for WebSocket server registration"),
            ok;
        OrchestratorPid when is_pid(OrchestratorPid) ->
            case berl_orchestrator:register_process({websocket, Port}, ServerName) of
                ok ->
                    logger:info("WebSocket server on port ~p registered with orchestrator", [Port]),
                    ok;
                {error, RegReason} ->
                    logger:warning("Failed to register WebSocket server on port ~p with orchestrator: ~p", [Port, RegReason]),
                    ok
            end
    end,
    
    logger:info("🔗 Attempting TCP listen on port ~p", [Port]),
    % Use localhost binding for reliable connectivity on macOS
    ListenOpts = [
        binary, 
        {packet, 0}, 
        {active, false}, 
        {reuseaddr, true},
        {ip, {127, 0, 0, 1}}  % Bind specifically to localhost
    ],
    case gen_tcp:listen(Port, ListenOpts) of
        {ok, ListenSocket} ->
            logger:info("✅ WebSocket server TCP listener started successfully on port ~p", [Port]),
            % Get comprehensive socket information
            case inet:sockname(ListenSocket) of
                {ok, {IP, ActualPort}} ->
                    logger:info("🔍 Socket bound to IP: ~p, Port: ~p", [IP, ActualPort]),
                    case inet:port(ListenSocket) of
                        {ok, VerifyPort} ->
                            logger:info("🔍 Socket port verification: ~p", [VerifyPort]),
                            % Test if socket is actually accessible
                            Self = self(),
                            AcceptPid = spawn_link(fun() -> accept_loop(ListenSocket, Self) end),
                            logger:info("🔄 WebSocket server accept loop started for port ~p, accept PID: ~p", [Port, AcceptPid]),
                            {ok, #state{listen_socket = ListenSocket, port = Port, server_name = ServerName}};
                        {error, PortReason} ->
                            logger:error("❌ Failed to verify socket port: ~p", [PortReason]),
                            gen_tcp:close(ListenSocket),
                            {stop, PortReason}
                    end;
                {error, SocknameReason} ->
                    logger:error("❌ Failed to get socket address: ~p", [SocknameReason]),
                    gen_tcp:close(ListenSocket),
                    {stop, SocknameReason}
            end;
        {error, Reason} ->
            logger:error("❌ FAILED to start WebSocket server TCP listener on port ~p: ~p", [Port, Reason]),
            {stop, Reason}
    end.

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast({send_message, Message}, #state{client_socket = Socket} = State) when Socket =/= undefined ->
    try
        JsonData = jsx:encode(Message),
        Frame = encode_websocket_frame(JsonData),
        case gen_tcp:send(Socket, Frame) of
            ok ->
                logger:debug("Sent WebSocket message: ~p", [Message]),
                ok;
            {error, SendReason} ->
                logger:warning("Failed to send WebSocket message: ~p", [SendReason])
        end
    catch
        Error:EncodeReason ->
            logger:error("Error encoding/sending WebSocket message: ~p:~p", [Error, EncodeReason])
    end,
    {noreply, State};

handle_cast({send_message, _Message}, State) ->
    logger:warning("No WebSocket client connected, message dropped"),
    {noreply, State};

handle_cast({broadcast, Message}, State) ->
    % Handle broadcast messages (same as send_message for single client server)
    handle_cast({send_message, Message}, State);

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({tcp, Socket, Data}, #state{client_socket = Socket} = State) ->
    logger:info("🔍 WEBSOCKET TCP DATA RECEIVED: ~p bytes", [byte_size(Data)]),
    logger:info("🔍 WEBSOCKET RAW DATA: ~p", [Data]),
    logger:info("🔍 WEBSOCKET RAW DATA HEX: ~s", [binary:encode_hex(Data)]),
    
    Result = case decode_websocket_frame(Data) of
        {error, protocol_violation_unmasked_frame} ->
            logger:error("🚨 RFC 6455 VIOLATION: Closing connection due to unmasked frame from client"),
            % Send close frame with protocol error status code (1002)
            CloseFrame = <<1:1, 0:3, 8:4, 0:1, 2:7, 1002:16>>,
            gen_tcp:send(Socket, CloseFrame),
            gen_tcp:close(Socket),
            {noreply, State#state{client_socket = undefined}};
        {ok, close_frame} ->
            logger:info("🔍 WEBSOCKET CLOSE FRAME RECEIVED"),
            % Send close frame response
            CloseFrame = <<1:1, 0:3, 8:4, 0:1, 0:7>>,
            gen_tcp:send(Socket, CloseFrame),
            gen_tcp:close(Socket),
            {noreply, State#state{client_socket = undefined}};
        {ok, ping_frame} ->
            logger:info("🔍 WEBSOCKET PING FRAME RECEIVED - sending pong"),
            % Send pong frame
            PongFrame = <<1:1, 0:3, 10:4, 0:1, 0:7>>,
            gen_tcp:send(Socket, PongFrame),
            {noreply, State};
        {ok, pong_frame} ->
            logger:debug("🔍 WEBSOCKET PONG FRAME RECEIVED"),
            {noreply, State};
        {ok, JsonData} ->
            logger:info("🔍 WEBSOCKET DECODED JSON: ~p", [JsonData]),
            try
                Command = jsx:decode(JsonData, [return_maps]),
                logger:info("📥 WEBSOCKET COMMAND PARSED: ~p", [Command]),
                
                % Write to debug file
                file:write_file("debug_websocket_commands.log", 
                    io_lib:format("~s: Received command: ~p~n", 
                        [calendar:system_time_to_rfc3339(erlang:system_time(second)), Command]), 
                    [append]),
                
                % Process the command
                Response = berl_app:handle_command(Command),
                logger:info("📤 WEBSOCKET RESPONSE GENERATED: ~p", [Response]),
                gen_server:cast(self(), {send_message, Response}),
                {noreply, State}
            catch
                ParseError:ParseReason ->
                    logger:error("Failed to parse WebSocket JSON: ~p:~p, Data: ~p", [ParseError, ParseReason, JsonData]),
                    ErrorResponse = #{error => <<"json_parse_error">>, 
                                    details => list_to_binary(io_lib:format("~p:~p", [ParseError, ParseReason]))},
                    gen_server:cast(self(), {send_message, ErrorResponse}),
                    {noreply, State}
            end;
        {error, incomplete_frame} ->
            logger:debug("🔍 WEBSOCKET INCOMPLETE FRAME - waiting for more data"),
            % Store partial frame for next message (simplified implementation)
            {noreply, State};
        {error, Reason} ->
            logger:warning("🔍 WEBSOCKET DECODE FAILED: ~p, Raw data: ~p", [Reason, Data]),
            logger:warning("🔍 WEBSOCKET DECODE FAILED HEX: ~s", [binary:encode_hex(Data)]),
            % Don't close connection on decode error - keep it alive
            {noreply, State}
    end,
    
    % Set socket to receive next message
    inet:setopts(Socket, [{active, once}]),
    Result;

handle_info({tcp_closed, Socket}, #state{client_socket = Socket} = State) ->
    logger:info("WebSocket client disconnected"),
    {noreply, State#state{client_socket = undefined, client_pid = undefined}};

handle_info({tcp_error, Socket, Reason}, #state{client_socket = Socket} = State) ->
    logger:warning("WebSocket TCP error: ~p", [Reason]),
    {noreply, State#state{client_socket = undefined, client_pid = undefined}};

handle_info({new_client, ClientSocket}, State) ->
    logger:info("🔗 New WebSocket client connected, taking socket ownership"),
    logger:info("🔍 DEBUG: Socket before ownership transfer: ~p", [ClientSocket]),
    
    % Transfer socket ownership from accept loop process to this gen_server process
    case gen_tcp:controlling_process(ClientSocket, self()) of
        ok ->
            logger:info("✅ Successfully transferred socket ownership to gen_server"),
            % Now set socket options after we own it
            case inet:setopts(ClientSocket, [{active, once}]) of
                ok ->
                    logger:info("✅ Successfully set socket to {active, once}"),
                    ok;
                {error, SetOptError} ->
                    logger:error("❌ Failed to set socket options: ~p", [SetOptError])
            end,
            logger:info("🔍 DEBUG: Socket options after setup: ~p", [inet:getopts(ClientSocket, [active, packet])]),
            {noreply, State#state{client_socket = ClientSocket}};
        {error, OwnershipError} ->
            logger:error("❌ Failed to transfer socket ownership: ~p", [OwnershipError]),
            gen_tcp:close(ClientSocket),
            {noreply, State}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{listen_socket = ListenSocket, client_socket = ClientSocket}) ->
    if 
        ClientSocket =/= undefined -> gen_tcp:close(ClientSocket);
        true -> ok
    end,
    if 
        ListenSocket =/= undefined -> gen_tcp:close(ListenSocket);
        true -> ok
    end,
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

accept_loop(ListenSocket, ServerPid) ->
    logger:info("🔄 WebSocket accept loop waiting for connections"),
    logger:info("🔍 DEBUG: Accept loop iteration starting, ListenSocket: ~p", [ListenSocket]),
    % Verify socket is still active before accepting
    case inet:sockname(ListenSocket) of
        {ok, {IP, Port}} ->
            logger:info("🔍 Socket still bound to ~p:~p", [IP, Port]),
            case gen_tcp:accept(ListenSocket) of
                {ok, ClientSocket} ->
                    logger:info("🔗 NEW CLIENT CONNECTED - starting handshake, ClientSocket: ~p", [ClientSocket]),
                    logger:info("🔍 Client socket details: ~p", [inet:peername(ClientSocket)]),
                    % Spawn a separate process to handle this client so accept loop doesn't block
                    spawn_link(fun() -> handle_client_handshake(ClientSocket, ServerPid) end),
                    % Immediately continue accepting more connections
                    accept_loop(ListenSocket, ServerPid);
                {error, Reason} ->
                    logger:error("❌ Failed to accept connection: ~p", [Reason]),
                    timer:sleep(1000),
                    accept_loop(ListenSocket, ServerPid)
            end;
        {error, SocknameError} ->
            logger:error("❌ Socket no longer bound: ~p", [SocknameError]),
            timer:sleep(5000),
            accept_loop(ListenSocket, ServerPid)
    end.

handle_client_handshake(ClientSocket, ServerPid) ->
    logger:info("🤝 Handling client handshake in separate process"),
    case websocket_handshake(ClientSocket) of
        ok ->
            logger:info("✅ WebSocket handshake successful"),
            % Notify the main process about new client
            ServerPid ! {new_client, ClientSocket};
        {error, Reason} ->
            logger:warning("❌ WebSocket handshake failed: ~p", [Reason]),
            gen_tcp:close(ClientSocket)
    end.

websocket_handshake(Socket) ->
    logger:info("🤝 Starting RFC 6455 compliant WebSocket handshake"),
    logger:info("🔍 Socket info: ~p", [Socket]),
    case gen_tcp:recv(Socket, 0, 10000) of  % Increased timeout to 10 seconds
        {ok, Data} ->
            logger:info("📨 Received handshake data: ~p bytes", [byte_size(Data)]),
            logger:info("📨 Raw handshake data: ~p", [Data]),
            case parse_http_request(Data) of
                {ok, Headers} ->
                    logger:info("📋 Parsed HTTP headers: ~p", [maps:keys(Headers)]),
                    logger:info("📋 Full headers map: ~p", [Headers]),
                    % RFC 6455 Section 4.2.1: Validate required headers
                    case validate_websocket_headers(Headers) of
                        {ok, Key} ->
                            logger:info("🔑 Valid WebSocket handshake, key: ~p", [Key]),
                            AcceptKey = generate_accept_key(Key),
                            logger:info("🔑 Generated accept key: ~p", [AcceptKey]),
                            Response = [
                                "HTTP/1.1 101 Switching Protocols\r\n",
                                "Upgrade: websocket\r\n",
                                "Connection: Upgrade\r\n",
                                "Sec-WebSocket-Accept: ", AcceptKey, "\r\n",
                                "\r\n"
                            ],
                            logger:info("📤 Sending WebSocket response: ~p", [iolist_to_binary(Response)]),
                            case gen_tcp:send(Socket, Response) of
                                ok -> 
                                    logger:info("✅ RFC 6455 compliant WebSocket handshake response sent"),
                                    ok;
                                Error -> 
                                    logger:error("❌ Failed to send handshake response: ~p", [Error]),
                                    Error
                            end;
                        {error, Reason} ->
                            logger:warning("❌ WebSocket handshake validation failed: ~p", [Reason]),
                            % Send 400 Bad Request for invalid handshake
                            ErrorResponse = [
                                "HTTP/1.1 400 Bad Request\r\n",
                                "Content-Type: text/plain\r\n",
                                "Content-Length: 23\r\n",
                                "\r\n",
                                "Invalid WebSocket request"
                            ],
                            gen_tcp:send(Socket, ErrorResponse),
                            {error, Reason}
                    end;
                {error, Reason} ->
                    logger:error("❌ Failed to parse HTTP request: ~p", [Reason]),
                    {error, Reason}
            end;
        {error, timeout} ->
            logger:error("❌ WebSocket handshake timed out (no data received within 10 seconds)"),
            {error, timeout};
        {error, Reason} ->
            logger:error("❌ Failed to receive handshake data: ~p", [Reason]),
            {error, Reason}
    end.

parse_http_request(Data) ->
    Lines = binary:split(Data, <<"\r\n">>, [global]),
    Headers = maps:new(),
    parse_headers(Lines, Headers).

parse_headers([<<>>|_], Headers) ->
    {ok, Headers};
parse_headers([Line|Rest], Headers) ->
    case binary:split(Line, <<": ">>) of
        [Name, Value] ->
            LowerName = string:lowercase(Name),
            parse_headers(Rest, maps:put(LowerName, Value, Headers));
        _ ->
            parse_headers(Rest, Headers)
    end;
parse_headers([], Headers) ->
    {ok, Headers}.

generate_accept_key(Key) ->
    Concat = <<Key/binary, ?WEBSOCKET_MAGIC>>,
    Hash = crypto:hash(sha, Concat),
    base64:encode(Hash).

%% @doc Validate WebSocket headers according to RFC 6455 Section 4.2.1
validate_websocket_headers(Headers) ->
    % Required headers per RFC 6455
    RequiredChecks = [
        {<<"upgrade">>, <<"websocket">>, "Missing or invalid Upgrade header"},
        {<<"connection">>, fun validate_connection_header/1, "Missing or invalid Connection header"},
        {<<"sec-websocket-key">>, fun validate_websocket_key/1, "Missing or invalid Sec-WebSocket-Key"},
        {<<"sec-websocket-version">>, <<"13">>, "Missing or invalid Sec-WebSocket-Version (must be 13)"}
    ],
    
    case validate_required_headers(Headers, RequiredChecks) of
        {ok, Key} -> {ok, Key};
        {error, Reason} -> {error, Reason}
    end.

%% @doc Validate required headers recursively
validate_required_headers(Headers, []) ->
    % All validations passed, return the WebSocket key
    case maps:get(<<"sec-websocket-key">>, Headers, undefined) of
        undefined -> {error, missing_websocket_key};
        Key -> {ok, Key}
    end;
validate_required_headers(Headers, [{HeaderName, Expected, ErrorMsg} | Rest]) ->
    case maps:get(HeaderName, Headers, undefined) of
        undefined ->
            {error, {missing_header, HeaderName, ErrorMsg}};
        Value ->
            case validate_header_value(Value, Expected) of
                true -> validate_required_headers(Headers, Rest);
                false -> {error, {invalid_header, HeaderName, ErrorMsg, Value}}
            end
    end.

%% @doc Validate header value against expected value or validation function
validate_header_value(Value, Expected) when is_binary(Expected) ->
    string:lowercase(Value) =:= Expected;
validate_header_value(Value, ValidatorFun) when is_function(ValidatorFun, 1) ->
    ValidatorFun(Value).

%% @doc Validate Connection header contains "upgrade" token (case-insensitive)
validate_connection_header(Value) ->
    Tokens = re:split(string:lowercase(Value), <<"\\s*,\\s*">>, [global, {return, binary}]),
    lists:member(<<"upgrade">>, Tokens).

%% @doc Validate Sec-WebSocket-Key is base64 encoded 16-byte value
validate_websocket_key(Key) ->
    try
        DecodedKey = base64:decode(Key),
        byte_size(DecodedKey) =:= 16
    catch
        _:_ -> false
    end.

encode_websocket_frame(Data) ->
    DataSize = byte_size(Data),
    if
        DataSize < 126 ->
            <<1:1, 0:3, 1:4, 0:1, DataSize:7, Data/binary>>;
        DataSize < 65536 ->
            <<1:1, 0:3, 1:4, 0:1, 126:7, DataSize:16, Data/binary>>;
        true ->
            <<1:1, 0:3, 1:4, 0:1, 127:7, DataSize:64, Data/binary>>
    end.

%% @doc Decode a WebSocket frame according to RFC 6455
%% 
%% WebSocket Frame Format:
%%  0                   1                   2                   3
%%  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
%% +-+-+-+-+-------+-+-------------+-------------------------------+
%% |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
%% |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
%% |N|V|V|V|       |S|             |   (if payload len==126/127)   |
%% | |1|2|3|       |K|             |                               |
%% +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
%% |     Extended payload length continued, if payload len == 127  |
%% + - - - - - - - - - - - - - - - +-------------------------------+
%% |                               |Masking-key, if MASK set to 1  |
%% +-------------------------------+-------------------------------+
%% | Masking-key (continued)       |          Payload Data         |
%% +-------------------------------- - - - - - - - - - - - - - - - +
%% :                     Payload Data continued ...                :
%% + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
%% |                     Payload Data continued ...                |
%% +---------------------------------------------------------------+
%%
%% MASKING RULES (RFC 6455):
%% - Client-to-server frames MUST be masked (MASK bit = 1)
%% - Server-to-client frames MUST NOT be masked (MASK bit = 0)
%% - Masking prevents cache poisoning attacks via intermediary proxies
%% - Masked payload = original_payload XOR masking_key (repeating every 4 bytes)
%%
%% This function handles both masked and unmasked frames for compatibility,
%% though properly behaving clients should always send masked frames to servers.
%% @doc Decode WebSocket frames with RFC 6455 compliance
%% 
%% CRITICAL RFC 6455 COMPLIANCE:
%% - Client-to-server frames MUST be masked (Section 5.3)
%% - Server MUST close connection if unmasked frame received from client
%% - Server-to-client frames MUST NOT be masked
decode_websocket_frame(<<Fin:1, _Rsv:3, Opcode:4, Mask:1, Len:7, Rest/binary>>) when Len < 126 ->
    try
        % RFC 6455 Section 5.3: Client-to-server frames MUST be masked
        case Mask of
            0 ->
                % RFC 6455 violation: Client sent unmasked frame
                logger:error("RFC 6455 VIOLATION: Client sent unmasked frame, closing connection"),
                {error, protocol_violation_unmasked_frame};
            1 ->
                % Proper masked frame from client
                case {Fin, Opcode} of
                    {1, 1} ->
                        % Text frame, masked (standard client-to-server)
                        case Rest of
                            <<MaskKey:32, Payload:Len/binary, _/binary>> ->
                                UnmaskedPayload = unmask_payload(Payload, MaskKey),
                                {ok, UnmaskedPayload};
                            _ when byte_size(Rest) >= 4 + Len ->
                                <<MaskKey:32, Payload:Len/binary, _/binary>> = Rest,
                                UnmaskedPayload = unmask_payload(Payload, MaskKey),
                                {ok, UnmaskedPayload};
                            _ ->
                                {error, incomplete_frame}
                        end;
                    {1, 8} ->
                        % Close frame - must be masked from client
                        logger:info("Received WebSocket close frame (masked)"),
                        {ok, close_frame};
                    {1, 9} ->
                        % Ping frame - must be masked from client
                        logger:debug("Received WebSocket ping frame (masked)"),
                        {ok, ping_frame};
                    {1, 10} ->
                        % Pong frame - must be masked from client
                        logger:debug("Received WebSocket pong frame (masked)"),
                        {ok, pong_frame};
                    {0, _} ->
                        % Fragmented frame (not fully implemented)
                        logger:warning("Received fragmented WebSocket frame (not supported)"),
                        {error, fragmented_frame};
                    _ ->
                        logger:warning("Unsupported WebSocket frame: FIN=~p, Opcode=~p", [Fin, Opcode]),
                        {error, unsupported_frame}
                end
        end
    catch
        Error:Reason ->
            logger:error("Error decoding WebSocket frame: ~p:~p", [Error, Reason]),
            {error, decode_error}
    end;
decode_websocket_frame(<<Fin:1, _Rsv:3, Opcode:4, Mask:1, 126:7, Len:16, Rest/binary>>) ->
    % Extended payload length (16-bit)
    try
        % RFC 6455 Section 5.3: Client-to-server frames MUST be masked
        case Mask of
            0 ->
                % RFC 6455 violation: Client sent unmasked frame
                logger:error("RFC 6455 VIOLATION: Client sent unmasked extended frame, closing connection"),
                {error, protocol_violation_unmasked_frame};
            1 ->
                % Proper masked frame from client
                case {Fin, Opcode} of
                    {1, 1} ->
                        % Text frame, masked, extended length
                        case Rest of
                            <<MaskKey:32, Payload:Len/binary, _/binary>> ->
                                UnmaskedPayload = unmask_payload(Payload, MaskKey),
                                {ok, UnmaskedPayload};
                            _ when byte_size(Rest) >= 4 + Len ->
                                <<MaskKey:32, Payload:Len/binary, _/binary>> = Rest,
                                UnmaskedPayload = unmask_payload(Payload, MaskKey),
                                {ok, UnmaskedPayload};
                            _ ->
                                {error, incomplete_frame}
                        end;
                    _ ->
                        logger:warning("Unsupported extended frame: FIN=~p, Opcode=~p, Len=~p", [Fin, Opcode, Len]),
                        {error, unsupported_frame}
                end
        end
    catch
        Error:Reason ->
            logger:error("Error decoding extended WebSocket frame: ~p:~p", [Error, Reason]),
            {error, decode_error}
    end;
decode_websocket_frame(Data) when byte_size(Data) < 2 ->
    % Not enough data for a complete frame header
    {error, incomplete_frame};
decode_websocket_frame(Data) ->
    logger:warning("Unsupported WebSocket frame format, size: ~p, data: ~w", [byte_size(Data), binary:part(Data, 0, min(8, byte_size(Data)))]),
    {error, unsupported_frame}.

%% @doc Unmask WebSocket payload data using the provided masking key
%% 
%% Per RFC 6455, masking is performed by XORing each payload byte with the
%% corresponding byte of the masking key, cycling through the 4-byte key:
%% 
%% unmasked_byte[i] = masked_byte[i] XOR masking_key[i MOD 4]
%% 
%% This process is reversible (XOR is its own inverse operation).
%% 
%% @param Payload The masked payload data as binary
%% @param Mask The 32-bit masking key
%% @returns The unmasked payload data as binary
unmask_payload(Payload, Mask) ->
    unmask_payload(Payload, Mask, 0, <<>>).

%% @private
%% @doc Internal helper for payload unmasking with byte index tracking
unmask_payload(<<>>, _Mask, _Index, Acc) ->
    Acc;
unmask_payload(<<Byte:8, Rest/binary>>, Mask, Index, Acc) ->
    % Extract the appropriate masking byte (cycling every 4 bytes)
    MaskByte = (Mask bsr (8 * (3 - (Index rem 4)))) band 16#FF,
    % XOR the payload byte with the masking byte
    UnmaskedByte = Byte bxor MaskByte,
    unmask_payload(Rest, Mask, Index + 1, <<Acc/binary, UnmaskedByte:8>>).
