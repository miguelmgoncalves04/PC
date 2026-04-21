-module(ut_manager).
-export([start/0, register_usr/3, login_usr/3, unregister_usr/2]).

start() ->
    spawn(fun() -> loop(#{} , #{}) end).



register_usr(Pid, Username, Password) ->
    Pid ! {register_usr, self(), Username, Password},
    receive
        Response -> Response
    end.

login_usr(Pid, Username, Password) ->
    Pid ! {login_usr, self(), Username, Password},
    receive
        Response -> Response
    end.

unregister_usr(Pid, Username) ->
    Pid ! {unregister_usr, self(), Username},
    receive
        Response -> Response
    end.



loop(Users, Logged) ->
    receive

        %% Criar conta
        {register_usr, From, Username, Password} ->
            case maps:is_key(Username, Users) of
                true ->
                    From ! {error, user_exists},
                    loop(Users, Logged);

                false ->
                    NewUsers = maps:put(Username, Password, Users),
                    From ! ok,
                    loop(NewUsers, Logged)
            end;

        %% Utilizador faz login
        {login_usr, From, Username, Password} ->
            case maps:find(Username, Users) of
                error ->
                    From ! {error, user_not_found},
                    loop(Users, Logged);

                {ok, StoredPass} ->
                    case StoredPass =:= Password of
                        false ->
                            From ! {error, wrong_password},
                            loop(Users, Logged);

                        true ->
                            case maps:is_key(Username, Logged) of
                                true ->
                                    From ! {error, already_logged},
                                    loop(Users, Logged);

                                false ->
                                    NewLogged = maps:put(Username, true, Logged),
                                    From ! ok,
                                    loop(Users, NewLogged)
                            end
                    end
            end;

        %% cancelar o registo do tropa
        {unregister_usr, From, Username} ->
            case maps:is_key(Username, Users) of
                true ->
                    NewUsers = maps:remove(Username, Users),
                    NewLogged = maps:remove(Username,Logged),
                    From ! ok,
                    loop(NewUsers, NewLogged);
                false ->
                    From ! {error,user_not_found},
                    loop(Users, Logged)
            end
    end.