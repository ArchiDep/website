defmodule ArchiDep.CourseSite.Renderer.Liquid.SolutionTag do
  @moduledoc """
  `{% solution %}` — the answer to the exercise above it, collapsed on screen so
  that a reader scrolling past does not read it by accident, and open on paper
  where there is nothing to click. `title` overrides the "Solution" it is
  labelled with, and `emoji` the key it is shown with, by the name of one of the
  site's emoji (`emoji: thinking`).

  An answer is only shown once the course has covered the chapter it is in. A
  withheld one is **left out of the page entirely** rather than folded away or
  hidden by a stylesheet, because a page's source is there to be read: a
  solution a student can find by looking at the markup is not withheld at all.
  The decision arrives already made, as
  `ArchiDep.CourseSite.Renderer.RenderContext`'s `solutions`, so this tag knows
  neither how far the course has got nor where the threshold is.

  `reveal: always` is the exception an author makes for an answer that is meant
  to be read straight away, such as the check of a prediction the exercise has
  just asked for: it is shown whatever the chapter's progress, and is in the
  page's source from the start.

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
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Emoji

  @default_title "Solution"

  # Naming the emoji rather than spelling its shortcode out is what makes one
  # the site does not have a broken build rather than a page showing `:key:` in
  # words, which is what the rest of the site's tags do through
  # `ArchiDep.CourseSite.Renderer.Liquid.TagIcon`.
  @default_emoji Emoji.fetch!("key")

  @enforce_keys [:loc, :title, :emoji, :always?, :body, :problems]
  defstruct [:loc, :title, :emoji, :always?, :body, :problems]

  @type t :: %__MODULE__{
          loc: Solid.Lexer.loc(),
          title: String.t(),
          emoji: Emoji.t(),
          always?: boolean(),
          body: Solid.Parser.parse_tree(),
          problems: [RenderError.reason()]
        }

  @impl Solid.Tag
  def parse("solution", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endsolution") do
      {always?, reveal_problems} = reveal(attributes)
      {emoji, emoji_problems} = emoji(attributes)

      {:ok,
       %__MODULE__{
         loc: loc,
         title: title(attributes),
         emoji: emoji,
         always?: always?,
         body: body,
         problems: reveal_problems ++ emoji_problems
       }, context}
    end
  end

  # A `reveal` the tag does not know is treated as absent, so the answer stays
  # withheld like any other, and the value the author wrote is reported: a typo
  # must not publish an answer early.
  defp reveal(attributes) do
    case Map.get(attributes, "reveal") do
      nil ->
        {false, []}

      "always" ->
        {true, []}

      unknown ->
        {false,
         [
           {:invalid_tag, "solution",
            ~s(Unknown reveal #{inspect(unknown)}, the only one is "always")}
         ]}
    end
  end

  # An emoji the site does not have is reported, and the answer is shown with
  # the key it would have had without one: the page still reads, and the build
  # still fails on the typo.
  defp emoji(attributes) do
    case Map.fetch(attributes, "emoji") do
      :error ->
        {@default_emoji, []}

      {:ok, name} ->
        case name |> to_string() |> Emoji.fetch() do
          {:ok, emoji} ->
            {emoji, []}

          :error ->
            {@default_emoji, [{:invalid_tag, "solution", "Unknown emoji #{inspect(name)}"}]}
        end
    end
  end

  defp title(attributes) do
    case attributes |> Map.get("title", "") |> to_string() |> String.trim() do
      "" -> @default_title
      title -> title
    end
  end

  defimpl Solid.Renderable do
    alias ArchiDep.Emoji

    @outside_a_chapter "only a chapter has an exercise for a solution to answer"

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context!, options) do
      context! = Registers.report(context!, tag.problems, tag.loc)

      # The body is rendered whatever becomes of it, and thrown away when the
      # answer is withheld. What it refers to — a link to another chapter, an
      # image beside the page — is resolved here and nowhere else, so a build
      # that rendered only the answers it shows would stop checking the rest and
      # publish the first one it revealed with a broken reference in it.
      {body, context!} = NestedBody.to_html(tag.body, context!, options)

      case Registers.fetch!(context!) do
        %RenderContext{page: {:document, %DocumentRef{}}} when tag.always? ->
          {solution(tag, body), context!}

        %RenderContext{page: {:document, %DocumentRef{}}, solutions: :revealed} ->
          {solution(tag, body), context!}

        %RenderContext{page: {:document, %DocumentRef{}}} ->
          {"", context!}

        %RenderContext{} ->
          {"",
           Registers.report(context!, {:invalid_tag, "solution", @outside_a_chapter}, tag.loc)}
      end
    end

    defp solution(tag, body),
      do:
        ~s(<div class="solution collapse screen:collapse-arrow print:collapse-open ) <>
          ~s(border border-neutral">) <>
          ~s(<input type="checkbox" class="peer" />) <>
          ~s(<div class="collapse-title font-semibold peer-hover:bg-primary/25">) <>
          ~s(<div class="flex items-center gap-2">#{Emoji.shortcode(tag.emoji)}<span>#{tag.title}</span></div>) <>
          ~s(</div>) <>
          ~s(<div class="collapse-content overflow-x-auto">#{body}</div>) <>
          ~s(</div>)
  end
end
