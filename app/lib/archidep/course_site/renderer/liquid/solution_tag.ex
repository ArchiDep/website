defmodule ArchiDep.CourseSite.Renderer.Liquid.SolutionTag do
  @moduledoc """
  `{% solution %}` — the answer to the exercise above it, collapsed on screen so
  that a reader scrolling past does not read it by accident, and open on paper
  where there is nothing to click.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody

  @enforce_keys [:loc, :body]
  defstruct [:loc, :body]

  @type t :: %__MODULE__{loc: Solid.Lexer.loc(), body: Solid.Parser.parse_tree()}

  @impl Solid.Tag
  def parse("solution", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, _attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endsolution") do
      {:ok, %__MODULE__{loc: loc, body: body}, context}
    end
  end

  defimpl Solid.Renderable do
    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context, options) do
      {body, context} = NestedBody.to_html(tag.body, context, options)

      {~s(<div class="solution collapse screen:collapse-arrow print:collapse-open ) <>
         ~s(border border-neutral hover:bg-primary/25">) <>
         ~s(<input type="checkbox" />) <>
         ~s(<div class="collapse-title font-semibold">) <>
         ~s(<div class="flex items-center gap-2">:key:<span>Solution</span></div>) <>
         ~s(</div>) <>
         ~s(<div class="collapse-content overflow-x-auto">#{body}</div>) <>
         ~s(</div>), context}
    end
  end
end
