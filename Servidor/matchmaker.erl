-module(matchmaker).
-export([start/0]).

start() ->
    spawn(fun() -> loop([], #{}) end).
% PID: Matchmaker_PID

loop(QNamesPids, Games) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            % if username in queue
            case lists:any(fun({_, Pid}) -> Pid =:= From end, QNamesPids) of
                true ->
                    From ! {error, already_in_queue},
                    loop(QNamesPids, Games);
                false ->
                    NewQueue = QNamesPids ++ [{Username, From}],
                    From ! ok,
                    %[TRIGGER] pode acontecer um novo jogo
                    {FinalQueue, FinalGames} = start_game(NewQueue, Games),
                    loop(FinalQueue, FinalGames)
            end;
        %Conas sai da fila
        {leave_queue, From, _} ->
            case lists:any(fun({_, Pid}) -> Pid =:= From end, QNamesPids) of
                true ->
                    NewQueue = lists:filter(fun({_, Pid}) -> Pid =/= From end, QNamesPids),
                    From ! ok,
                    loop(NewQueue, Games);
                false ->
                    From ! ok,
                    loop(QNamesPids, Games)
            end;
        %Avisar o mastchmaker que um jogo terminou, ou seja no caso de isto estar cheio pode voltar a tentar encher um servidor
        {game_finished, GameId} ->
            NewGames = maps:remove(GameId, Games),
            %[TRIGGER] pode acontecer um novo jogo
            {FinalQueue, FinalGames} = start_game(QNamesPids, NewGames),
            loop(FinalQueue, FinalGames)
    end.

%Começar jogos
start_game(QNamesPids, Games) ->
    % min de jogadores: 3 e max de salas: 4
    case {length(QNamesPids) >= 3, maps:size(Games) < 4} of
        {true, true} ->
            N =
                case length(QNamesPids) >= 4 of
                    true -> 4;
                    false -> 3
                end,

            SelectedPlayers = lists:sublist(QNamesPids, N),
            RestPlayers = lists:nthtail(N, QNamesPids),

            ValidPlayers = lists:filter(
                fun({_, Pid}) -> is_process_alive(Pid) end, SelectedPlayers
            ),

            case length(ValidPlayers) >= 3 of
                false ->
                    InvalidPlayers = SelectedPlayers -- ValidPlayers,
                    io:format("Jogadores mortos removidos: ~p~n", [InvalidPlayers]),
                    start_game(ValidPlayers ++ RestPlayers, Games);
                true ->
                    GamePid = game_session:start(ValidPlayers, self()),
                    SelectedPids = [Pid || {_, Pid} <- ValidPlayers],
                    [Pid ! {matchmaker, {game_start, GamePid}} || Pid <- SelectedPids],
                    SelectedNames = [Name || {Name, _} <- ValidPlayers],
                    io:format("Novo jogo (~p) com jogadores: ~p~n", [GamePid, SelectedNames]),
                    NewGames = maps:put(GamePid, ValidPlayers, Games),
                    start_game(RestPlayers, NewGames)
            end;
        _ ->
            {QNamesPids, Games}
    end.
