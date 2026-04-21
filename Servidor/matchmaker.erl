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
    spawn(fun() -> loop([], #{}) end).



join_queue(Pid, Username) ->  % PID: SERVER_PID
    Pid ! {join_queue, self(), Username},
    receive Response -> Response end.

leave_queue(Pid, Username) ->  % PID: SERVER_PID
    Pid ! {leave_queue, self(), Username},
    receive Response -> Response end.

loop(QueueNames, QueuePids, Games) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            case lists:member(Username,Queue) of % if username in queue
                true ->
                    From ! {error, already_in_queue},
                    loop(QueueNames, QueuePids, Games);
                false ->
                    NewNames = QueueNames ++ [Username],
                    NewPids  = QueuePids ++ [From],
                    From ! ok,
                    {FinalQueue, FinalGames} = start_game(NewQueue, Games),  %[TRIGGER] pode acontecer um novo jogo
                    loop(FinalQueue, FinalGames)
            end;
        %Conas sai da fila
        {leave_queue, From, Username} ->
            case lists:member(Username, QueueNames) of
                true ->
                    {NewNames, NewPids} = remove_player(Username, QueueNames, QueuePids),
                    From ! ok,
                    loop(NewNames, NewPids, Games);
                false ->
                    From ! ok,
                    loop(QueueNames, QueuePids, Games)
            end;
        %Avisar o mastchmaker que um jogo terminou, ou seja no caso de isto estar cheio pode voltar a tentar encher um servidor
        {game_finished, GameId} ->
            NewGames = maps:remove(GameId, Games),
            {FinalQueue, FinalGames} = start_game(Queue, NewGames), %[TRIGGER] pode acontecer um novo jogo
            loop(FinalQueue, FinalGames)
    end.




%Começar jogos
start_game(Queue, Games) ->
    case {length(Queue) >= 3, maps:size(Games) < 4} of % min de jogadores: 3 e max de salas: 4

        {true, true} ->
            N = case length(QueueNames) >= 4 of true -> 4; false -> 3 end,
            SelectedNames = lists:sublist(QueueNames, N), 
            SelectedPids  = lists:sublist(QueuePids, N), 
            RestNames = lists:nthtail(N, QueueNames), 
            RestPids  = lists:nthtail(N, QueuePids), 

            %depois há que ligar isto ao cenas que vai fazer a comunicação entre o client e o servidor
            io:format("Novo jogo encontrado (~p) com jogadores: ~p~n", [GameId, Players]),

            NewGames = maps:put(GameId, Players, Games),

            %tenta criar mais jogos recursivamente
            start_game(RestQueue, NewGames);

        _ ->
            {Queue, Games}
    end.




%Escolher jogadores para entrarem no mapa
take_players(Queue) -> %isto aqui entra sempre quando a condiçao de start_game é TRUE
    case length(Queue) >= 4 of %isto ta meio javardo mas funciona bem
        true ->
            {lists:sublist(Queue, 4), lists:nthtail(4, Queue)};
        false ->
            {lists:sublist(Queue, 3), lists:nthtail(3, Queue)}
    end.