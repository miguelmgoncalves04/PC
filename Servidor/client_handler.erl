-module(client_handler).
-export([init/3]).

init(Socket, UTM, MM) ->
    login_loop(Socket, UTM, MM, undefined).   % pid do UTM e do MM

%ALTERAÇÕES:


% nos ja temos esta funcao feita no matchmaker, tipo n podemos simplesmente apagar zezinho??
% Tipo no caso a join_queue nos podemos simplesmente chamar matchmaker:join_queue e tá n?
% Memo assim deixei comentado 

%adicionei usarname tipo no login_loop e essas cenas, tipo literalmente join_queue usa o Username
% e completei o que faltava fazer acho que agora o que falta memo é fazer o game_session direito e o java fdd




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%join_queue(MATCHMAKER_PID, Username) ->  % PID: MATCHMAKER_PID 
%    MATCHMAKER_PID ! {join_queue, self(), Username};

%join_queue(MATCHMAKER_PID, Username) ->  % PID: MATCHMAKER_PID
%    MATCHMAKER_PID ! {join_queue, self(), Username},
%    receive Response -> Response end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





login_loop(Socket,UTM,MM,Username) -> %aqui eu vou receber algo no formato {tcp,Socket,Data}
    receive 
        {tcp,Socket,Data} ->
            io:format("[DEBUG] Recebido: ~p~n", [Data]), % n tava a conseguir fazer com que o servidor recebe-se as mensagens do cliente mas agora dá. e agora já conseguem compilar e isso mas deixo para caso ajude de debug
            Lista = binary:split(string:trim(Data), <<":">>, [global]), % comandos (e.g) LOGIN:PauloPicas:cartas123
            case Lista of %caso for um pedido do java isto vem no formato acima
                
                [<<"LOGIN">>, User, Pass] ->
                    UTM ! {login_usr, self(), User, Pass},
                    login_loop(Socket, UTM, MM, User);   % guarda o User
                
                [<<"REGIST">>, User, Pass] ->
                    UTM ! {register_usr, self(), User, Pass},
                    login_loop(Socket, UTM, MM, User);   % guarda o User
                
                [<<"UNREGIST">>, User | _] ->
                    UTM ! {unregister_usr, self(), User},
                    login_loop(Socket, UTM, MM, User);
                _ ->
                    gen_tcp:send(Socket, <<"(ERROR) COMANDO_INVALIDO\n">>),
                    login_loop(Socket, UTM, MM, Username)
            end;

        {ok, _} when Username =/= undefined -> % sai do loop!!! entra no matchmaker
            gen_tcp:send(Socket, <<"<ENTRASTE>\n">>),
            matchmaker_loop(Socket, UTM, MM, Username);

        {ok, _} ->
            gen_tcp:send(Socket, <<"(ERROR) ERRO INTERNO\n">>),
            login_loop(Socket, UTM, MM, undefined);

        {error, already_logged} ->
            gen_tcp:send(Socket, <<"(ERROR) JA ESTAS LOGADO!\n">>),
            login_loop(Socket, UTM, MM, undefined);

        {error, wrong_password} ->
            gen_tcp:send(Socket, <<"(ERROR) PASSWORD ERRADA!\n">>),
            login_loop(Socket, UTM, MM, undefined);

        {error, user_exists} ->
            gen_tcp:send(Socket, <<"(ERROR) USER JA EXISTE\n">>),
            login_loop(Socket, UTM, MM, undefined);
        
        {error, user_not_found} ->
            gen_tcp:send(Socket, <<"(ERROR) USER NAO EXISTE\n">>),
            login_loop(Socket, UTM, MM, undefined);

        {tcp_closed, Socket} ->
            io:format("Cliente desligou-se durante o login.~n")
    end.


