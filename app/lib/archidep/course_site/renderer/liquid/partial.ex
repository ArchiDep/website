defmodule ArchiDep.CourseSite.Renderer.Liquid.Partial do
  @moduledoc """
  Render one of the partials the build was given.

  `{% include %}` is one caller; the other is a block tag showing an icon in its
  own wrapper (`ArchiDep.CourseSite.Renderer.Liquid.TagIcon`), which renders the
  very same `icons/…` partial the content includes by hand rather than writing
  the SVG out.

  Both go through here so that a partial the build was never given is reported
  once, in one wording, whoever asked for it.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.Registers

  @doc """
  Render a partial with the values it is given, which it reads as `{{ include.…
  }}`.
  """
  @spec render(
          String.t(),
          %{String.t() => String.t()},
          Solid.Context.t(),
          keyword(),
          Solid.Lexer.loc() | nil
        ) :: {iodata(), Solid.Context.t()}
  def render(path, variables, %Solid.Context{} = context, options, loc) do
    render_context = Registers.fetch!(context)

    case Map.fetch(render_context.includes, path) do
      {:ok, template} -> render_template(template, variables, context, options)
      :error -> {"", Registers.report(context, {:unknown_include, path}, loc)}
    end
  end

  # The partial sees the document's variables plus its own; whatever it does to
  # them stays inside it, the way a Jekyll include does.
  defp render_template(template, variables, context, options) do
    document_variables = context.vars

    {rendered, context} =
      Solid.render(
        template.parsed_template,
        %{context | vars: Map.put(document_variables, "include", variables)},
        options
      )

    {rendered, %{context | vars: document_variables}}
  end
end
