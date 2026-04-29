%ALTERAÇÕES:

%Só adicionei um ";" na linha 31 xd

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
        id         => GameId,
        players    => init_players(Players),
        start_time => erlang:monotonic_time(second)
    },

    erlang:send_after(50, self(), update_tick), % agora os ticks sao um timer interno do erlang
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
                loop(UpdatedState, MatchmakerPid);
        end
    end.

%recebe uma lista de jogadores e inicializa o estado fisico de cada um com os atributos abaixo
init_players(Players) ->
    lists:map(fun({Username, Pid}) ->
        {Username, #{
            pos     => {float(rand:uniform(500)), float(rand:uniform(500))},
            vel     => {0.0, 0.0},
            angle   => 0.0,    % direcao para onde esta voltado (radianos)
            ang_vel => 0.0,    % velocidade angular atual
            mass    => 10.0,
            torque  => 2.13,   % define aceleracao angular
            force   => 4.23,   % define aceleracao linear
            score   => 0,
            pid     => Pid
        }}
    end, Players).

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
            Mass   = maps:get(mass, PData),
            Torque = maps:get(torque, PData),
            Force  = maps:get(force, PData),
            Angle  = maps:get(angle, PData),
            {Vx, Vy} = maps:get(vel, PData),
            AngVel   = maps:get(ang_vel, PData),

            NewPData = case Command of
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
broadcast(State) -> %% isto está muito certo muito bem
    Players = maps:get(players, State),
    lists:foreach(fun({_Username, Data}) ->
        Pid = maps:get(pid, Data),
        Pid ! {game_update, State} %isto aqui é o pid de cada jogador esta
    end, maps:to_list(Players)).





