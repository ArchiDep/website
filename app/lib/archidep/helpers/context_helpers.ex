defmodule ArchiDep.Helpers.ContextHelpers do
  @moduledoc """
  Helpers to implement application contexts.

  See https://hexdocs.pm/phoenix/contexts.html.
  """

  @doc """
  Defines a module as a context behaviour.
  """
  @spec __using__(:behaviour) :: Macro.t()
  defmacro __using__(:behaviour) do
    quote do
      Module.register_attribute(__MODULE__, :context_callback, accumulate: true)

      @before_compile ArchiDep.Helpers.ContextHelpers
    end
  end

  @doc """
  Adds the `:__context_callbacks__` function which returns information about the
  defined behaviour callbacks.
  """
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      @spec __context_callbacks__() ::
              list(
                {{module, atom, non_neg_integer}, list({:doc, String.t()} | {:args, list(atom)})}
              )
      def __context_callbacks__, do: @context_callback
    end
  end

  @doc """
  Defines a callback in the current module.
  """
  @spec callback(term, Keyword.t()) :: Macro.t()
  defmacro callback(
             ast,
             opts! \\ []
           )
           when is_list(opts!) do
    {docstring, opts!} = Keyword.pop(opts!, :doc)

    [] = opts!

    {fun, args_and_types, spec_ast} = ast |> expand_all_aliases(__CALLER__) |> parse_callback()

    arg_names = Keyword.keys(args_and_types)
    args_ast = Enum.map(arg_names, fn arg -> {arg, [], nil} end)
    arity = length(args_ast)
    spec = Macro.escape(spec_ast)

    quote do
      doc =
        case Module.get_attribute(__MODULE__, :doc) do
          {_line, text} -> text
          _anything_else -> nil
        end

      @context_callback {{__MODULE__, unquote(fun), unquote(arity)},
                         doc: unquote(docstring) || doc,
                         args: unquote(arg_names),
                         spec: unquote(spec)}
      @doc unquote(docstring) || doc
      @callback unquote(spec_ast)
    end
  end

  @doc """
  Delegates a behaviour's callback to the implementation module, defined by the
  `:to` option or the `@implementation` module attribute.
  """
  @spec delegate(term, Keyword.t()) :: Macro.t()
  defmacro delegate(
             {:&, _meta1, [{:/, _meta2, [{{:., _meta3, [m, f]}, _meta4, []}, a]}]},
             opts! \\ []
           )
           when is_list(opts!) do
    behaviour = Macro.expand(m, __CALLER__)
    callbacks = behaviour.__context_callbacks__()
    {_mfa, meta} = Enum.find(callbacks, fn {mfa, _o} -> mfa == {behaviour, f, a} end)

    {delegate_target, opts!} =
      Keyword.pop_lazy(opts!, :to, fn ->
        {:@, [], [{:implementation, [], nil}]}
      end)

    {doc, opts!} = Keyword.pop_lazy(opts!, :doc, fn -> Keyword.fetch!(meta, :doc) end)

    [] = opts!

    args_ast = meta |> Keyword.fetch!(:args) |> Enum.map(&{&1, [], nil})
    spec_ast = Keyword.fetch!(meta, :spec)

    quote do
      @doc unquote(doc)
      @spec unquote(spec_ast)
      defdelegate unquote(f)(unquote_splicing(args_ast)), to: unquote(delegate_target)
    end
  end

  @doc """
  Delegates a behaviour's callback to the real implementation.
  """
  @spec implement(term, module) :: Macro.t()
  defmacro implement(
             {:&, _meta1, [{:/, _meta2, [{{:., _meta3, [m, f]}, _meta4, []}, a]}]},
             delegate_target,
             opts! \\ []
           ) do
    behaviour = Macro.expand(m, __CALLER__)
    callbacks = behaviour.__context_callbacks__()
    {_mfa, meta} = Enum.find(callbacks, fn {mfa, _o} -> mfa == {behaviour, f, a} end)

    {as, opts!} = Keyword.pop(opts!, :as, f)

    [] = opts!

    args_ast = meta |> Keyword.fetch!(:args) |> Enum.map(&{&1, [], nil})

    quote do
      @doc false
      @impl unquote(behaviour)
      defdelegate unquote(f)(unquote_splicing(args_ast)),
        to: unquote(delegate_target),
        as: unquote(as)
    end
  end

  defp parse_callback({:"::", callback_meta, [{fun, fun_meta, fun_args}, result]}) do
    args_and_types = List.first(fun_args, [])
    spec_ast = {:"::", callback_meta, [{fun, fun_meta, Keyword.values(args_and_types)}, result]}
    {fun, args_and_types, spec_ast}
  end

  defp parse_callback(
         {:when, when_meta, [{:"::", callback_meta, [{fun, fun_meta, fun_args}, result]}, w]}
       ) do
    args_and_types = List.first(fun_args, [])

    spec_ast =
      {:when, when_meta,
       [{:"::", callback_meta, [{fun, fun_meta, Keyword.values(args_and_types)}, result]}, w]}

    {fun, args_and_types, spec_ast}
  end

  defp expand_all_aliases({:__aliases__, _meta, _nodes} = ast, env),
    do: Macro.expand_literals(ast, env)

  defp expand_all_aliases({fun, meta, nodes}, env) when is_list(nodes),
    do: {expand_all_aliases(fun, env), meta, Enum.map(nodes, &expand_all_aliases(&1, env))}

  defp expand_all_aliases(ast, env) when is_list(ast),
    do: Enum.map(ast, &expand_all_aliases(&1, env))

  defp expand_all_aliases({key, value}, env) when is_atom(key),
    do: {key, expand_all_aliases(value, env)}

  defp expand_all_aliases(ast, _env), do: ast
end
