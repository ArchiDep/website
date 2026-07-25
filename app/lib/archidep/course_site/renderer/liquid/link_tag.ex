defmodule ArchiDep.CourseSite.Renderer.Liquid.LinkTag do
  @moduledoc """
  `{% link _course/205-php-todolist/exercise.md %}` — the URL of another
  document of the course, written as the path of its source file.

  The tag emits nothing but a logical reference; where that document ends up
  living is `ArchiDep.CourseSite.Urls`' business. That is what lets the same
  chapter link resolve differently in the site being taught, in a frozen archive
  and in a PDF, without the content knowing any of it.

  A path that names no document of the course is reported rather than rendered
  as a broken link, which is the whole reason the content refers to a source
  file instead of writing a URL.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid.RawMarkup
  alias ArchiDep.CourseSite.Renderer.Liquid.Registers
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls

  @enforce_keys [:loc, :source_path]
  defstruct [:loc, :source_path]

  @type t :: %__MODULE__{loc: Solid.Lexer.loc(), source_path: String.t()}

  @impl Solid.Tag
  def parse("link", loc, context) do
    with {:ok, markup, context} <- RawMarkup.parse(context),
         {:ok, source_path} <- source_path(markup, loc) do
      {:ok, %__MODULE__{loc: loc, source_path: source_path}, context}
    end
  end

  @doc """
  The document a `{% link %}` tag points at, or why it points at nothing.
  """
  @spec document(t()) :: {:ok, DocumentRef.t()} | {:error, RenderError.reason()}
  def document(%__MODULE__{source_path: source_path}) do
    case DocumentRef.parse_source_path(source_path) do
      {:ok, document} -> {:ok, document}
      {:error, {:invalid_source_path, path}} -> {:error, {:invalid_document, path}}
    end
  end

  defp source_path("", loc), do: {:error, "The link tag requires the path of a document", loc}

  defp source_path(markup, _loc),
    do: {:ok, markup |> String.trim("\"") |> String.trim("'") |> String.trim()}

  defimpl Solid.Renderable do
    alias ArchiDep.CourseSite.Renderer.Liquid.LinkTag

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context, _options) do
      render_context = Registers.fetch!(context)

      with {:ok, document} <- LinkTag.document(tag),
           {:ok, url} <-
             resolve(render_context.urls, {:document, document}, render_context.page) do
        {url, context}
      else
        {:error, reason} ->
          {"",
           Registers.report(
             context,
             RenderError.new(reason, render_context.source_path, tag.loc)
           )}
      end
    end

    defp resolve(urls, reference, page) do
      case Urls.resolve(urls, reference, page) do
        {:ok, url} -> {:ok, url}
        {:error, error} -> {:error, {:url, error}}
      end
    end
  end
end
