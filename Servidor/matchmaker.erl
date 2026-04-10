-module(matchmaker).
-export([start/0, join_queue/2, leave_queue/2]).

start() ->
    spawn(fun() -> loop([], #{}) end).



join_queue(Pid, Username) ->
    Pid ! {join_queue, self(), Username},
    receive
        Response -> Response
    end.

leave_queue(Pid, Username) ->
    Pid ! {leave_queue, self(), Username},
    receive
        Response -> Response
    end.


loop(Queue, Games) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            case lists:member(Username,Queue) of
                true ->
                    From ! {error, already_in_queue},
                    loop(Queue, Games);
                false ->
                    NewQueue = Queue ++ [Username],
                    From ! ok,
                    {FinalQueue, FinalGames} = start_game(NewQueue, Games),
                    loop(FinalQueue, FinalGames)
            end;
        %Conas sai da fila
        {leave_queue, From, Username} ->
            NewQueue = lists:delete(Username, Queue),
            From ! ok,
            loop(NewQueue, Games);
        %Avisar o mastchmaker que um jogo terminou, ou seja no caso de isto estar cheio pode voltar a tentar encher um servidor
        {game_finished, GameId} ->
            NewGames = maps:remove(GameId, Games),
            {FinalQueue, FinalGames} = start_game(Queue, NewGames),
            loop(FinalQueue, FinalGames)
    end.




%Começar jogos
start_game(Queue, Games) ->
    case {length(Queue) >= 3, maps:size(Games) < 4} of

        {true, true} ->
            {Players, RestQueue} = take_players(Queue),
            GameId = make_ref(),

            %depois há que ligar isto ao cenas que vai fazer a comunicação entre o client e o servidor
            io:format("Novo jogo encontrado (~p) com jogadores: ~p~n", [GameId, Players]),

            NewGames = maps:put(GameId, Players, Games),

            %tenta criar mais jogos recursivamente
            start_game(RestQueue, NewGames);

        _ ->
            {Queue, Games}
    end.




%Escolher jogadores para entrarem no mapa
take_players(Queue) ->
    case length(Queue) >= 4 of
        true ->
            {lists:sublist(Queue, 4), lists:nthtail(4, Queue)};
        false ->
            {lists:sublist(Queue, 3), lists:nthtail(3, Queue)}
    end.