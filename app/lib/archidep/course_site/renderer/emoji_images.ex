defmodule ArchiDep.CourseSite.Renderer.EmojiImages do
  @moduledoc """
  Turns the emoji a page is written with into the images the site draws them as.

  A page writes an emoji in one of two ways and both end up here: as the
  shortcode the course material has always used — `:books:` — or as the
  character itself, which is how a handful of chapters and the application write
  it. Both become the same `<img>`, so that one emoji is one picture wherever it
  is written. Which emoji exist, and what one looks like, is `ArchiDep.Emoji`'s
  to say.

  It sweeps the finished page rather than the document because a block tag
  writes its icon into the wrapper it puts around its body, which was never
  Markdown. And it is not a rewrite a build may do without: a heading's
  shortcodes are moved out of the text its identifier is slugged from by
  `ArchiDep.CourseSite.Renderer.HeadingIdentifiers` on the understanding that
  something later draws them, so a page rendered without this one carries
  anchors named for a decoration it goes on to show as text.

  ## What it leaves alone

  Code is never swept. The course teaches the command line, and
  `404-unix-basics` alone holds six `/etc/passwd` lines such as `jde:x:1004:`
  that are shortcode-shaped by accident; elsewhere sit timestamps like `:00:`
  and the `:--:` of a table's alignment row.

  A shortcode that names no emoji of the site is left as it is, which is what
  keeps those accidents intact wherever they are written outside code. A
  character that is not one of the site's emoji is left alone too, but reported:
  the vocabulary is a closed one, and an emoji nobody added to it would
  otherwise be the one thing on the page that looks different in every browser.
  """

  @behaviour ArchiDep.CourseSite.Renderer.HtmlPass

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.Emoji

  # A region of the page the sweep does not look into, or a tag it must not look
  # inside of: an emoji is written in a page's words, never in its markup.
  @protected ~r{<(pre|code|script|style)\b[^>]*>.*?</\1>|<!--.*?-->|<[^>]*>}s

  # An emoji as a page writes it: the shortcode the content spells it with, or
  # the character itself. The shortcode has to open the text or stand after a
  # space, which is the rule `HeadingIdentifiers` reads a heading by — the two
  # must agree on what a shortcode is, or a heading would lose a decoration from
  # its identifier that is never drawn.
  #
  # Both are matched in one pass because the image an emoji becomes names the
  # character it draws: sweeping twice would find the second kind inside what
  # the first left behind.
  @written Regex.compile!(
             "(?<=\\A|\\s):([a-z0-9_+-]+):|" <> Regex.source(Emoji.pattern()),
             "su"
           )

  @doc """
  Draw the emoji of a rendered page.
  """
  @impl ArchiDep.CourseSite.Renderer.HtmlPass
  @spec run(String.t(), RenderContext.t()) :: {String.t(), [RenderError.t()]}
  def run(html, %RenderContext{} = context) when is_binary(html) do
    parts = Regex.split(@protected, html, include_captures: true)
    words = Enum.reject(parts, &protected?/1)

    {urls, url_errors} = urls(words, context)

    {Enum.map_join(parts, &draw(&1, urls)), url_errors ++ unregistered(words, context)}
  end

  # Every part of the split that is not a match of the protected pattern is the
  # page's own words; a match always opens with the `<` that started it.
  defp protected?(part), do: String.starts_with?(part, "<")

  defp draw(part, urls) do
    if protected?(part) do
      part
    else
      Regex.replace(@written, part, &image(&1, &2, urls))
    end
  end

  # A shortcode is replaced by the emoji it names and a character by the emoji
  # it is; what names none of the site's emoji is left as the page wrote it.
  defp image(written, "", urls), do: drawn(Emoji.fetch_by_character(written), written, urls)
  defp image(written, name, urls), do: drawn(Emoji.fetch(name), written, urls)

  defp drawn({:ok, emoji}, written, urls) do
    case Map.fetch(urls, emoji.name) do
      {:ok, url} -> Emoji.img(emoji, url)
      :error -> written
    end
  end

  defp drawn(:error, written, _urls), do: written

  # Where each emoji the page writes is drawn from, worked out once for the
  # whole page: an image the build cannot find the file of is a problem with the
  # build rather than with the page, and saying so once is enough.
  defp urls(words, context) do
    words
    |> Enum.flat_map(&emoji_written_in/1)
    |> Enum.uniq()
    |> Enum.reduce({%{}, []}, fn emoji, {urls, errors} ->
      case Urls.resolve(context.urls, {:asset, Emoji.asset_path(emoji)}, context.page) do
        {:ok, url} ->
          {Map.put(urls, emoji.name, url), errors}

        {:error, error} ->
          {urls, errors ++ [RenderError.new({:url, error}, context.source_path)]}
      end
    end)
  end

  defp emoji_written_in(words) do
    @written
    |> Regex.scan(words)
    |> Enum.flat_map(fn
      [_written, name] -> found(Emoji.fetch(name))
      [written] -> found(Emoji.fetch_by_character(written))
    end)
  end

  defp found({:ok, emoji}), do: [emoji]
  defp found(:error), do: []

  defp unregistered(words, context) do
    words
    |> Enum.flat_map(&Emoji.unregistered_characters_in/1)
    |> Enum.uniq()
    |> Enum.map(&RenderError.new({:unregistered_emoji, &1}, context.source_path))
  end
end
