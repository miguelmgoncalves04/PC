-module(client_handler).
-export([init/3]).

init(Socket,UTM,MM) -> 
    login_loop(Socket,UTM,MM). % pid do UTM e do MM

join_queue(MATCHMAKER_PID, Username) ->  % PID: MATCHMAKER_PID 
    MATCHMAKER_PID ! {join_queue, self(), Username};

join_queue(MATCHMAKER_PID, Username) ->  % PID: MATCHMAKER_PID
    MATCHMAKER_PID ! {join_queue, self(), Username},
    receive Response -> Response end.

login_loop(Socket,UTM,MM) -> %aqui eu vou receber algo no formato {tcp,Socket,Data}
    receive 
        {tcp,Socket,Data} ->
        Lista = binary:split(string:trim(Data), <<":">>, [global]), % comandos (e.g) LOGIN:PauloPicas:cartas123
        case Lista of %caso for um pedido do java isto vem no formato acima
            [<<"LOGIN">>, Username, Pass] -> 
                UTM ! {login_usr, self(), Username, Pass},
                login_loop(Socket,UTM,MM);
            [<<"REGIST">>, Username, Pass] -> 
                UTM ! {register_usr, self(), Username, Pass},
                login_loop(Socket,UTM,MM);
            [<<"UNREGIST">>, Username, Pass] -> 
                UTM ! {unregister_usr, self(), Username},
                login_loop(Socket,UTM,MM);
            _ ->
                gen_tcp:send(Socket, <<"(ERROR) COMANDO_INVALIDO\n">>),
                login_loop(Socket, UTM, MM)
            end;

        {ok, _} -> % sai do loop!!! entra no matchmaker
            gen_tcp:send(Socket, <<"<ENTRASTE>\n">>),
            matchmaker_loop(Socket,UTM,MM);
            

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

        
        
            
            

    



