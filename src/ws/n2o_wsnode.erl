-module(n2o_wsnode).
-include("n2o.hrl").
-compile(export_all).

send(C,M) -> C ! M.

proc(init,#pi{name=Name}=Async) -> n2o:reg(Name), {ok,Async#pi{state=application:get_env(n2o,proto,n2o_proto)}};

proc({publish, C, Token, Request}, State = #pi{name=Server,state=Module}) ->
    Ctx = #cx { session= n2o:to_binary(Token), node=Server,
                client_pid=C, state=application:get_env(kvx,dba,[]) },
    put(context, Ctx),
    Return = case n2o_proto:try_info(Module,Request,[],Ctx) of
             {reply,{_,      <<>>},_,_} -> skip;
             {reply,{text,   Text},_,_} -> {ok,send(C,{flush,Text})};
             {reply,{bert,   Term},_,_} -> {ok,send(C,n2o_bert:encode(Term))};
             {reply,{json,   Term},_,_} -> {ok,send(C,n2o_json:encode(Term))};
             {reply,{binary, Term},_,_} -> {ok,send(C,Term)};
             {reply,{default,Term},_,_} -> {ok,send(C,n2o:encode(Term))};
             {reply,{Encoder,Term},_,_} -> {ok,send(C,Encoder:encode(Term))};
                                  Reply -> {error,{"Invalid Return",Reply}} end,
    {reply, Return, State};

proc(Unknown,#pi{name=Name}=Async) ->
    io:format("UNKNOWN ~p: ~p~n",[Name,Unknown]),
    {reply,{uknown,Unknown,0},Async}.
