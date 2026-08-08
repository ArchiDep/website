defmodule ArchiDep.CourseSite.Renderer.Liquid do
  @moduledoc """
  The first of the renderer's two stages: everything written in `{% %}` and `{{
  }}` is expanded, and what comes out is still Markdown.

  This is the order Jekyll works in, and it is what makes a tag able to produce
  Markdown that the next stage then converts — or, for a slide deck, the whole
  answer, since a deck is never converted here at all.

  Two kinds of failure come out of it and they are not the same thing. A
  template that does not parse produces nothing, and there is no page to speak
  of. A template that parses but refers to something that is not there produces
  a complete page and a list of what to fix; the renderer collects those rather
  than stopping at the first, so that an author fixes a page in one pass.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.Filters
  alias ArchiDep.CourseSite.Renderer.Liquid.Registers
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source

  @doc """
  Expand the Liquid of a document.
  """
  @spec render(RenderContext.t()) ::
          {:ok, String.t(), [RenderError.t()]} | {:error, nonempty_list(RenderError.t())}
  def render(%RenderContext{} = context) do
    case parse_body(context) do
      {:ok, template} -> render_template(template, context)
      {:error, errors} -> {:error, errors}
    end
  end

  @doc """
  Expand the Liquid of the document's link reference definitions.

  They are expanded on their own, and before the body, because a block tag's
  body is converted *while* the body is being expanded — the definitions sit at
  the bottom of the file, so by the time the document's own copy of them is
  reached, every fragment that needed them has already been converted.

  **Nothing that goes wrong here is reported**, and a document whose definitions
  do not even parse simply defines nothing. That is not a hole: the definitions
  are part of the body, so `render/1` expands the same Liquid a second time and
  reports whatever is wrong with it there — at the line of the file it is
  actually written on, which this rendering of two lines out of context cannot
  say. Reporting here would report every such mistake twice, once with the wrong
  location.
  """
  @spec render_definitions(RenderContext.t()) :: [{String.t(), String.t()}]
  def render_definitions(%RenderContext{source: source} = context) do
    with definitions when definitions != "" <- Source.definitions(source.link_references),
         {:ok, template} <- parse(definitions, context.options.tags, context.source_path),
         {:ok, rendered, _errors} <- render_template(template, context) do
      Source.link_references(rendered)
    else
      _nothing_to_expand_or_nothing_that_expanded -> []
    end
  end

  @doc """
  Parse a Liquid template, the way the partials of a build are parsed before it
  starts.
  """
  @spec parse(String.t(), %{String.t() => module()}, String.t()) ::
          {:ok, Solid.Template.t()} | {:error, nonempty_list(RenderError.t())}
  def parse(source, tags, source_path) when is_binary(source) do
    case Solid.parse(source, tags: tags) do
      {:ok, template} -> {:ok, template}
      {:error, error} -> {:error, template_errors(error, source_path)}
    end
  end

  defp parse_body(%RenderContext{} = context),
    do: parse(context.source.body, context.options.tags, context.source_path)

  defp render_template(template, context) do
    solid_context = Registers.put(%Solid.Context{vars: variables(context)}, context)

    case Solid.render(template, solid_context, options(context)) do
      {:ok, rendered, errors} ->
        {:ok, IO.iodata_to_binary(rendered), render_errors(errors, context)}

      {:error, errors, _partial} ->
        {:error, render_errors(errors, context)}
    end
  end

  defp options(context),
    do: [
      custom_filters: Filters.build(context),
      strict_filters: true,
      strict_variables: context.options.strict_variables
    ]

  defp variables(context), do: %{"page" => RenderContext.page_variables(context)}

  defp template_errors(%Solid.TemplateError{errors: errors}, source_path),
    do:
      Enum.map(errors, fn %Solid.ParserError{reason: reason} = error ->
        RenderError.new({:liquid, reason}, source_path, loc(error))
      end)

  # A tag of this renderer reports a fully formed error; anything else comes
  # from Solid, whose own messages start with the line number that the renderer
  # says better at the end.
  defp render_errors(errors, context) do
    Enum.map(errors, fn
      %RenderError{} = error -> error
      error -> RenderError.new({:liquid, reason(error)}, context.source_path, loc(error))
    end)
  end

  defp reason(%Solid.UndefinedVariableError{original_name: name}),
    do: "Undefined variable #{name}"

  defp reason(%Solid.UndefinedFilterError{filter: filter}), do: "Undefined filter #{filter}"
  defp reason(%Solid.ArgumentError{message: message}), do: message

  defp reason(%Solid.WrongFilterArityError{
         filter: filter,
         expected_arity: expected,
         arity: given
       }),
       do: "The #{filter} filter takes #{expected} argument(s), got #{given}"

  defp reason(error), do: Exception.message(error)

  defp loc(%Solid.ParserError{meta: %{line: line, column: column}}),
    do: %{line: line, column: column}

  defp loc(%{loc: %{line: line, column: column}}), do: %{line: line, column: column}
  defp loc(_error), do: nil
end
