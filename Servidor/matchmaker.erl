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
    spawn(fun() -> loop([], [], #{}) end).

join_queue(Pid, Username) ->
    Pid ! {join_queue, self(), Username},
    receive Response -> Response end.

leave_queue(Pid, Username) ->
    Pid ! {leave_queue, self(), Username},
    receive Response -> Response end.

loop(QueueNames, QueuePids, Games) ->
    receive
        % Jogador entra na fila
        {join_queue, From, Username} ->
            case lists:member(Username, QueueNames) of
                true ->
                    From ! {error, already_in_queue},
                    loop(QueueNames, QueuePids, Games);
                false ->
                    NewNames = QueueNames ++ [Username],
                    NewPids  = QueuePids ++ [From],
                    From ! ok,
                    {FinalNames, FinalPids, FinalGames} = start_game(NewNames, NewPids, Games),
                    loop(FinalNames, FinalPids, FinalGames)
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
        {game_finished, GamePid} ->
            NewGames = maps:remove(GamePid, Games),
            {FinalNames, FinalPids, FinalGames} = start_game(QueueNames, QueuePids, NewGames),
            loop(FinalNames, FinalPids, FinalGames)
    end.


% isto aqui foi mais chat que eu, tentei fazer igual ao que o stor fez na aula n consegui e mandei ao chat xd
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

% Mas faz sentido e tenho quase acerteza que tá certo por isso fds.Imaginando que tá no fim ele vai adiconando as merdas a uma lista
% até chegar ao nome que quer e depois simplesmente n adiciona esse e depois dá a lista inversa para ficar igual ao que tinha
% no inicio. Isto deve é cansar o pc todo mas q sa foda que o do taveira roda Minecraft por isso tá safe

%Começar jogos
start_game(QueueNames, QueuePids, Games) ->
    case {length(QueueNames) >= 3, maps:size(Games) < 4} of
        {true, true} ->
            N = case length(QueueNames) >= 4 of true -> 4; false -> 3 end,
            SelectedNames = lists:sublist(QueueNames, N), 
            SelectedPids  = lists:sublist(QueuePids, N), 
            RestNames = lists:nthtail(N, QueueNames), 
            RestPids  = lists:nthtail(N, QueuePids), 

            %depois há que ligar isto ao cenas que vai fazer a comunicação entre o client e o servidor
            io:format("Novo jogo encontrado com jogadores: ~p~n", [SelectedNames]),

            %esta parte simpplesmente cria o processo que vai executar o game_stud que é onde vai acontecer a maior parte das merdas
            % tipo o jogo em si, as colisoes e isso que vamos ter de criar, neste momento a unica coisa que faz é esperar 120000 
            % milesegundos que é 2m como no enunciado diz quanto demora uma partida

            GamePid = spawn(fun() -> game_stub(SelectedPids) end),

            % isto aqui foi a imitar o stor deve dar para fazer com um while mas é tipo para cada pid em SelectedPids (os clientes
            % que vao jogar) manda uma mensagem a dizer que a partida começou junto com o pid da partida
            [Pid ! {matchmaker, {game_start, GamePid}} || Pid <- SelectedPids],

            NewGames = maps:put(GamePid, {SelectedNames, SelectedPids}, Games),

            start_game(RestNames, RestPids, NewGames);
        _ ->
            {QueueNames, QueuePids, Games}
    end.

% funcao que anda para frente verifica colisoes e essas merdas todas
game_stub(_Pids) ->
    receive
        stop -> ok
    after 120000 ->
        matchmaker ! {game_finished, self()}
    end.