-module(matchmaker).
-export([start/0, join_queue/2, leave_queue/2]).


start() ->
    spawn(fun() -> loop([], [], #{}) end).

% PID: Matchmaker_PID
join_queue(M_Pid, Username) ->
    M_Pid ! {join_queue, self(), Username},
    receive
        Response -> Response
    end.

% PID: Matchmaker_PID
leave_queue(M_Pid, Username) ->
    M_Pid ! {leave_queue, self(), Username},
    receive
        Response -> Response
    end.

loop(QueueNames, QueuePids, Games) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            % if username in queue
            case lists:member(Username, QueueNames) of
                true ->
                    From ! {error, already_in_queue},
                    loop(QueueNames, QueuePids, Games);
                false ->
                    NewNames = QueueNames ++ [Username],
                    NewPids = QueuePids ++ [From],
                    From ! ok,
                    %[TRIGGER] pode acontecer um novo jogo
                    {FinalQueue, FinalPids, FinalGames} = start_game(NewNames, NewPids, Games),
                    loop(FinalQueue, FinalPids, FinalGames)
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
            %[TRIGGER] pode acontecer um novo jogo
            {FinalQueue, FinalPids, FinalGames} = start_game(QueueNames, QueuePids, NewGames),
            loop(FinalQueue, FinalPids, FinalGames)
    end.

%Começar jogos
start_game(QueueNames,QueuePids,Games) ->
    case {length(QueueNames) >= 3, maps:size(Games) < 4} of % min de jogadores: 3 e max de salas: 4

        {true, true} ->
            N = case length(QueueNames) >= 4 of true -> 4; false -> 3 end,

            SelectedNames = lists:sublist(QueueNames, N), 
            SelectedPids  = lists:sublist(QueuePids, N), 

            RestNames = lists:nthtail(N, QueueNames), 
            RestPids  = lists:nthtail(N, QueuePids), 

            GameId = make_ref(),
            %depois há que ligar isto ao cenas que vai fazer a comunicação entre o client e o servidor
            io:format("Novo jogo encontrado (~p) com jogadores: ~p~n", [GameId, SelectedNames]),

            NewGames = maps:put(GameId, SelectedPids, Games),

            %tenta criar mais jogos recursivamente
            start_game(RestNames, RestPids ,NewGames);
        _ ->
            {QueueNames, QueuePids, Games}
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
remove_player(Username, [Name | RestNames], [Pid | RestPids], AccNames, AccPids) ->
    if
        Name =:= Username ->
            remove_player(Username, RestNames, RestPids, AccNames, AccPids);
        true ->
            remove_player(Username, RestNames, RestPids, [Name | AccNames], [Pid | AccPids])
    end.
