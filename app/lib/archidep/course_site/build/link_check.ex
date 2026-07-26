defmodule ArchiDep.CourseSite.Build.LinkCheck do
  @moduledoc """
  The relative URLs of a build that lead nowhere.

  Digesting a file makes a stale reference to it fail loudly, and the renderer
  reports every reference it could not resolve — but one kind of reference is
  deliberately left alone. A relative link is written the same way whether it
  points at a file or at another page of the course, so
  `ArchiDep.CourseSite.Renderer.AssetReferences` takes one that resolves to no
  file to be a link to a page and emits it exactly as its author wrote it. This
  is what looks at those afterwards, when there is a finished build to compare
  them against.

  It is told what the build wrote rather than reading the output directory, and
  in the same coordinates the rest of the subsystem speaks: an output path with
  a leading slash, no mount point and no edition prefix. So a check needs
  neither a filesystem nor a `ArchiDep.CourseSite.Urls.UrlContext`, and it
  cannot disagree with `ArchiDep.CourseSite.Urls` about what a path means — it
  resolves one with the same arithmetic.

  **A page is read as HTML and a deck as the Markdown it stays.** An HTML parser
  hands back the content of a `textarea` as text, and a deck is handed to the
  browser as the text of one, so a deck read as part of its page would have
  every reference in it invisible. It is read as itself instead, with the same
  scan the rewrite of a deck uses.
  """

  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer.AssetReferences
  alias ArchiDep.CourseSite.Urls.UrlPath

  @typedoc """
  One thing the build wrote: which page it is, whether it is the page's HTML or
  a deck's Markdown, and what it says.
  """
  @type page :: {PageRef.t(), :html | :markdown, String.t()}

  @type reason :: {:missing, String.t()} | :escapes_root

  @type broken :: {PageRef.t(), String.t(), reason()}

  # Where a URL is written in HTML. `src` and `href` are what the course writes
  # today and what the rewrite covers; the rest are here because this is the
  # cheap half of the pair — a page that starts writing one is caught rather
  # than published broken.
  @url_attributes ~w(src href srcset poster data action formaction cite background)

  @doc """
  Every relative URL of the build that resolves to nothing it wrote.

  `files` is every path the build wrote, as an output path. A page directory is
  read as the `index.html` inside it, which is how the site is served.
  """
  @spec check([page()], MapSet.t(String.t())) :: [broken()]
  def check(pages, files) when is_list(pages) do
    pages
    |> Enum.flat_map(&broken_in(&1, files))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Describe a URL that leads nowhere, for a build that has to report it.
  """
  @spec format_error(broken()) :: String.t()
  def format_error({page, url, {:missing, target}}),
    do:
      "Page #{PageRef.output_path(page)} links to #{inspect(url)}, and the build wrote nothing at #{inspect(target)}"

  def format_error({page, url, :escapes_root}),
    do:
      "Page #{PageRef.output_path(page)} links to #{inspect(url)}, which climbs above the root of the site"

  defp broken_in({page, syntax, text}, files) do
    text
    |> urls(syntax)
    |> Enum.filter(&relative?/1)
    |> Enum.flat_map(&broken_url(page, &1, files))
  end

  defp urls(html, :html) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("*")
    |> LazyHTML.attributes()
    |> Enum.flat_map(fn attributes ->
      for {name, value} <- attributes, name in @url_attributes, do: value
    end)
  end

  defp urls(markdown, :markdown),
    do: markdown |> AssetReferences.references(:markdown) |> Enum.map(&elem(&1, 0))

  # A URL of another site carries a scheme, one of the build's own assets or
  # pages is written from the root, and a fragment alone names the page it is
  # written on. Only what is written relative to the page can be resolved here
  # at all.
  defp relative?(url) do
    url != "" and not String.starts_with?(url, ["/", "#", "?"]) and
      not Regex.match?(~r{\A[a-zA-Z][a-zA-Z0-9+.-]*:}, url)
  end

  defp broken_url(page, url, files) do
    path = url |> String.split(["#", "?"], parts: 2) |> hd()

    if path == "" do
      []
    else
      resolve(page, url, path, files)
    end
  end

  defp resolve(page, url, path, files) do
    # A URL is emitted percent-encoded, and a path on disk is not.
    decoded = URI.decode(path)

    case page |> PageRef.output_path() |> UrlPath.join(decoded) |> UrlPath.normalize() do
      {:ok, resolved} ->
        target = target(resolved)
        if MapSet.member?(files, target), do: [], else: [{page, url, {:missing, target}}]

      {:error, :escapes_root} ->
        [{page, url, :escapes_root}]
    end
  end

  # A page is a directory of the build and the file inside it is what a server
  # answers with.
  defp target(resolved) do
    if String.ends_with?(resolved, "/"), do: resolved <> "index.html", else: resolved
  end
end
