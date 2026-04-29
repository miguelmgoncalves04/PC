-module(matchmaker).
-export([start/0]).

start() ->
    spawn(fun() -> loop([], #{}) end).
% PID: Matchmaker_PID


loop(QNamesPids , Games) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            % if username in queue
            case lists:any(fun({_,Pid})-> Pid =:= From end , QNamesPids) of
                true ->
                    From ! {error, already_in_queue},
                    loop(QNamesPids, Games); 
                false ->
                    NewQueue = QNamesPids ++ [{Username,From}],
                    From ! ok,
                    %[TRIGGER] pode acontecer um novo jogo
                    {FinalQueue, FinalGames} = start_game(NewQueue, Games),
                    loop(FinalQueue, FinalGames)
            end;
        %Conas sai da fila
        {leave_queue, From, _} ->
            case lists:any(fun({_,Pid})-> Pid =:= From end , QNamesPids) of
                true ->
                    NewQueue = lists:filter(fun({_,Pid})-> Pid =/= From end,QNamesPids),
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
start_game(QNamesPids,Games) ->
    case {length(QNamesPids) >= 3, maps:size(Games) < 4} of % min de jogadores: 3 e max de salas: 4

        {true, true} ->
            N = case length(QNamesPids) >= 4 of true -> 4; false -> 3 end,

            SelectedPlayers = lists:sublist(QNamesPids, N),  
            RestPlayers = lists:nthtail(N, QNamesPids), 

            GamePid = game_session:start(SelectedPlayers, self()),

            % GameId = make_ref(), tinha isto dantes mas acho melhor usar o GamePid simpelsmente porque depois vamos ter problemas ao remover a partida do mapa. Tipo o game_session vai mandar um {game_finished, self()} (acho sem ver) e aqui o self vai ser o GamePid.E como a chave do mapa é o GamePid assim remove diretamente, se fosse um makeref() seria outro pid e acho que iam tipo encher que no caso acho que pelo enunciado so pode ter 4 partidas ou algo assim. Por isso mudei isso mas posso so tar a trollar mb se tiver mas assim é 100% que funciona.
            
            %depois há que ligar isto ao cenas que vai fazer a comunicação entre o client e o servidor 
            SelectedPids=[Pid || {_,Pid}<-SelectedPlayers],
            [Pid ! {matchmaker, {game_start, GamePid}} || Pid <- SelectedPids],
            SelectedNames = [Name || {Name, _} <- SelectedPlayers],
            io:format("Novo jogo (~p) com jogadores: ~p~n", [GamePid, SelectedNames]),

            NewGames = maps:put(GamePid, SelectedPlayers, Games),

            %tenta criar mais jogos recursivamente
            start_game(RestPlayers ,NewGames);
        _ ->
            {QNamesPids, Games}
    end.



