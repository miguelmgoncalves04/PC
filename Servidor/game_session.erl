%ALTERAÇÕES:

% Apenas vejam o final comentado

%Comit todo que dei:
% Neste commit que dei apenas mexi no client_handler e no game_session e no main.pde

% Ahh e zezinho tu tinhas dito que n conseguias abrir mais que um pde porque dava erros.
% Eu se abro os 3 com a aplicação do processing consigo rodar sem erros.
% no Vs_code aparece tudo sublinhado ns porque
% Tipo eu simplesmente abri o main2 main3 main4 em abas diferentes no processing e consegui rodar olha tenta

-module(game_session).
-export([start/2, send_input/3]).

% Players = [{Username, Pid}]
start(Players, MatchmakerPid) ->
    init(Players, MatchmakerPid).

% API para receber input (do client_handler depois) perfeito
send_input(GamePid, Username, Input) ->
    GamePid ! {input, Username, Input}.

%Cria um jogo novo. Cria cada jogo como sondo único com um GameId único através da função make_ref
init(Players, MatchmakerPid) ->
    GameId = make_ref(),
    io:format("Game ~p started with players: ~p~n", [GameId, Players]),
    State = #{
        id => GameId,
        players => init_players(Players),
        start_time => erlang:monotonic_time(second)
    },

    % agora os ticks sao um timer interno do erlang
    erlang:send_after(50, self(), update_tick),
    loop(State, MatchmakerPid).

loop(State, MatchmakerPid) ->
    receive
        {input, Username, Command} ->
            NewState = handle_input(State, Username, Command),
            loop(NewState, MatchmakerPid);
    update_tick ->  %% ~20 FPS ////
        erlang:send_after(50, self(), update_tick),
        Now   = erlang:monotonic_time(second),
        Start = maps:get(start_time, State),
        UpdatedState = update(State),
        broadcast(UpdatedState),
        case Now - Start >= 120 of
            true ->
                io:format("Game ~p finished~n", [maps:get(id, State)]),
                MatchmakerPid ! {game_finished, self()};
            false ->
                loop(UpdatedState, MatchmakerPid)
        end
    end.

%recebe uma lista de jogadores e inicializa o estado fisico de cada um com os atributos abaixo
init_players(Players) ->
    lists:map(
        fun({Username, Pid}) ->
            {Username, #{
                pos => {float(rand:uniform(500)), float(rand:uniform(500))},
                vel => {0.0, 0.0},
                % direcao para onde esta voltado (radianos)
                angle => 0.0,
                % velocidade angular atual
                ang_vel => 0.0,
                mass => 10.0,
                % define aceleracao angular
                torque => 2.13,
                % define aceleracao linear
                force => 4.23,
                score => 0,
                pid => Pid
            }}
        end,
        Players
    ).

%FEITA PELO AMIGO, NAO SEI SE ESTÁ CERTO
% O input apenas altera velocidades (nao posicao diretamente).
% A posicao e atualizada no update/1 a cada tick.
%
% left/right -> aceleracao angular (inversamente proporcional a massa)
% forward    -> aceleracao linear na direcao do angulo atual
handle_input(State, Username, Command) ->
    Players = maps:get(players, State),
    case maps:find(Username, Players) of
        error ->
            State;
        {ok, PData} ->
            Mass = maps:get(mass, PData),
            Torque = maps:get(torque, PData),
            Force = maps:get(force, PData),
            Angle = maps:get(angle, PData),
            {Vx, Vy} = maps:get(vel, PData),
            AngVel = maps:get(ang_vel, PData),

            NewPData =
                case Command of
                    left ->
                        AngAcc = Torque / Mass,
                        maps:put(ang_vel, AngVel - AngAcc, PData);
                    right ->
                        AngAcc = Torque / Mass,
                        maps:put(ang_vel, AngVel + AngAcc, PData);
                    forward ->
                        LinAcc = Force / Mass,
                        NewVx = Vx + LinAcc * math:cos(Angle),
                        NewVy = Vy + LinAcc * math:sin(Angle),
                        maps:put(vel, {NewVx, NewVy}, PData);
                    _ ->
                        PData
                end,

            NewPlayers = maps:put(Username, NewPData, Players),
            maps:put(players, NewPlayers, State)
    end.

