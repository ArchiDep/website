defmodule ArchiDep.CourseSite.Renderer.Liquid.MarkdownTag do
  @moduledoc """
  `{% markdown %}` — a piece of the page converted on its own, wrapped in
  nothing but a plain block.

  It is the escape hatch of the set: it exists so that Markdown can be written
  where the page around it would not convert it, which is anywhere inside raw
  HTML the content writes by hand.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody

  @enforce_keys [:loc, :body]
  defstruct [:loc, :body]

  @type t :: %__MODULE__{loc: Solid.Lexer.loc(), body: Solid.Parser.parse_tree()}

  @impl Solid.Tag
  def parse("markdown", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, _attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endmarkdown") do
      {:ok, %__MODULE__{loc: loc, body: body}, context}
    end
  end

  defimpl Solid.Renderable do
    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context, options) do
      {body, context} = NestedBody.to_html(tag.body, context, options)
      {~s(<div class="markdown">#{body}</div>), context}
    end
  end
end
