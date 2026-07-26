defmodule ArchiDep.CourseSite.Renderer.Liquid.IncludeTag do
  @moduledoc """
  `{% include icons/photo.html class="size-6" %}` — a partial rendered in place,
  with the values it was given available to it as `{{ include.… }}`.

  The course uses this for one thing: putting an icon into the page. The
  partials themselves are given to the renderer already parsed, so that a build
  is a function of what it was handed rather than of what happens to be on disk
  when it runs.

  Like `ArchiDep.CourseSite.Renderer.Liquid.LinkTag`, this reads its markup as
  text rather than as a Liquid expression, because the path of a partial
  contains a slash.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.RawMarkup

  @enforce_keys [:loc, :path, :variables]
  defstruct [:loc, :path, :variables]

  @type t :: %__MODULE__{
          loc: Solid.Lexer.loc(),
          path: String.t(),
          variables: %{String.t() => String.t()}
        }

  @variable ~r/([a-zA-Z_][a-zA-Z0-9_-]*)\s*=\s*"([^"]*)"|([a-zA-Z_][a-zA-Z0-9_-]*)\s*=\s*'([^']*)'/

  @impl Solid.Tag
  def parse("include", loc, context) do
    with {:ok, markup, context} <- RawMarkup.parse(context),
         {:ok, path, variables} <- markup(markup, loc) do
      {:ok, %__MODULE__{loc: loc, path: path, variables: variables}, context}
    end
  end

  defp markup("", loc), do: {:error, "The include tag requires the path of a partial", loc}

  defp markup(markup, _loc) do
    [path | _rest] = String.split(markup, ~r/\s+/, parts: 2)
    {:ok, path, variables(markup)}
  end

  defp variables(markup) do
    @variable
    |> Regex.scan(markup)
    |> Map.new(fn
      [_match, name, value] -> {name, value}
      [_match, "", "", name, value] -> {name, value}
    end)
  end

  defimpl Solid.Renderable do
    alias ArchiDep.CourseSite.Renderer.Liquid.Partial

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context, options),
      do: Partial.render(tag.path, tag.variables, context, options, tag.loc)
  end
end
