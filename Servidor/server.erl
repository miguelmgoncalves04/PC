module(tcp_server).
-export([start/1]).

start(Port) ->
    % Inicia os gestores globais
    UTM = ut_manager:start(), %% user manager trata dos logins 
    MM  = matchmaker:start(), %% matchmaker 
    
    % Abre o Socket TCP
    {ok, LSocket} = gen_tcp:listen(Port, [binary, {packet, line}, {active, true}, {reuseaddr, true}]),
    io:format("Servidor ON na porta ~p~n", [Port]),
    accept_loop(LSocket, UTM, MM).

accept_loop(LSocket, UTM, MM) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    % Cria um handler para o novo jogador
    spawn(fun() -> client_handler:init(Socket, UTM, MM) end),
    accept_loop(LSocket, UTM, MM).