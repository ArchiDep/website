defmodule ArchiDep.ContextBehaviourContractTest do
  use ExUnit.Case, async: true

  # Each bounded context is a trio: a behaviour declaring the contract, a public
  # boundary that delegates to the configured implementation, and an
  # implementation that delegates to the use cases. The behaviour and the
  # boundary are meant to carry the same documentation and typespecs so a caller
  # sees the contract from either side. Nothing at compile time keeps them in
  # sync, so this test reflects on every callback and asserts the boundary
  # exposes it with a byte-for-byte identical `@doc` and an equivalent spec, and
  # that the implementation exposes it hidden. A missing function, a doc that
  # drifts, or a spec that no longer matches the callback fails here.

  @triples [
    {ArchiDep.Accounts, ArchiDep.Accounts.Behaviour, ArchiDep.Accounts.Context},
    {ArchiDep.Course, ArchiDep.Course.Behaviour, ArchiDep.Course.Context},
    {ArchiDep.Events, ArchiDep.Events.Behaviour, ArchiDep.Events.Context},
    {ArchiDep.Servers, ArchiDep.Servers.Behaviour, ArchiDep.Servers.Context}
  ]

  test "each context boundary and implementation stay in sync with the behaviour" do
    for {boundary, behaviour, impl} <- @triples, module <- [boundary, behaviour, impl] do
      Code.ensure_loaded!(module)
    end

    violations =
      for {boundary, behaviour, impl} <- @triples,
          {name, arity} <- behaviour.behaviour_info(:callbacks),
          problems = problems(boundary, behaviour, impl, name, arity),
          problems != [],
          into: %{} do
        {{behaviour, name, arity}, problems}
      end

    assert violations == %{}
  end

  defp problems(boundary, behaviour, impl, name, arity) do
    presence_problems(boundary, impl, name, arity) ++
      doc_problems(boundary, behaviour, impl, name, arity) ++
      spec_problems(boundary, behaviour, name, arity)
  end

  defp presence_problems(boundary, impl, name, arity) do
    for {label, module} <- [boundary: boundary, impl: impl],
        not function_exported?(module, name, arity),
        do: {:not_exported, label}
  end

  defp doc_problems(boundary, behaviour, impl, name, arity) do
    behaviour_doc = fetch_doc(behaviour, :callback, name, arity)
    boundary_doc = fetch_doc(boundary, :function, name, arity)
    impl_doc = fetch_doc(impl, :function, name, arity)

    problem_when(
      boundary_doc != behaviour_doc,
      {:doc_mismatch, boundary: boundary_doc, behaviour: behaviour_doc}
    ) ++ problem_when(impl_doc != :hidden, {:impl_doc_not_hidden, impl_doc})
  end

  defp spec_problems(boundary, behaviour, name, arity) do
    spec = normalize(Code.Typespec.fetch_specs(boundary), name, arity)
    callback = normalize(Code.Typespec.fetch_callbacks(behaviour), name, arity)

    problem_when(spec != callback, {:spec_mismatch, spec: spec, callback: callback})
  end

  defp problem_when(true, problem), do: [problem]
  defp problem_when(false, _problem), do: []

  defp fetch_doc(module, kind, name, arity) do
    {:docs_v1, _anno, _lang, _format, _module_doc, _meta, docs} = Code.fetch_docs(module)

    case Enum.find(docs, fn {signature, _anno, _sig, _doc, _meta} ->
           signature == {kind, name, arity}
         end) do
      nil -> :missing
      {_signature, _anno, _sig, doc, _meta} -> doc
    end
  end

  # Render the callback/spec forms for a function as normalized strings: strip
  # any `arg :: type` name annotations so a named argument compares equal to a
  # bare type, and drop line metadata by going through `Macro.to_string/1`.
  # `spec_to_quoted/2` renders fully-qualified module names, so this comparison
  # is independent of how either module aliases its types.
  defp normalize({:ok, entries}, name, arity) do
    case Enum.find(entries, fn {{n, a}, _forms} -> {n, a} == {name, arity} end) do
      nil -> :missing
      {_key, forms} -> forms |> Enum.map(&render(name, &1)) |> Enum.sort() |> Enum.join("\n")
    end
  end

  defp render(name, form) do
    name
    |> Code.Typespec.spec_to_quoted(form)
    |> Macro.prewalk(fn
      {:"::", _meta, [{arg, _arg_meta, context}, type]} when is_atom(arg) and is_atom(context) ->
        type

      node ->
        node
    end)
    |> Macro.to_string()
  end
end