encode_state(State)->
    Players=maps:get(players,State),
    PlayerList=maps:to_list(Players),
    EncodePlayers= lists:map(fun({Username,PData})->
        {X, Y} = maps:get(pos,PData),
        {Vx, Vy} = maps:get(vel, PData),
        Angle = maps:get(angle,PData),
        Massa = maps:get(mass,PData),
        Score = maps:get(score,PData),
        io_lib:format(
            "{\"username\":\"~s\",\"x\":~f,\"y\":~f,\"vx\":~f,\"vy\":~f,\"angle\":~f,\"mass\":~f,\"score\":~B}",
            [Username, X, Y, Vx, Vy, Angle, Massa, Score]
        )
        end,PlayerList),
        PlayersJson=lists:join(",",EncodePlayers),
        lists:flatten(io_lib:format("{\"players\":[~s]}\n",[PlayersJson])).



% A cada tick(50 MS) aplica as velocidades ao estado de cada jogador. 👅👅👅👅
% Aqui depois tambem entram colisoes, limites do mapa, etc.
update(State) ->
    Players = maps:get(players, State),
    NewPlayers = maps:map(fun(_Username, PData) ->
        {X, Y}   = maps:get(pos, PData),
        {Vx, Vy} = maps:get(vel, PData),
        Angle    = maps:get(angle, PData),
        AngVel   = maps:get(ang_vel, PData),
        PData#{
            pos   => {X + Vx, Y + Vy},
            angle => Angle + AngVel
        }
    end, Players),
    maps:put(players, NewPlayers, State).

%envia o estado atual do jogo a todos os jogadores

%% isto está muito certo muito bem
broadcast(State) ->
    Players = maps:get(players, State),
    Json = encode_state(State),
    lists:foreach(
        fun({_Username, Data}) ->
            Pid = maps:get(pid, Data),
            %isto aqui é o pid de cada jogador esta
            Pid ! {game_update, Json}
        end,
        maps:to_list(Players)
    ).

















%%%%%% Ok, então este game_session é apenas um para saber se está tudo a comunicar certinho. 
%%%Para tipo ter acerteza que os comandos estão a ser enviados certinho e esse tipo de cenas.
%%% Se quiserem testar o trabalho podem simplesmente tirar os comentarios disto e verificam que com 3 clientes ele está a receber
%%% as mensagens certo e a ir para a tela de jogo, agora é fazer a parte fdd que é a fisica do jogo e isso
%%% Eu vou trabalhar nisso agora e ver tbm se coonsigo por a fisica do jogo a funcionar com a ajuda do meu amigo.

% Mas prontos pelo menos a comunicação tá a funcionar direito por isso tá safe.

%-module(game_session).
%-export([start/2, send_input/3]).
%
%start(Players, MatchmakerPid) ->
%    spawn(fun() -> simple_game_loop(Players, MatchmakerPid) end).
%
%send_input(GamePid, Username, Input) ->
%    GamePid ! {input, Username, Input}.
%
%simple_game_loop(Players, MatchmakerPid) ->
%    receive
%        {input, Username, Command} ->
%            % Cria uma mensagem JSON simples com o comando
%            Json = io_lib:format(
%                "{\"player\":\"~s\",\"command\":\"~s\"}\n",
%                [Username, Command]
%            ),
%            % Players vem do matchmaker como [{Username, Pid}]
%            [Pid ! {game_update, Json} || {_, Pid} <- Players],
%            simple_game_loop(Players, MatchmakerPid);
%        _ ->
%            simple_game_loop(Players, MatchmakerPid)
%    after 30000 ->   % termina ao fim de 30 segundos
%        [Pid ! {game_over, self()} || {_, Pid} <- Players],
%        MatchmakerPid ! {game_finished, self()}
%    end.