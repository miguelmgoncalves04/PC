%ALTERAÇÕES:

% Apenas vejam o final comentado

%Comit todo que dei:
% Neste commit que dei apenas mexi no client_handler e no game_session e no main.pde

% Ahh e zezinho tu tinhas dito que n conseguias abrir mais que um pde porque dava erros.
% Eu se abro os 3 com a aplicação do processing consigo rodar sem erros.
% no Vs_code aparece tudo sublinhado ns porque
% Tipo eu simplesmente abri o main2 main3 main4 em abas diferentes no processing e consegui rodar olha tenta




% segundo commit:

% tá a ir para a tela de jogo e a comunição rá certinha e isso.
% claro que fiz muita coisa com o chat como é obvio, mas tentei mudar o menos de coisa possivel e como tá a funcionar acho que tá safe
% acho que agora seria criar um outro processo tipo top_pontuações para n se tar a mecher já na fisica n?
% top_pontuações guarda uma lista tipo dos vencedores e as pontuações de cada um 
% e tipo quando o matchmaker recebe "A partida acabou" o game_session ou o matchamler memo calcula o vencedor e manda ao top_pontuações ou algo assim 

% Tbm se pode por o mathmaker a esperar uns 5s para ver se entra um 4 jogador antes disso

% E depois é fazer a fisica do joguinho



-module(game_session).
-export([start/2, send_input/3]).

% Players = [{Username, Pid}]
start(Players, MatchmakerPid) ->
    spawn(fun() -> init(Players, MatchmakerPid) end). % com spawn corre em paralelo tava a dar problemas

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
                    % Enviar game_over a todos os jogadores
                    Players = maps:get(players, UpdatedState),
                    [ Pid ! {game_over, self()} || {_, #{pid := Pid}} <- maps:to_list(Players) ],
                    MatchmakerPid ! {game_finished, self()};
                false ->
                    loop(UpdatedState, MatchmakerPid)
            end
    end.

% CORREÇÃO 1: init_players agora devolve um MAPA, não uma lista.
init_players(Players) ->
    lists:foldl(                    % eu sempre tive difculdade em usar foldl e foldr, mas tem de ser porque tava a crashar, dantes lists:map devolvia uma lista {Username, PData} e com lists:foldl devolve um mapa #{Username => PData}, broadcaste e ssas funcoes todas que tinhamos usavam maps:find e cenas assim por isso é preciso 
        fun({Username, Pid}, AccMap) ->
            Mass = 10.0,
            PData = #{
                pos => {rand:uniform() * 500, rand:uniform() * 500},  % Mudei isto tbm
                vel => {0.0, 0.0},
                angle => 0.0,
                ang_vel => 0.0,
                mass => Mass,
                torque => 2.13,
                force => 4.23,
                score => 0,
                radius => math:sqrt(Mass / math:pi()),   % guardamos o raio para o futuro
                pid => Pid
            },
            maps:put(Username, PData, AccMap)
        end,
        #{},
        Players
    ).

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

% adaptei o encode_state para o formato que o cliente espera (Nome,x,y,ângulo|Nome...)
encode_state(State) ->
    Players = maps:get(players, State),
    PlayerList = maps:to_list(Players),
    EncodePlayers = lists:map(
        fun({Username, PData}) ->
            {X, Y} = maps:get(pos, PData),
            Angle = maps:get(angle, PData),
            UsernameStr = binary_to_list(Username),
            io_lib:format("~s,~f,~f,~f", [UsernameStr, float(X), float(Y), float(Angle)])
        end,
        PlayerList
    ),
    PlayersString = lists:join("|", EncodePlayers),
    list_to_binary(PlayersString ++ "\n").

% NOVO: update agora aplica movimento e limites
update(State) ->
    State1 = move_players(State),
    State2 = apply_boundaries(State1),
    State2.

move_players(State) ->
    Players = maps:get(players, State),
    NewPlayers = maps:map(fun(_Username, PData) ->
        {X, Y} = maps:get(pos, PData),
        {Vx, Vy} = maps:get(vel, PData),
        Angle = maps:get(angle, PData),
        AngVel = maps:get(ang_vel, PData),
        PData#{
            pos   => {X + Vx, Y + Vy},
            angle => Angle + AngVel
        }
    end, Players),
    maps:put(players, NewPlayers, State).

% NOVO: limites do mapa (0‑800 x 0‑600), o clamp é para quando atigir as bordas por a velocidade a 0
apply_boundaries(State) ->
    Players = maps:get(players, State),
    NewPlayers = maps:map(fun(_Username, PData) ->
        {X, Y} = maps:get(pos, PData),
        {Vx, Vy} = maps:get(vel, PData),
        {NewX, NewVx} = clamp(X, 0.0, 800.0, Vx),
        {NewY, NewVy} = clamp(Y, 0.0, 600.0, Vy),
        PData#{
            pos => {float(NewX), float(NewY)},
            vel => {float(NewVx), float(NewVy)}
        }
    end, Players),
    maps:put(players, NewPlayers, State).

clamp(Val, Min, Max, _Vel) when Val < Min -> {float(Min), 0.0};
clamp(Val, Min, Max, _Vel) when Val > Max -> {float(Max), 0.0};
clamp(Val, _, _, Vel) -> {float(Val), float(Vel)}.

%envia o estado atual do jogo a todos os jogadores
broadcast(State) ->
    Players = maps:get(players, State),
    Json = encode_state(State),
    lists:foreach(
        fun({_Username, Data}) ->
            Pid = maps:get(pid, Data),
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