matchmaker_loop(Socket, UTM, MM, Username) ->
    receive
        {tcp, Socket, Data} ->
            Lista = binary:split(string:trim(Data), <<":">>, [global]),
            case Lista of
                [<<"JOGAR">>] ->
                    % Pedido para entrar na fila
                    matchmaker:join_queue(MM, Username),
                    matchmaker_loop(Socket, UTM, MM, Username);
                [<<"SAIR">>] ->
                    matchmaker:leave_queue(MM, Username),
                    matchmaker_loop(Socket, UTM, MM, Username);
                _ ->
                    gen_tcp:send(Socket, <<"(ERROR) COMANDO_INVALIDO\n">>),
                    matchmaker_loop(Socket, UTM, MM, Username)
            end;

        {matchmaker, {game_start, GamePid}} ->
            gen_tcp:send(Socket, <<"PARTIDA_START\n">>),
            game_loop(Socket, GamePid, Username);

        {tcp_closed, Socket} ->
            io:format("Cliente desligou-se durante a espera.~n")
    end.    
            

game_loop(Socket, GamePid, Username) ->
    receive
        {tcp, Socket, Data} ->
            process_key(Socket, GamePid, Username, Data),
            game_loop(Socket, GamePid, Username);

        {game_update, State} ->
            WorldStr = serialize_world(State),
            gen_tcp:send(Socket, WorldStr ++ <<"\n">>),
            game_loop(Socket, GamePid, Username);

        {tcp_closed, Socket} ->
            io:format("Cliente desligou-se durante o jogo.~n")
    end.

%% Trata um comando recebido do cliente 
process_key(_Socket, GamePid, Username, Data) ->

% Tipo isto mais ou menos que se vai fazer em java creio eu

%void keyPressed() {
%    if (key == CODED) {
%        if (keyCode == LEFT)  myClient.write("KEY:LEFT:d\n");
%        if (keyCode == RIGHT) myClient.write("KEY:RIGHT:d\n");
%        if (keyCode == UP)    myClient.write("KEY:UP:d\n");
%    }
%}

%void keyReleased() {
%    if (key == CODED) {
%        if (keyCode == LEFT)  myClient.write("KEY:LEFT:u\n");
%        if (keyCode == RIGHT) myClient.write("KEY:RIGHT:u\n");
%        if (keyCode == UP)    myClient.write("KEY:UP:u\n");
%    }
%}

%u vem de up que significa que largamos a tecla e d vem de down que significa que tamos a precionsar a tecla btw, mas podemos 
%mudar de letra se tiver confuso
%Tipo como vai haver acelerações e isso e como pode tar a primir varias teclas ao mesmo tempo temos de saber quais estao a ser precionardas ou n

    Lista = binary:split(string:trim(Data), <<":">>, [global]),
    case Lista of
        [<<"KEY">>, <<"LEFT">>, State] when State == <<"d">>; State == <<"u">> ->             
            game_session:send_input(GamePid, Username, left);
        [<<"KEY">>, <<"RIGHT">>, State] when State == <<"d">>; State == <<"u">> ->
            game_session:send_input(GamePid, Username, right);
        [<<"KEY">>, <<"UP">>, State] when State == <<"d">>; State == <<"u">> ->
            game_session:send_input(GamePid, Username, forward);
        _ ->
            ok   % comando mal escrito
    end.
    


%chat completamente nem olhei é so memo para n ter vermelhos no codigo 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%FAZER DIREITO%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%FAZER DIREITO%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%FAZER DIREITO%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%chat completamente nem olhei é so memo para n ter vermelhos no codigo 

serialize_world(State) ->
    Players = maps:get(players, State),
    PlayerList = maps:to_list(Players),
    PlayerStrs = lists:map(fun({Username, Data}) ->
        {X, Y} = maps:get(pos, Data),
        Angle = maps:get(angle, Data),
        Mass  = maps:get(mass, Data),
        io_lib:format("~s:~p:~p:~p:~p", [Username, X, Y, Angle, Mass])
    end, PlayerList),
    list_to_binary("MUNDO " ++ string:join(PlayerStrs, " ")).
