defmodule ArchiDep.Support.CourseSiteRendererTestTags do
  @moduledoc """
  Liquid tags and rendering passes that exist only to drive the course material
  renderer in tests.

  The renderer's seams — the tag table, the two lists of passes — are what the
  rest of the migration plugs its real tags and passes into. These are the
  smallest possible things that fit those seams, so that the pipeline can be
  exercised without depending on what any particular real tag does. They double
  as the worked example of how a tag reads its body, reaches the document it is
  in, and reports a problem instead of raising.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody
  alias ArchiDep.CourseSite.Renderer.Liquid.RawBody
  alias ArchiDep.CourseSite.Renderer.Liquid.Registers
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.RenderError

  defmodule ProseTag do
    @moduledoc """
    A block tag whose body is prose: Liquid inside it is expanded, and the
    result is converted from Markdown, which is what the course's notes and
    callouts do.
    """

    @behaviour Solid.Tag

    alias ArchiDep.CourseSite.Renderer.Liquid.Attributes

    @enforce_keys [:loc, :attributes, :body]
    defstruct [:loc, :attributes, :body]

    @impl Solid.Tag
    def parse("prose", loc, context) do
      with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
           {:ok, attributes} <- Attributes.parse(tokens),
           {:ok, body, context} <- NestedBody.parse(context, "endprose") do
        {:ok, %__MODULE__{loc: loc, attributes: attributes, body: body}, context}
      end
    end

    defimpl Solid.Renderable do
      @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
      def render(tag, context, options) do
        {markdown, context} = NestedBody.render(tag.body, context, options)
        {html, errors} = Markdown.to_html(markdown, Registers.fetch!(context))
        kind = Map.get(tag.attributes, "kind", "plain")

        {~s(<div class="prose-#{kind}">) <> html <> "</div>",
         Enum.reduce(errors, context, &Registers.report(&2, &1))}
      end
    end
  end

  defmodule CodeTag do
    @moduledoc """
    A block tag whose body is code: nothing inside it is expanded, so a sample
    containing `{{` is a sample rather than a parse error.
    """

    @behaviour Solid.Tag

    @enforce_keys [:loc, :body]
    defstruct [:loc, :body]

    @impl Solid.Tag
    def parse("code", loc, context) do
      with {:ok, _tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
           {:ok, body, context} <- RawBody.parse(context, "endcode") do
        {:ok, %__MODULE__{loc: loc, body: body}, context}
      end
    end

    defimpl Solid.Renderable do
      @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
      def render(tag, context, _options), do: {"<pre>#{tag.body}</pre>", context}
    end
  end

  defmodule FailingTag do
    @moduledoc """
    A tag that always reports a problem and renders nothing, the way a tag does
    when the content refers to something that does not exist.
    """

    @behaviour Solid.Tag

    @enforce_keys [:loc]
    defstruct [:loc]

    @impl Solid.Tag
    def parse("boom", loc, context) do
      with {:ok, _tokens, context} <- Solid.Lexer.tokenize_tag_end(context) do
        {:ok, %__MODULE__{loc: loc}, context}
      end
    end

    defimpl Solid.Renderable do
      @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
      def render(tag, context, _options) do
        render_context = Registers.fetch!(context)

        {"",
         Registers.report(
           context,
           RenderError.new(
             {:invalid_tag, "boom", "this tag always fails"},
             render_context.source_path,
             tag.loc
           )
         )}
      end
    end
  end

  defmodule ShoutingPass do
    @moduledoc """
    An AST pass: it upper-cases every piece of text, which is visible in the
    body of a block tag as well as in the page, since a pass runs over both.
    """

    @behaviour ArchiDep.CourseSite.Renderer.AstPass

    @impl ArchiDep.CourseSite.Renderer.AstPass
    def run(document, _context),
      do:
        {MDEx.Document.update_nodes(document, MDEx.Text, fn %MDEx.Text{} = text ->
           %{text | literal: String.upcase(text.literal)}
         end), []}
  end

  defmodule FailingPass do
    @moduledoc """
    An AST pass that leaves the document alone and reports a problem, the way a
    pass does when the page refers to an image that is not there.
    """

    @behaviour ArchiDep.CourseSite.Renderer.AstPass

    @impl ArchiDep.CourseSite.Renderer.AstPass
    def run(document, context),
      do:
        {document,
         [RenderError.new({:invalid_tag, "pass", "this pass always fails"}, context.source_path)]}
  end

  defmodule SignaturePass do
    @moduledoc """
    An HTML pass, which sees the finished page rather than one document of it.
    """

    @behaviour ArchiDep.CourseSite.Renderer.HtmlPass

    @impl ArchiDep.CourseSite.Renderer.HtmlPass
    def run(html, _context), do: {html <> "<!-- signed -->", []}
  end

  @doc """
  The renderer's own tags plus the ones defined here.
  """
  @spec tags() :: %{String.t() => module()}
  def tags do
    Map.merge(Tags.default(), %{
      "prose" => ProseTag,
      "code" => CodeTag,
      "boom" => FailingTag
    })
  end
end
