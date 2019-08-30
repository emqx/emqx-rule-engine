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
        , peername/0
        , username/0
        , payload/0
        , payload/1
        , timestamp/0
        , contains_topic/2
        , contains_topic/3
        , contains_topic_match/2
        , contains_topic_match/3
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
        , sha/1
        , sha256/1
        ]).

%% Data encode and decode
-export([ base64_encode/1
        , base64_decode/1
        , json_decode/1
        , json_encode/1
        ]).

-export(['$handle_undefined_function'/2]).

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
topic(I) when is_integer(I) ->
    fun(#{topic := Topic}) ->
            lists:nth(I, emqx_topic:tokens(Topic));
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
    fun(#{from := ClientId}) -> ClientId; (_) -> undefined end.

%% @doc "clientip()" Func
clientip() ->
    fun(#{headers := #{peername := {Addr, _Port}}}) ->
        iolist_to_binary(inet_parse:ntoa(Addr));
        (_) -> undefined
    end.

%% @doc "peername()" Func
peername() ->
    fun(#{headers := #{peername := {Addr, Port}}}) ->
        iolist_to_binary(io_lib:format("~s:~w", [inet_parse:ntoa(Addr), Port]));
        (_) -> undefined
    end.

%% @doc "username()" Func
username() ->
    header(username).

%% @doc "headers()" Func
headers() ->
    fun(#{headers := Headers}) -> Headers; (_) -> #{} end.

%% @doc "header(Name)" Func
header(Name) ->
    fun(#{headers := Headers}) ->
            get_value(Name, Headers);
       (_) -> undefined
    end.

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

%% @doc Check if a topic_filter contains a specific topic
%% TopicFilters = [{<<"t/a">>, #{qos => 0}].
-spec(contains_topic(emqx_mqtt_types:topic_filters(), emqx_types:topic())
        -> true | false).
contains_topic(TopicFilters, Topic) ->
    case proplists:get_value(Topic, TopicFilters) of
        undefined -> false;
        _ -> true
    end.
contains_topic(TopicFilters, Topic, QoS) ->
    case proplists:get_value(Topic, TopicFilters) of
        #{qos := QoS} -> true;
        undefined -> false
    end.

-spec(contains_topic_match(emqx_mqtt_types:topic_filters(), emqx_types:topic())
        -> true | false).
contains_topic_match(TopicFilters, Topic) ->
    case find_topic_filter(Topic, TopicFilters) of
        not_found -> false;
        _ -> true
    end.
contains_topic_match(TopicFilters, Topic, QoS) ->
    case find_topic_filter(Topic, TopicFilters) of
        {_, #{qos := QoS}} -> true;
        _ -> false
    end.

find_topic_filter(Filter, TopicFilters) ->
    try
        [case emqx_topic:match(Topic, Filter) of
            true -> throw(Result);
            false -> ok
         end || Result = {Topic, _Opts} <- TopicFilters],
        not_found
    catch
        throw:Result -> Result
    end.

%%------------------------------------------------------------------------------
%% Arithmetic Funcs
%%------------------------------------------------------------------------------

'+'(X, Y) when is_number(X), is_number(Y) ->
    X + Y.

'-'(X, Y) when is_number(X), is_number(Y) ->
    X - Y.

'*'(X, Y) when is_number(X), is_number(Y) ->
    X * Y.

'/'(X, Y) when is_number(X), is_number(Y) ->
    X / Y.

'div'(X, Y) when is_integer(X), is_integer(Y) ->
    X div Y.

mod(X, Y) when is_integer(X), is_integer(Y) ->
    X rem Y.

%%------------------------------------------------------------------------------
%% Math Funcs
%%------------------------------------------------------------------------------

abs(N) when is_integer(N) ->
    erlang:abs(N).

acos(N) when is_number(N) ->
    math:acos(N).

acosh(N) when is_number(N) ->
    math:acosh(N).

asin(N) when is_number(N)->
    math:asin(N).

asinh(N) when is_number(N) ->
    math:asinh(N).

atan(N) when is_number(N) ->
    math:atan(N).

atanh(N) when is_number(N)->
    math:atanh(N).

ceil(N) when is_number(N) ->
    erlang:ceil(N).

cos(N) when is_number(N)->
    math:cos(N).

cosh(N) when is_number(N) ->
    math:cosh(N).

exp(N) when is_number(N)->
    math:exp(N).

floor(N) when is_number(N) ->
    erlang:floor(N).

fmod(X, Y) when is_number(X), is_number(Y) ->
    math:fmod(X, Y).

log(N) when is_number(N) ->
    math:log(N).

log10(N) when is_number(N) ->
    math:log10(N).

log2(N) when is_number(N)->
    math:log2(N).

power(X, Y) when is_number(X), is_number(Y) ->
    math:pow(X, Y).

round(N) when is_number(N) ->
    erlang:round(N).

sin(N) when is_number(N) ->
    math:sin(N).

sinh(N) when is_number(N) ->
    math:sinh(N).

sqrt(N) when is_number(N) ->
    math:sqrt(N).

tan(N) when is_number(N) ->
    math:tan(N).

tanh(N) when is_number(N) ->
    math:tanh(N).

%%------------------------------------------------------------------------------
%% Bits Funcs
%%------------------------------------------------------------------------------

bitnot(I) when is_integer(I) ->
    bnot I.

bitand(X, Y) when is_integer(X), is_integer(Y) ->
    X band Y.

bitor(X, Y) when is_integer(X), is_integer(Y) ->
    X bor Y.

bitxor(X, Y) when is_integer(X), is_integer(Y) ->
    X bxor Y.

bitsl(X, I) when is_integer(X), is_integer(I) ->
    X bsl I.

bitsr(X, I) when is_integer(X), is_integer(I) ->
    X bsr I.

%%------------------------------------------------------------------------------
%% String Funcs
%%------------------------------------------------------------------------------

lower(S) when is_binary(S) ->
    string:lowercase(S).

ltrim(S) when is_binary(S) ->
    string:trim(S, leading).

reverse(S) when is_binary(S) ->
    iolist_to_binary(string:reverse(S)).

rtrim(S) when is_binary(S) ->
    string:trim(S, trailing).

strlen(S) when is_binary(S) ->
    string:length(S).

substr(S, Start) when is_binary(S), is_integer(Start) ->
    string:slice(S, Start).

substr(S, Start, Length) when is_binary(S),
                              is_integer(Start),
                              is_integer(Length) ->
    string:slice(S, Start, Length).

trim(S) when is_binary(S) ->
    string:trim(S).

upper(S) when is_binary(S) ->
    string:uppercase(S).

%%------------------------------------------------------------------------------
%% Array Funcs
%%------------------------------------------------------------------------------

nth(N, L) when is_integer(N), is_list(L) ->
    lists:nth(N, L).

%%------------------------------------------------------------------------------
%% Hash Funcs
%%------------------------------------------------------------------------------

md5(S) when is_binary(S) ->
    hash(md5, S).

sha(S) when is_binary(S) ->
    hash(sha, S).

sha256(S) when is_binary(S) ->
    hash(sha256, S).

hash(Type, Data) ->
    hexstring(crypto:hash(Type, Data)).

hexstring(<<X:128/big-unsigned-integer>>) ->
    iolist_to_binary(io_lib:format("~32.16.0b", [X]));
hexstring(<<X:160/big-unsigned-integer>>) ->
    iolist_to_binary(io_lib:format("~40.16.0b", [X]));
hexstring(<<X:256/big-unsigned-integer>>) ->
    iolist_to_binary(io_lib:format("~64.16.0b", [X])).

%%------------------------------------------------------------------------------
%% Base64 Funcs
%%------------------------------------------------------------------------------

base64_encode(Data) when is_binary(Data) ->
    base64:encode(Data).

base64_decode(Data) when is_binary(Data) ->
    base64:decode(Data).

json_encode(Data) ->
    jsx:encode(Data).

json_decode(Data) ->
    jsx:decode(Data, [return_maps]).

%% @doc This is for sql funcs that should be handled in the specific modules.
%% Here the emqx_rule_funcs module acts as a proxy, forwarding
%% the function handling to the worker module.
%% @end
'$handle_undefined_function'(schema_decode, [SchemaId, Data|MoreArgs]) ->
    emqx_schema_parser:decode(SchemaId, Data, MoreArgs);
'$handle_undefined_function'(schema_decode, Args) ->
    error({args_count_error, {schema_decode, Args}});

'$handle_undefined_function'(schema_encode, [SchemaId, Term|MoreArgs]) ->
    emqx_schema_parser:encode(SchemaId, Term, MoreArgs);
'$handle_undefined_function'(schema_encode, Args) ->
    error({args_count_error, {schema_encode, Args}});

'$handle_undefined_function'(Fun, _Args) ->
    error({sql_function_not_supported, Fun}).
