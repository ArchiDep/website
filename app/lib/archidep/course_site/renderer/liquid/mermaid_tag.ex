defmodule ArchiDep.CourseSite.Renderer.Liquid.MermaidTag do
  @moduledoc """
  `{% mermaid %}` — a diagram, drawn in the browser from the description this
  tag puts on the page.

  It is the one block tag of the course whose body is not prose: a diagram is
  drawn from source, so the body is captured verbatim and nothing inside it is
  expanded or converted. That it lands in a `pre` element is what lets it keep
  the blank lines a diagram may contain, which anywhere else would end the
  wrapper's HTML block.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.RawBody

  @enforce_keys [:loc, :body]
  defstruct [:loc, :body]

  @type t :: %__MODULE__{loc: Solid.Lexer.loc(), body: String.t()}

  @impl Solid.Tag
  def parse("mermaid", loc, context) do
    with {:ok, _tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, body, context} <- RawBody.parse(context, "endmermaid") do
      {:ok, %__MODULE__{loc: loc, body: body}, context}
    end
  end

  defimpl Solid.Renderable do
    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context, _options),
      do: {~s(<pre class="mermaid loading">#{tag.body}</pre>), context}
  end
end
