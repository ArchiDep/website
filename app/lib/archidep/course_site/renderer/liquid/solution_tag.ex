defmodule ArchiDep.CourseSite.Renderer.Liquid.SolutionTag do
  @moduledoc """
  `{% solution %}` — the answer to the exercise above it, collapsed on screen so
  that a reader scrolling past does not read it by accident, and open on paper
  where there is nothing to click.

  An answer is only shown once the course has covered the chapter it is in. A
  withheld one is **left out of the page entirely** rather than folded away or
  hidden by a stylesheet, because a page's source is there to be read: a
  solution a student can find by looking at the markup is not withheld at all.
  The decision arrives already made, as
  `ArchiDep.CourseSite.Renderer.RenderContext`'s `solutions`, so this tag knows
  neither how far the course has got nor where the threshold is.

  A solution is an answer to an exercise, and only a chapter has one. On the
  home page or in a cheatsheet there is nothing for it to answer and no status
  that could ever reveal it, so it is refused rather than shown.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody
  alias ArchiDep.CourseSite.Renderer.Liquid.Registers
  alias ArchiDep.CourseSite.Renderer.RenderContext

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
    alias ArchiDep.Emoji

    # Naming the emoji rather than spelling its shortcode out is what makes one
    # the site does not have a broken build rather than a page showing `:key:`
    # in words, which is what the rest of the site's tags do through
    # `ArchiDep.CourseSite.Renderer.Liquid.TagIcon`.
    @key Emoji.shortcode(Emoji.fetch!("key"))

    @outside_a_chapter "only a chapter has an exercise for a solution to answer"

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context, options) do
      # The body is rendered whatever becomes of it, and thrown away when the
      # answer is withheld. What it refers to — a link to another chapter, an
      # image beside the page — is resolved here and nowhere else, so a build
      # that rendered only the answers it shows would stop checking the rest and
      # publish the first one it revealed with a broken reference in it.
      {body, context} = NestedBody.to_html(tag.body, context, options)

      case Registers.fetch!(context) do
        %RenderContext{page: {:document, %DocumentRef{}}, solutions: :revealed} ->
          {solution(body), context}

        %RenderContext{page: {:document, %DocumentRef{}}} ->
          {"", context}

        %RenderContext{} ->
          {"", Registers.report(context, {:invalid_tag, "solution", @outside_a_chapter}, tag.loc)}
      end
    end

    defp solution(body),
      do:
        ~s(<div class="solution collapse screen:collapse-arrow print:collapse-open ) <>
          ~s(border border-neutral hover:bg-primary/25">) <>
          ~s(<input type="checkbox" />) <>
          ~s(<div class="collapse-title font-semibold">) <>
          ~s(<div class="flex items-center gap-2">#{@key}<span>Solution</span></div>) <>
          ~s(</div>) <>
          ~s(<div class="collapse-content overflow-x-auto">#{body}</div>) <>
          ~s(</div>)
  end
end
