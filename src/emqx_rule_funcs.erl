%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(emqx_rule_funcs).

%% IoT Funcs
-export([ msgid/0
        , qos/0
        , flags/0
        , flag/1
        , headers/0
        , header/1
        , topic/0
        , topic/1
        , clientid/0
        , clientip/0
        , username/0
        , payload/0
        , payload/1
        , timestamp/0
        ]).

%% Arithmetic Funcs
-export([ '+'/2
        , '-'/2
        , '*'/2
        , '/'/2
        , 'div'/2
        , mod/2
        ]).

%% Math Funcs
-export([ abs/1
        , acos/1
        , acosh/1
        , asin/1
        , asinh/1
        , atan/1
        , atanh/1
        , ceil/1
        , cos/1
        , cosh/1
        , exp/1
        , floor/1
        , fmod/2
        , log/1
        , log10/1
        , log2/1
        , power/2
        , round/1
        , sin/1
        , sinh/1
        , sqrt/1
        , tan/1
        , tanh/1
        ]).

%% Bits Funcs
-export([ bitnot/1
        , bitand/2
        , bitor/2
        , bitxor/2
        , bitsl/2
        , bitsr/2
        ]).

%% String Funcs
-export([ lower/1
        , ltrim/1
        , reverse/1
        , rtrim/1
        , strlen/1
        , substr/2
        , substr/3
        , trim/1
        , upper/1
        ]).

%% Array Funcs
-export([ nth/2 ]).

%% Hash Funcs
-export([ md5/1
        , sha1/1
        , sha256/1
        ]).

-import(emqx_rule_maps,
        [ get_value/2
        , nested_get/2
        ]).

-compile({no_auto_import,
          [ abs/1
          , ceil/1
          , floor/1
          , round/1
          ]}).

-define(is_var(X), is_binary(X)).

