defmodule ArchiDep.CourseSite.Renderer.Markdown do
  @moduledoc """
  The one place Markdown becomes HTML.

  Everything goes through here — a whole page, the body of a block tag — so that
  one set of options and one list of passes apply to all of it. A tag that
  converted its own body with its own options is how two parts of the same page
  end up disagreeing about what Markdown is.

  Three of the options are not preferences:

  - `unsafe: true` keeps the raw HTML the course writes in its Markdown. Without
    it every such island is replaced by a comment saying it was omitted. The
    input is our own content, not anything a reader supplied.
  - `smart: true` turns quotes and dashes into their typographic characters.
  - `header_id_prefix: ""` is what gives headings the identifiers the table of
    contents, the in-page anchors and the application's own links to the course
    all depend on.

  Parsing and rendering are separate steps here rather than one call because
  passes run in between, and because a page is split into its excerpt and its
  body as a document rather than as text. That is safe: rendering a parsed
  document is byte for byte what rendering the Markdown directly produces.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source

  @options [
    extension: [
      strikethrough: true,
      table: true,
      autolink: true,
      tasklist: true,
      footnotes: true,
      header_id_prefix: ""
    ],
    parse: [smart: true],
    render: [unsafe: true]
  ]

  @doc """
  The MDEx options every conversion of the build uses.
  """
  @spec options() :: keyword()
  def options, do: @options

  @doc """
  Parse Markdown into a document, with the source's link reference definitions
  appended so that a reference link resolves even in a fragment taken out of the
  page.

  A definition produces no node of its own and a link is resolved as it is
  parsed, so a document parsed this way can be cut into pieces and each piece
  rendered on its own without any of its links breaking.
  """
  @spec parse(String.t(), RenderContext.t()) ::
          {:ok, MDEx.Document.t()} | {:error, RenderError.t()}
  def parse(markdown, %RenderContext{} = context) when is_binary(markdown) do
    case MDEx.parse_document(with_definitions(markdown, context.source), @options) do
      {:ok, document} -> {:ok, document}
      {:error, error} -> {:error, markdown_error(error, context)}
    end
  end

  @doc """
  Run the build's passes over a document and render it to HTML.
  """
  @spec render(MDEx.Document.t(), RenderContext.t()) :: {String.t(), [RenderError.t()]}
  def render(%MDEx.Document{} = document, %RenderContext{} = context) do
    {document, errors} = run_passes(document, context)

    case MDEx.to_html(document, @options) do
      {:ok, html} -> {html, errors}
      {:error, error} -> {"", errors ++ [markdown_error(error, context)]}
    end
  end

  @doc """
  Convert a fragment of Markdown to HTML: what a block tag calls for its own
  body.
  """
  @spec to_html(String.t(), RenderContext.t()) :: {String.t(), [RenderError.t()]}
  def to_html(markdown, %RenderContext{} = context) when is_binary(markdown) do
    case parse(markdown, context) do
      {:ok, document} -> render(document, context)
      {:error, error} -> {"", [error]}
    end
  end

  defp run_passes(document, context) do
    Enum.reduce(context.options.ast_passes, {document, []}, fn pass, {document, errors} ->
      {document, pass_errors} = pass.run(document, context)
      {document, errors ++ pass_errors}
    end)
  end

  defp with_definitions(markdown, source) do
    case Source.definitions(source) do
      "" -> markdown
      definitions -> markdown <> "\n\n" <> definitions
    end
  end

  defp markdown_error(error, context),
    do: RenderError.new({:markdown, Exception.message(error)}, context.source_path)
end
