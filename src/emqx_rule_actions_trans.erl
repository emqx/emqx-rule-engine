-module(emqx_rule_actions_trans).

-include_lib("syntax_tools/include/merl.hrl").

-export([parse_transform/2]).

parse_transform(Forms, _Options) ->
  trans(Forms, []).

trans([], ResAST) ->
  lists:reverse(ResAST);
trans([{eof, L} | AST], ResAST) ->
  lists:reverse([{eof, L} | ResAST]) ++ AST;
trans([Form | AST], ResAST) ->
  trans(AST, [trans_functions(Form) | ResAST]).

trans_functions(Form) ->
  case Form of
    ?Q("'@Name'(_@@Args) -> _@@Expr.") ->
      case atom_to_list(erl_syntax:concrete(Name)) of
        "on_action_create_" ++ _ ->
          Bindings = lists:flatten(get_vars(Args) ++ get_vars(Expr, lefth)),
          Expr2 = append_to_result(Bindings, Expr),
          WithBindingsTree = ?Q("'@Name'(_@Args) -> _@Expr2."),
          [WithBindings] = erl_syntax:revert_forms([WithBindingsTree]),
          %io:format("OrgCode: ~p~n", [Form]), merl:print(Form),
          %io:format("AfterChanged: ~p~n", [WithBindings]), merl:print(WithBindings),
          WithBindings;
        _NotActCreate -> Form
      end;
    _ -> Form
  end.

get_vars(Exprs) ->
  get_vars(Exprs, all).
get_vars(Exprs, Type) ->
  do_get_vars(Exprs, [], Type).

do_get_vars([], Vars, _Type) -> Vars;
do_get_vars([Line | Expr], Vars, all) ->
  do_get_vars(Expr, [syntax_vars(Line) | Vars], all);
do_get_vars([Line | Expr], Vars, lefth) ->
  do_get_vars(Expr,
    case Line of
      ?Q("_@LeftV = _@@_") -> Vars ++ syntax_vars(LeftV);
      _ -> Vars
    end, lefth).

syntax_vars(Line) ->
  sets:to_list(erl_syntax_lib:variables(Line)).

%% append bindings to the return value as the first tuple element.
%% e.g. if the original result is R, then the new result will be {[binding()], R}.
append_to_result(Bindings, Exprs) ->
  do_append_to_result(to_keyword(Bindings), Exprs, []).

do_append_to_result(KeyWordVars, [Line], Res) ->
  Expr = case Line of
    ?Q("_@LeftV = _@RightV") -> RightV;
    _ -> Line
  end,
  lists:reverse([?Q("{[_@KeyWordVars], _@Expr}") | Res]);
do_append_to_result(KeyWordVars, [Line | Exprs], Res) ->
  do_append_to_result(KeyWordVars, Exprs, [Line | Res]).

to_keyword(Vars) ->
  [erl_syntax:tuple([erl_syntax:atom(Var), merl:var(Var)])
   || Var <- Vars].
