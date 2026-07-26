defmodule ArchiDep.CourseSite.Renderer.Liquid.ColsTag do
  @moduledoc """
  `{% cols %}` — prose laid out side by side on a wide screen and stacked on a
  narrow one, most often a paragraph next to the picture it describes.

  Where one column ends and the next begins is written as an HTML comment inside
  the body rather than as a tag of its own, so that the body stays a piece of
  Markdown a reader can follow. A comment may carry the classes of the column it
  opens, which is how a column is made to span more than one of them.

  Each column is converted on its own, for the reason every tag body is: what
  the tag wraps a column in is raw HTML, and the content of raw HTML is opaque
  to the Markdown of the page around it.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody
  alias ArchiDep.CourseSite.Renderer.RenderError

  @default_columns 2
  @min_columns 2
  @max_columns 12

  @column ~r/<!--\s*col(?:umn)?(?:\s+([^"'>]+))?\s*-->/

  @enforce_keys [:loc, :columns, :body, :problems]
  defstruct [:loc, :columns, :body, :problems]

  @type t :: %__MODULE__{
          loc: Solid.Lexer.loc(),
          columns: pos_integer(),
          body: Solid.Parser.parse_tree(),
          problems: [RenderError.reason()]
        }

  @impl Solid.Tag
  def parse("cols", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endcols") do
      {columns, problems} = columns(attributes)
      {:ok, %__MODULE__{loc: loc, columns: columns, body: body, problems: problems}, context}
    end
  end

  @doc """
  Cut a rendered body into its columns, as the classes each one opens with and
  the Markdown under it.

  The text before the first marker is a column of its own, which is what lets a
  body of two columns be written with a single marker between them. It is
  dropped when it is blank, as it is whenever the author opens the body with a
  marker.

      iex> ColsTag.split("Left.\\n<!-- col md:col-span-2 -->\\nRight.\\n")
      [{nil, "Left.\\n"}, {"md:col-span-2", "\\nRight.\\n"}]
  """
  @spec split(String.t()) :: [{String.t() | nil, String.t()}]
  def split(body) do
    [leading | rest] = Regex.split(@column, body, include_captures: true)

    columns =
      rest
      |> Enum.chunk_every(2)
      |> Enum.map(fn [marker, text] -> {classes(marker), text} end)

    if String.trim(leading) == "", do: columns, else: [{nil, leading} | columns]
  end

  @doc """
  The class that lays a row out in as many columns as the tag asks for, on a
  screen wide enough to show them side by side.
  """
  @spec grid_class(pos_integer()) :: String.t()
  def grid_class(columns), do: "md:grid-cols-#{columns}"

  defp classes(marker) do
    with [_match, classes] <- Regex.run(@column, marker),
         trimmed when trimmed != "" <- String.trim(classes) do
      trimmed
    else
      _none -> nil
    end
  end

  # A row of a number of columns the grid has no layout for is laid out in the
  # number it defaults to, and what the author asked for is reported.
  defp columns(attributes) do
    case Map.get(attributes, "columns", @default_columns) do
      columns when is_integer(columns) and columns >= @min_columns and columns <= @max_columns ->
        {columns, []}

      unknown ->
        {@default_columns,
         [
           {:invalid_tag, "cols",
            "The number of columns must be between #{@min_columns} and #{@max_columns}, " <>
              "got #{inspect(unknown)}"}
         ]}
    end
  end

  defimpl Solid.Renderable do
    alias ArchiDep.CourseSite.Renderer.Liquid.ColsTag
    alias ArchiDep.CourseSite.Renderer.Liquid.Registers
    alias ArchiDep.CourseSite.Renderer.Markdown

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context!, options) do
      context! = Registers.report(context!, tag.problems, tag.loc)
      {markdown, context!} = NestedBody.render(tag.body, context!, options)
      {columns, errors} = columns(markdown, Registers.fetch!(context!))

      {~s(<div class="cols grid grid-cols-1 #{ColsTag.grid_class(tag.columns)} gap-4">) <>
         columns <> ~s(</div>), Registers.report(context!, errors)}
    end

    defp columns(markdown, render_context) do
      {columns, errors} =
        markdown
        |> ColsTag.split()
        |> Enum.map_reduce([], fn {classes, text}, errors ->
          {html, column_errors} = Markdown.to_html(text, render_context)
          {~s(<div#{class(classes)}>#{html}</div>), errors ++ column_errors}
        end)

      {Enum.join(columns), errors}
    end

    defp class(nil), do: ""
    defp class(classes), do: ~s( class="#{classes}")
  end
end