%% @doc "msgid()" Func
msgid() ->
    fun(#{id := MsgId}) -> MsgId; (_) -> undefined end.

%% @doc "qos()" Func
qos() ->
    fun(#{qos := QoS}) -> QoS; (_) -> undefined end.

%% @doc "topic()" Func
topic() ->
    fun(#{topic := Topic}) -> Topic; (_) -> undefined end.

%% @doc "topic(N)" Func
topic({const, I}) when is_integer(I) ->
    fun(#{topic := Topic}) ->
            lists:nth(I+1, emqx_topic:tokens(Topic));
       (_) -> undefined
    end.

%% @doc "flags()" Func
flags() ->
    fun(#{flags := Flags}) -> Flags; (_) -> #{} end.

%% @doc "flags(Name)" Func
flag(Name) ->
    fun(#{flags := Flags}) -> get_value(Name, Flags); (_) -> undefined end.

%% @doc "clientid()" Func
clientid() ->
    fun(#{from := ClientId}) -> ClientId end.

%% @doc "clientip()" Func
clientip() ->
    header(clientip).

%% @doc "username()" Func
username() ->
    header(username).

%% @doc "headers()" Func
headers() ->
    fun(#{headers := Headers}) -> Headers; (_) -> #{} end.

%% @doc "header(Name)" Func
header(Name) ->
    fun(#{headers := Headers}) -> get_value(Name, Headers); (_) -> undefined end.

payload() ->
    fun(#{payload := Payload}) -> Payload; (_) -> undefined end.

payload(Path) when is_list(Path) ->
    fun(Payload) when is_map(Payload) ->
            nested_get(Path, Payload);
       (_) -> undefined
    end.

%% @doc "timestamp()" Func
timestamp() ->
    fun(#{timestamp := Ts}) ->
            emqx_time:now_ms(Ts);
       (_) -> emqx_time:now_ms()
    end.

%%------------------------------------------------------------------------------
%% Arithmetic Funcs
%%------------------------------------------------------------------------------

'+'(X, Y) ->
    fun(M) -> num(X, M) + num(Y, M) end.

'-'(X, Y) ->
    fun(M) -> num(X, M) - num(Y, M) end.

'*'(X, Y) ->
    fun(M) -> num(X, M) * num(Y, M) end.

'/'(X, Y) ->
    fun(M) -> num(X, M) / num(Y, M) end.

'div'(X, Y) ->
    fun(M) -> int(X, M) div int(Y, M) end.

mod(X, Y) ->
    fun(M) -> int(X, M) rem int(Y, M) end.

%%------------------------------------------------------------------------------
%% Math Funcs
%%------------------------------------------------------------------------------

abs({const, N}) when is_integer(N) ->
    fun(_) -> erlang:abs(N) end;
abs(X) when ?is_var(X) ->
    fun(#{X := V}) -> erlang:abs(V) end.

acos({const, N}) when is_number(N) ->
    fun(_) -> math:acos(N) end;
acos(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:acos(V) end.

acosh({const, N}) when is_number(N) ->
    fun(_) -> math:acosh(N) end;
acosh(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:acosh(V) end.

asin({const, N}) when is_number(N)->
    fun(_) -> math:asin(N) end;
asin(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:asin(V) end.

asinh({const, N}) when is_number(N) ->
    fun(_) -> math:asinh(N) end;
asinh(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:asinh(V) end.

atan({const, N}) when is_number(N) ->
    fun(_) -> math:atan(N) end;
atan(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:atan(V) end.

atanh({const, N}) when is_number(N)->
    fun(_) -> math:atanh(N) end;
atanh(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:atanh(V) end.

ceil({const, N}) when is_number(N) ->
    fun(_) -> erlang:ceil(N) end;
ceil(X) when ?is_var(X) ->
    fun(#{X := V}) -> erlang:ceil(V) end.

cos({const, N}) when is_number(N)->
    fun(_) -> math:cos(N) end;
cos(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:cos(V) end.

cosh({const, N}) when is_number(N) ->
    fun(_) -> math:cosh(N) end;
cosh(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:cosh(V) end.

exp({const, N}) when is_number(N)->
    fun(_) -> math:exp(N) end;
exp(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:exp(V) end.

floor({const, N}) when is_number(N) ->
    fun(_) -> erlang:floor(N) end;
floor(X) when ?is_var(X) ->
    fun(#{X := V}) -> erlang:floor(V) end.

fmod(X, {const, N}) when is_number(N) ->
    fun(M) -> math:fmod(num(X, M), N) end.

log({const, N}) when is_number(N) ->
    fun(_) -> math:log(N) end;
log(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:log(V) end.

log10({const, N}) when is_number(N) ->
    fun(_) -> math:log10(N) end;
log10(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:log10(V) end.

log2({const, N}) when is_number(N)->
    fun(_) -> math:log2(N) end;
log2(X) when ?is_var(X)->
    fun(#{X := V}) -> math:log2(V) end.

power(X, {const, N}) when is_number(N) ->
    fun(M) -> math:pow(num(X, M), N) end.

round({const, N}) when is_number(N) ->
    fun(_) -> erlang:round(N) end;
round(X) when ?is_var(X) ->
    fun(#{X := V}) -> erlang:round(V) end.

sin({const, N}) when is_number(N) ->
    fun(_) -> math:sin(N) end;
sin(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:sin(V) end.

sinh({const, N}) when is_number(N) ->
    fun(_) -> math:sinh(N) end;
sinh(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:sinh(V) end.

sqrt({const, N}) when is_number(N) ->
    fun(_) -> math:sqrt(N) end;
sqrt(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:sqrt(V) end.

tan({const, N}) when is_number(N) ->
    fun(_) -> math:tan(N) end;
tan(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:tan(V) end.

tanh({const, N}) when is_number(N) ->
    fun(_) -> math:tanh(N) end;
tanh(X) when ?is_var(X) ->
    fun(#{X := V}) -> math:tanh(V) end.

%%------------------------------------------------------------------------------
%% Bits Funcs
%%------------------------------------------------------------------------------

bitnot({const, I}) when is_integer(I) ->
    fun(_) -> bnot I end;
bitnot(X) when ?is_var(X) ->
    fun(#{X := I}) -> bnot I end.

bitand(X, Y) ->
    fun(M) -> int(X, M) band int(Y, M) end.

bitor(X, Y) ->
    fun(M) -> int(X, M) bor int(Y, M) end.

bitxor(X, Y) ->
    fun(M) -> int(X, M) bxor int(Y, M) end.

bitsl(X, {const, I}) when is_integer(I) ->
    fun(M) -> int(X, M) bsl I end.

bitsr(X, {const, I}) when is_integer(I) ->
    fun(M) -> int(X, M) bsr I end.

int({const, I}, _M) when is_integer(I) ->
    I;
int(X, M) when ?is_var(X) ->
    maps:get(X, M).

num({const, N}, _M) when is_number(N) ->
    N;
num(X, M) when ?is_var(X) ->
    maps:get(X, M).

%%------------------------------------------------------------------------------
%% String Funcs
%%------------------------------------------------------------------------------

lower({const, S}) ->
    fun(_) -> string:lowercase(S) end;
lower(X) when ?is_var(X) ->
    fun(#{X := S}) -> string:lowercase(S) end.

ltrim({const, S}) ->
    fun(_) -> string:trim(S, leading) end;
ltrim(X) when ?is_var(X) ->
    fun(#{X := S}) -> string:trim(S, leading) end.

reverse({const, S}) ->
    fun(_) -> iolist_to_binary(string:reverse(S)) end;
reverse(X) when ?is_var(X) ->
    fun(#{X := S}) -> iolist_to_binary(string:reverse(S)) end.

rtrim({const, S}) ->
    fun(_) -> string:trim(S, trailing) end;
rtrim(X) when ?is_var(X) ->
    fun(#{X := S}) -> string:trim(S, trailing) end.

strlen({const, S}) ->
    fun(_) -> string:length(S) end;
strlen(X) when ?is_var(X) ->
    fun(#{X := S}) -> string:length(S) end.

substr({const, S}, {const, Start}) when is_integer(Start) ->
    fun(_) -> string:slice(S, Start) end;
substr(X, {const, Start}) when ?is_var(X) ->
    fun(#{X := S}) -> string:slice(S, Start) end.

substr({const, S}, {const, Start}, {const, Length}) ->
    fun(_) -> string:slice(S, Start, Length) end;
substr(X, {const, Start}, {const, Length}) when ?is_var(X) ->
    fun(#{X := S}) -> string:slice(S, Start, Length) end.

trim({const, S}) ->
    fun(_) -> string:trim(S) end;
trim(X) when ?is_var(X) ->
    fun(#{X := S}) -> string:trim(S) end.

upper({const, S}) ->
    fun(_) -> string:uppercase(S) end;
upper(X) when ?is_var(X) ->
    fun(#{X := S}) -> string:uppercase(S) end.

%%------------------------------------------------------------------------------
%% Array Funcs
%%------------------------------------------------------------------------------

nth(X, {const, N}) when ?is_var(X) ->
    fun(#{X := L}) -> lists:nth(N+1, L); (_) -> undefined end.

%%------------------------------------------------------------------------------
%% Hash Funcs
%%------------------------------------------------------------------------------

md5({const, S}) ->
    fun(_) -> hash(md5, S) end;
md5(X) when ?is_var(X) ->
    fun(#{X := S}) -> hash(md5, S) end.

sha1({const, S}) ->
    fun(_) -> hash(sha1, S) end;
sha1(X) when ?is_var(X) ->
    fun(#{X := S}) -> hash(sha1, S) end.

sha256({const, S}) ->
    fun(_) -> hash(sha256, S) end;
sha256(X) when ?is_var(X) ->
    fun(#{X := S}) -> hash(sha256, S) end.

hash(Type, Data) ->
    hexstring(crypto:hash(Type, Data)).

hexstring(<<X:128/big-unsigned-integer>>) ->
    iolist_to_binary(io_lib:format("~32.16.0b", [X]));
hexstring(<<X:160/big-unsigned-integer>>) ->
    iolist_to_binary(io_lib:format("~40.16.0b", [X]));
hexstring(<<X:256/big-unsigned-integer>>) ->
    iolist_to_binary(io_lib:format("~64.16.0b", [X])).

