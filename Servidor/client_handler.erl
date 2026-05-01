-module(client_handler).
-export([init/3]).

init(Socket,UTM,MM) -> 
    login_loop(Socket,UTM,MM). % pid do UTM e do MM

join_queue(MATCHMAKER_PID,Username) ->  % PID: MATCHMAKER_PID
    MATCHMAKER_PID ! {join_queue, self(),Username}.

leave_queue(M_Pid, Username) ->
    M_Pid ! {leave_queue, self(), Username}.
    

login_loop(Socket,UTM,MM) -> %aqui eu vou receber algo no formato {tcp,Socket,Data}
    receive 
        {tcp,Socket,Data} -> % RECEBI ALGO DO JAVA (user_input)
        Data1 = strip_newline(Data), %tira o /n no final q tava a fuder com tudo tipo quando fazemos login:....."ENTER"
        Lista = binary:split(Data1, <<":">>, [global]), % segundo o chat "O {packet, line} já remove o \n, por isso não é necessário trim"  e tbm "string:trim nao funciona com binarios" "mas é um bocadinho contraditorio porque eu mesmo assim tive que fazer uma funcao auxiliar para tirar o \n, mas prontos está a funcionar. Mesmo assim deixei comentado como estava caso eu seja meio necio e tivesse tudo bem.
        %Lista = binary:split(string:trim(Data), <<":">>, [global]), % comandos (e.g) LOGIN:PauloPicas:cartas123
        case Lista of %caso for um pedido do java isto vem no formato acima
            [<<"LOGIN">>, Username, Pass] -> 
                UTM ! {login_usr, self(), Username, Pass},
                login_loop(Socket,UTM,MM);
            [<<"REGIST">>, Username, Pass] -> 
                UTM ! {register_usr, self(), Username, Pass},
                login_loop(Socket,UTM,MM);
            [<<"UNREGIST">>, Username, Pass] -> 
                UTM ! {unregister_usr, self(), Username, Pass},
                login_loop(Socket,UTM,MM);
            [<<"LOGOUT">>] ->
                login_loop(Socket,UTM,MM);
            _ ->
                gen_tcp:send(Socket, <<"(ERROR) COMANDO_INVALIDO\n">>),
                login_loop(Socket, UTM, MM)
            end;
        
        {ok, registered, _Username}->
            gen_tcp:send(Socket, <<"<RESGISTRADO>\n">>),
            login_loop(Socket,UTM,MM);
            
        {ok,logged, Username} -> % sai do loop!!! entra no matchmaker
            gen_tcp:send(Socket, <<"<ENTRASTE>\n">>),
            matchmaker_loop(Socket,UTM,MM,Username);
            

        {error, already_logged} ->
            gen_tcp:send(Socket, <<"(ERROR) JA ESTAS LOGADO!\n">>),
            login_loop(Socket, UTM, MM);
        
            
        {error, wrong_password} ->
            gen_tcp:send(Socket, <<"(ERROR) PASSWORD ERRADA!\n">>),
            login_loop(Socket, UTM, MM);
        
        
        {error, user_exists} ->
            gen_tcp:send(Socket, <<"(ERROR) USER JA EXISTE TENTA OUTRA VEZ\n">>),
            login_loop(Socket, UTM, MM);
        
        {error, user_not_found} ->
            gen_tcp:send(Socket, <<"(ERROR) USER NAO EXISTE\n">>),
            login_loop(Socket, UTM, MM);
        
        {tcp_closed, Socket} ->
            io:format("Cliente desligou-se durante o login.~n")
        end.

matchmaker_loop(Socket,UTM,MM,Username) ->
    receive
        {tcp,Socket,Data} -> 
            Data1 = strip_newline(Data),
            io:format("DEBUG matchmaker recebeu: ~p~n", [Data1]), 
            Lista = binary:split(Data1, <<":">>, [global]), % segundo o chat "O {packet, line} já remove o \n, por isso não é necessário trim" e tbm "string:trim nao funciona com binarios" "mas é um bocadinho contraditorio porque eu mesmo assim tive que fazer uma funcao auxiliar para tirar o \n, mas prontos está a funcionar"
            %Lista = binary:split(string:trim(Data), <<":">>, [global]), % comandos (e.g) JOIN EXIT LOGOUT
            case Lista of %caso for um pedido do java isto vem no formato acima
            [<<"JOIN">>] -> 
                join_queue(MM,Username),
                matchmaker_loop(Socket,UTM,MM,Username);
            [<<"EXIT">>] ->
                leave_queue(MM,Username),
                matchmaker_loop(Socket,UTM,MM,Username);
            _ ->
                gen_tcp:send(Socket, <<"(ERROR) COMANDO_INVALIDO\n">>),
                matchmaker_loop(Socket, UTM, MM,Username)
            end;

        {matchmaker, {game_start, GamePid}} ->
            gen_tcp:send(Socket, <<"GAME_START\n">>), % pus isto aqui para ir para o ecra de jogo tipo depois de esperar
            game_loop(Socket,UTM,MM,Username,GamePid);
            
        {tcp_closed, Socket} ->
            leave_queue(MM,Username),
            io:format("Cliente desligou-se durante o matchmaking.~n")
        

    end.   

% isto nao me parece muito bem porque a mensagem de exit tem de vir de algum sitio neste caso do java.
game_loop(Socket, UTM, MM, Username, GamePid) ->
    receive
        % Agora o que o jogador prime é enviado para o game_session
        {tcp, Socket, Data} ->
            Data1 = strip_newline(Data),
            Command = parse_movement(Data1),                       % converte binário para átomo (left, right, forward)
            game_session:send_input(GamePid, Username, Command),  % envia ao processo do jogo
            game_loop(Socket, UTM, MM, Username, GamePid);

        {exit} ->
            matchmaker_loop(Socket, UTM, MM, Username);

        {game_update, Json} ->
            gen_tcp:send(Socket, Json),
            game_loop(Socket, UTM, MM, Username, GamePid);

        
        % Quando o game_session envia {game_over, ...}, voltamos ao matchmaker
        {game_over, _GamePid} ->
            matchmaker_loop(Socket, UTM, MM, Username);

        {tcp_closed, Socket} ->
            io:format("Cliente desligou-se durante o jogo.~n")
    end.

% Converte os comandos em binário que vêm do cliente (ex: <<"LEFT">>) nos átomos
% que o game_session espera (left, right, forward)
parse_movement(<<"LEFT">>)    -> left;
parse_movement(<<"RIGHT">>)   -> right;
parse_movement(<<"FORWARD">>) -> forward;
parse_movement(_)             -> unknown.


            
            

% funcao auxiliar que remove os /n no final se tiver

strip_newline(Bin) ->
    case binary:last(Bin) of
        $\n -> binary:part(Bin, 0, byte_size(Bin)-1);
        _   -> Bin
    end.


% Resumidamente tipo o cliente ao fazer o registro e o login depois estava a mandar <<"JOIN\n">> e não só join por isso estava a cair no  _ -> e dava o erro (ERROR) COMANDO_INVALIDO.
% Eu testei isso com um game_session que deixei comentado e voçês podem ver que agora tá tudo direitinho e vai da tela de login para a tela de espera para a tela do jogo.


