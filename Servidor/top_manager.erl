-module(top_manager).
-export([start/0, add_winner/2, get_top/0]).

start() ->
    Pid = spawn(fun() -> loop([]) end),
    register(?MODULE, Pid).

add_winner(Username, Score) ->
    ?MODULE ! {add_winner, Username, Score}.

get_top() ->
    ?MODULE ! {get_top, self()},
    receive {top, List} -> List end.

%% Loop principal do processo top_manager
loop(Scores) ->
    receive
        %% Recebe um novo vencedor para adicionar/atualizar
        {add_winner, Username, Score} ->
            % Substitui o par {Username, Score} se já existir, senão adiciona
            NewScores = lists:keystore(Username, 1, Scores, {Username, Score}),
            loop(NewScores);

        %% Recebe um pedido do top atual
        {get_top, From} ->
            % Ordena por score decrescente (keysort pelo segundo elemento, depois inverte)
            Sorted = lists:reverse(lists:keysort(2, Scores)),
            From ! {top, Sorted},              % envia a lista ordenada de volta
            loop(Scores)
    end.