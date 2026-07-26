defmodule ArchiDep.CourseSite.Renderer.AssetReferences do
  @moduledoc """
  The files an author writes next to a document, resolved to the names they are
  published under.

  An author writes `images/cli.jpg` and the build digests the file, so the name
  in the reference is not the name in the output and every such reference has to
  go through `ArchiDep.CourseSite.Urls`. Most of them are written in Markdown
  and are rewritten on the document (`ArchiDep.CourseSite.Renderer.PageAssets`);
  this module is for the ones that are written as text and never reach a
  document: the raw HTML a page embeds, and a slide deck, which is handed to the
  browser as Markdown.

  Only a reference that could be a file next to the document is looked up: a
  relative path with no scheme, no query and no fragment. Everything else a
  document refers to — the site's own pages, the assets of the build, another
  site — is written differently and left exactly as it is.

  **An image is a file and a link may be one**, which is what a missing file
  means here. An image the build has no file for is a page showing a picture
  that is not there, and is reported. A link is written the same way whether it
  points at a file or at another page of the course — `dns-configuration.md` and
  `../cli/` are both links a chapter writes — so one that resolves to no file is
  taken to be a link to a page and left exactly as written.

  Resolving twice is resolving once (see
  `ArchiDep.CourseSite.Urls.PageAssetManifest`), which is what makes this safe
  to run over text the Liquid stage has already resolved references in: a
  reference written with `relative_file_url` comes out of that stage digested,
  and this sweep hands it back unchanged.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Sweep
  alias ArchiDep.CourseSite.Urls

  # Where a reference is written, in three pieces: what comes before it, the
  # reference itself, and what comes after. A rewrite is then the reference
  # replaced between what surrounded it, whatever quoting or syntax that was.
  @src Regex.compile!(~S{(?|(\ssrc\s*=\s*")([^"]*)(")|(\ssrc\s*=\s*')([^']*)('))}, "i")
  @href Regex.compile!(~S{(?|(\shref\s*=\s*")([^"]*)(")|(\shref\s*=\s*')([^']*)('))}, "i")
  @image_destination Regex.compile!(~S{(!\[[^\]]*\]\()([^)\s]+)((?:\s+"[^"]*")?\))})
  @link_destination Regex.compile!(~S{((?<!!)\[[^\]]*\]\()([^)\s]+)((?:\s+"[^"]*")?\))})

  # The markup a page embeds cannot be code shown as markup, and a deck writes
  # code the way Markdown does as well. Tags are protected in neither: a
  # reference lives in a tag's attributes, which is the whole point of looking.
  @in_html Sweep.compile([:code_markup, :comments])
  @in_markdown Sweep.compile([:fences, :code_markup, :comments, :inline_code])

  @doc """
  Resolve the references to files next to the document written in a fragment of
  raw HTML, or in the Markdown of a slide deck.
  """
  @spec rewrite(String.t(), :html | :markdown, RenderContext.t()) ::
          {String.t(), [RenderError.t()]}
  def rewrite(text, syntax, %RenderContext{} = context) when is_binary(text) do
    written = written(syntax)
    parts = Sweep.split(text, sweep(syntax))

    {urls, errors} = urls(Sweep.text(parts), written, context)

    {Sweep.map_text(parts, &resolved_in(&1, written, urls)), errors}
  end

  @doc """
  Every URL written in a fragment of raw HTML, or in the Markdown of a slide
  deck, outside the regions a rewrite must leave alone.

  This is what `rewrite/3` looks at before it decides which of those URLs could
  be a file next to the document. A caller that has a different question to ask
  of them — whether they lead anywhere, say — asks it of this list, so that
  what a build checks and what it rewrites are read out of the text the same
  way.
  """
  @spec references(String.t(), :html | :markdown) :: [{String.t(), :image | :link}]
  def references(text, syntax) when is_binary(text) do
    text
    |> Sweep.split(sweep(syntax))
    |> Sweep.text()
    |> Enum.flat_map(&written_in(&1, written(syntax)))
    |> Enum.uniq()
  end

  @doc """
  Resolve one reference, written where the whole of what is written is the
  reference: the URL of an image or of a link of a Markdown document.

  A URL that could not be a file next to the document is handed back as it is,
  so that the caller can hand over every URL it has without asking what kind it
  is first.
  """
  @spec resolve(String.t(), :image | :link, RenderContext.t()) ::
          {String.t(), [RenderError.t()]}
  def resolve(reference, kind, %RenderContext{} = context) when is_binary(reference) do
    if reference?(reference) do
      resolved_reference(reference, kind, context)
    else
      {reference, []}
    end
  end

  defp resolved_reference(reference, kind, context) do
    case Urls.resolve(context.urls, {:page_asset, context.page, reference}, context.page) do
      {:ok, url} -> {url, []}
      {:error, error} -> {reference, missing(kind, error, context)}
    end
  end

  defp missing(:image, error, context),
    do: [RenderError.new({:url, error}, context.source_path)]

  defp missing(:link, _error, _context), do: []

  defp sweep(:html), do: @in_html
  defp sweep(:markdown), do: @in_markdown

  # Markdown's own syntax is only looked for where the text is Markdown: a
  # page's raw HTML sits inside a document whose images and links were resolved
  # on the document itself.
  defp written(:html), do: [{@src, :image}, {@href, :link}]

  defp written(:markdown),
    do: [{@src, :image}, {@href, :link}, {@image_destination, :image}, {@link_destination, :link}]

  defp resolved_in(words, written, urls) do
    Enum.reduce(written, words, fn {pattern, _kind}, rewritten ->
      Regex.replace(pattern, rewritten, &resolved(&1, &2, &3, &4, urls))
    end)
  end

  defp resolved(written, before, path, rest, urls) do
    case Map.fetch(urls, path) do
      {:ok, url} -> before <> url <> rest
      :error -> written
    end
  end

  # Where every file the text refers to is published, worked out once: a
  # document referring to the same image twice is one reference as far as the
  # build and its problems are concerned. A file that is both shown and linked
  # to is reported for the image alone, since that is where it has to be there.
  defp urls(words, written, context) do
    words
    |> Enum.flat_map(&referenced_in(&1, written))
    |> Enum.uniq()
    |> Enum.reduce({%{}, []}, fn {path, kind}, {urls, errors} ->
      {url, path_errors} = resolved_reference(path, kind, context)
      {Map.put(urls, path, url), errors ++ path_errors}
    end)
  end

  defp referenced_in(words, written),
    do: words |> written_in(written) |> Enum.filter(fn {path, _kind} -> reference?(path) end)

  defp written_in(words, written) do
    Enum.flat_map(written, fn {pattern, kind} ->
      pattern
      |> Regex.scan(words, capture: :all_but_first)
      |> Enum.map(fn [_before, path, _rest] -> {path, kind} end)
    end)
  end

  # A page of the site, an asset of the build and a heading are all written from
  # the root or as a fragment; another site carries a scheme, which is the one
  # thing `Urls` reads a colon as.
  defp reference?(path),
    do: not String.starts_with?(path, "/") and not String.contains?(path, [":", "#", "?"])
end
