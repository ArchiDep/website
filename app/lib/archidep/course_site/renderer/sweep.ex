defmodule ArchiDep.CourseSite.Renderer.Sweep do
  @moduledoc """
  What a rewrite of the text may look at, and what it must leave alone.

  Several rewrites of the course material are scans of text rather than walks of
  a tree: there is no HTML library outside the test environment, and a slide
  deck is never converted to HTML at all. Each of them needs the same thing
  first — the text cut into the parts it may rewrite and the parts it may not —
  and they do not agree on what those are, which is why the regions are named
  and chosen by the caller:

  | Region         | What it protects                                          |
  | -------------- | --------------------------------------------------------- |
  | `:code_markup` | a `pre`, `code`, `script` or `style` element and its text |
  | `:comments`    | an HTML comment                                           |
  | `:tags`        | every tag, so that a rewrite sees only the words          |
  | `:fences`      | a fenced code block, backticks or tildes                  |
  | `:inline_code` | code written between backticks                            |

  Emoji are written in a page's words, so a page's tags are protected from that
  sweep. The URL of an image is written in a tag's attributes, so tags are the
  one thing that sweep is there to look inside. And a deck, being Markdown,
  protects what Markdown writes code with on top of what markup writes it with.

  A region is a fragment of a pattern rather than a pattern of its own, which is
  what lets them be composed: they refer to what they matched relatively
  (`\\g{-1}`), so a region does not care how many groups the regions before it
  opened.
  """

  @region_sources %{
    fences: ~S'(?m)^[ \t]{0,3}(`{3,}|~{3,})[^\n]*\n.*?(?:^[ \t]{0,3}\g{-1}[ \t]*(?:\n|\z)|\z)',
    code_markup: ~S'<(pre|code|script|style)\b[^>]*>.*?</\g{-1}>',
    comments: ~S'<!--.*?-->',
    inline_code: ~S'(`+)(?:[^`]|(?!\g{-1})`)*\g{-1}',
    tags: ~S'<[^>]*>'
  }

  # A region that stands for a whole element must be tried before the tag that
  # opens it, or the text of a code block would be swept as if it were prose.
  @region_order [:fences, :code_markup, :comments, :inline_code, :tags]

  @type region :: :code_markup | :comments | :tags | :fences | :inline_code
  @type t :: Regex.t()
  @type part :: {:text, String.t()} | {:protected, String.t()}

  @doc """
  What a sweep protects, compiled once from the regions it names.

  Meant to be called where the sweep is defined rather than where it runs, so
  that the pattern is built once instead of once per document.

      iex> Sweep.split("Text with <code>:books:</code>.", Sweep.compile([:code_markup]))
      [{:text, "Text with "}, {:protected, "<code>:books:</code>"}, {:text, "."}]
  """
  @spec compile([region()]) :: t()
  def compile(regions) when is_list(regions) do
    known!(regions)

    @region_order
    |> Enum.filter(&(&1 in regions))
    |> Enum.map_join("|", &Map.fetch!(@region_sources, &1))
    |> Regex.compile!("su")
  end

  @doc """
  Cut text into the parts a sweep may rewrite and the parts it must leave alone.

      iex> Sweep.split("`code` and prose", Sweep.compile([:inline_code]))
      [{:text, ""}, {:protected, "`code`"}, {:text, " and prose"}]
  """
  @spec split(String.t(), t()) :: [part()]
  def split(text, %Regex{} = sweep) when is_binary(text) do
    sweep
    |> Regex.split(text, include_captures: true)
    |> Enum.with_index()
    |> Enum.map(fn {part, index} -> {kind(rem(index, 2)), part} end)
  end

  @doc """
  The parts of split text that may be rewritten.

      iex> Sweep.text(Sweep.split("A <b>bold</b> claim", Sweep.compile([:tags])))
      ["A ", "bold", " claim"]
  """
  @spec text([part()]) :: [String.t()]
  def text(parts) when is_list(parts), do: for({:text, part} <- parts, do: part)

  @doc """
  Rewrite the parts of split text that may be rewritten, putting the rest back
  as it was.

  A sweep works out what it is going to write from the whole of what it may
  look at — a URL a page refers to twice is resolved once — which is why the
  text is split, then read, then rewritten.

      iex> "shout <b>quietly</b>" |> Sweep.split(Sweep.compile([:tags])) |> Sweep.map_text(&String.upcase/1)
      "SHOUT <b>QUIETLY</b>"
  """
  @spec map_text([part()], (String.t() -> String.t())) :: String.t()
  def map_text(parts, fun) when is_list(parts) and is_function(fun, 1),
    do: Enum.map_join(parts, &mapped(&1, fun))

  # A split that includes its captures alternates the two, starting and ending
  # with text, so a part's kind is its position rather than something to sniff
  # out of what it looks like.
  defp kind(0), do: :text
  defp kind(1), do: :protected

  defp mapped({:text, part}, fun), do: fun.(part)
  defp mapped({:protected, part}, _fun), do: part

  defp known!(regions) do
    case Enum.reject(regions, &Map.has_key?(@region_sources, &1)) do
      [] -> :ok
      unknown -> raise ArgumentError, "No such region to protect: #{inspect(unknown)}"
    end
  end
end
