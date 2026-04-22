-module(matchmaker).
-export([start/0, join_queue/2, leave_queue/2]).

% Podem apagar isto depois se quiserem é só para entenderem as mudanças n foi grande coisa.

% No ut_manager nao mexi em nada.

% No matchmaker simplesmente fiz com que se guarda-se tbm os Pids de quem está na fila pq é como o stor nesta aula disse que depois
% n se ia saber para quem mandar mensagem. No nosso caso é tipo nao se saberia para que gajos iamos mandar mensagem a dizer que 
% o jogo começou por exemplo, mas deve haver mais exemplos

% Fiz isso com duas listas tipo uma com os nomes e outra com os pids, como o stor fez, nao fiz com tuplos

% Em termos de funções, resumidamente é isso fiz:
% a função remove_players que simplesmente remove um jogador.
% A game_stub simplesmente espera 2m e avisa o mathcmaker que terminou tipo isto é onde vamos ter um coto de dor de cabeça
% Dantes em start_game nos tavamos a usar o GameId = make_ref(), para gerar o identificador da partida
% eu simplesmente usei o proprio pid da partida (GamePid) como identificador que o stor na aula explicou essa merda como cada
% um é unico e os caralhos, tipo ele usou isso em "Raid = spawn(fun() -> raid(...)end),"
% muito sinceramente eu prefiro o make_ref() por mais que o stor n use acho mais "legivel", mas yha fds.


% ahh e passei a função que o miguel tinha criado para start_game aquela que pega os 4 gajos ou os 3 gajos
% acho que é isso xd

start() ->
    spawn(fun() -> loop([], [], #{}, undefined) end).


join_queue(M_Pid, Username) ->  % PID: Matchmaker_PID
    M_Pid ! {join_queue, self(), Username},
    receive Response -> Response end.

leave_queue(M_Pid, Username) ->  % PID: Matchmaker_PID
    M_Pid ! {leave_queue, self(), Username},
    receive Response -> Response end.

loop(QueueNames, QueuePids, Games,Timer) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            case lists:member(Username,QueueNames) of % if username in queue
                true ->
                    From ! {error, already_in_queue},
                    loop(QueueNames, QueuePids, Games, Timer);
                false ->
                    NewNames = QueueNames ++ [Username],
                    NewPids  = QueuePids ++ [From],
                    From ! ok,
                    Tamanho = length(NewNames),
                    if
                        Tamanho =:= 3 ->
                            io:format("3 Jogadores, se nao entrar um quarto jogador o jogo iniciara em 30s"),
                            Clock = erlang:send_after(30000,self(),force_start),
                            loop(NewNames, NewPids, Games, Clock);

                        Tamanho >= 4 ->
                            io:format("4 jogadores, pronto para começar o jogo!"),
                            if Timer =/= undefined -> erlang:cancel_timer(Timer); true -> ok end,
                            {FinalNames,FinalPids ,FinalGames} = start_game(NewNames, NewPids,Games , 4),%[TRIGGER] pode acontecer um novo jogo
                            loop(FinalNames,FinalPids,FinalGames,undefined);

                        true ->
                            loop(NewNames,NewPids,Games,Timer)
                    end
            end;
        %Conas sai da fila
        {leave_queue, From, Username} ->
            case lists:member(Username, QueueNames) of
                true ->
                    {NewNames, NewPids} = remove_player(Username, QueueNames, QueuePids),
                    From ! ok,

                    NovoRelogio = if 
                        length(NewNames) < 3 andalso Timer =/= undefined->
                            erlang:cancel_timer(Timer),
                            io:format("saiu um jogador, timer cancelado"),
                            undefined;
                        true -> Timer
                    end,
                    loop(NewNames, NewPids, Games , NovoRelogio);
                false ->
                    From ! ok,
                    loop(QueueNames, QueuePids, Games,Timer)
            end;

        force_start ->
            io:format("o jogo vai começar passaram 30 segundos"),
            {FinalNames, FinalPids, FinalGames} = start_game(QueueNames, QueuePids, Games, 3),
            loop(FinalNames,FinalPids,FinalGames,undefined);
        %Avisar o mastchmaker que um jogo terminou, ou seja no caso de isto estar cheio pode voltar a tentar encher um servidor
        {game_finished, GameId} ->
            NewGames = maps:remove(GameId, Games),
            {FinalQueue, FinalPids, FinalGames} = start_game(QueueNames, QueuePids ,NewGames,4), %[TRIGGER] pode acontecer um novo jogo
            loop(FinalQueue,FinalPids, FinalGames, Timer)
    end.




%Começar jogos
start_game(QueueNames,QueuePids,Games, MinJogadores) ->
    case {length(QueueNames) >= MinJogadores, maps:size(Games) < 4} of % min de jogadores: 3 e max de salas: 4

        {true, true} ->
            N = case length(QueueNames) >= 4 of true -> 4; false -> 3 end,

            SelectedNames = lists:sublist(QueueNames, N), 
            SelectedPids  = lists:sublist(QueuePids, N), %%%%
            SelectedPids  = lists:sublist(QueuePids, N), 

            RestNames = lists:nthtail(N, QueueNames), 
            RestPids  = lists:nthtail(N, QueuePids), %%%%%
            RestPids  = lists:nthtail(N, QueuePids), 

            GameId = make_ref(),

            %depois há que ligar isto ao cenas que vai fazer a comunicação entre o client e o servidor
            io:format("Novo jogo encontrado (~p) com jogadores: ~p~n", [GameId, SelectedNames]),

            NewGames = maps:put(GameId, SelectedPids, Games),

            %tenta criar mais jogos recursivamente
            start_game(RestNames, RestPids ,NewGames, 4);

        _ ->
            {QueueNames, QueuePids,Games}
    end.



%Escolher jogadores para entrarem no mapa
%pick player to play
% pptp(Queue) -> %isto aqui entra sempre quando a condiçao de start_game é TRUE
%     case length(Queue) >= 4 of %isto ta meio javardo mas funciona bem
%         true ->
%             {lists:sublist(Queue, 4), lists:nthtail(4, Queue)};
%         false ->
%             {lists:sublist(Queue, 3), lists:nthtail(3, Queue)}
%     end.

% nome precisa de ser mudado
remove_player(Username, Names, Pids) ->
    remove_player(Username, Names, Pids, [], []).

remove_player(_, [], [], NewNames, NewPids) ->
    {lists:reverse(NewNames), lists:reverse(NewPids)};
remove_player(Username, [Name|RestNames], [Pid|RestPids], AccNames, AccPids) ->
    if
        Name =:= Username ->
            remove_player(Username, RestNames, RestPids, AccNames, AccPids);
        true ->
            remove_player(Username, RestNames, RestPids, [Name|AccNames], [Pid|AccPids])
    end. 