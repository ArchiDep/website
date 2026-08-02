defmodule ArchiDep.CourseSite.Urls do
  @moduledoc """
  Turns the logical references emitted by the course material renderer into the
  URLs of one particular build.

  Nothing else in the rendering pipeline may concatenate a prefix onto a path.
  The renderer emits a reference — "the exercise of chapter 402", "the image
  next to this page" — and this module answers with a string, so that the
  deployment mount point, the edition prefix, asset digests and the absolute
  base URL used by the PDF export are decided in exactly one place. Every build
  is a `ArchiDep.CourseSite.Urls.UrlContext`, not a variation of the renderer.

  ## References

  | Reference                   | Meaning                                                 |
  | --------------------------- | ------------------------------------------------------- |
  | `:home`                     | the course home page                                    |
  | `{:document, ref}`          | a course document                                       |
  | `{:cheatsheet, slug}`       | a cheatsheet                                            |
  | `{:heading, page, id}`      | a heading within a page                                 |
  | `{:page_asset, page, path}` | a file co-located with a page                           |
  | `{:asset, path}`            | a global asset: a stylesheet, a script, a font          |
  | `{:site_file, path}`        | a file emitted at the root of the build                 |
  | `{:build_file, path}`       | ditto, named after the build that produced it           |
  | `{:pdf, page}`              | the generated PDF of a page                             |
  | `{:root_file, path}`        | a file anchored at the mount point, e.g. a favicon      |
  | `{:live_site, page}`        | this page on the current edition's own site             |
  | `{:current_edition, page}`  | whatever superseded this page, resolved at request time |
  | `{:external, url}`          | passthrough                                             |

  ## What each reference is subject to

  | Reference                                  | Edition prefix                                         | Digested | Absolute base URL |
  | ------------------------------------------ | ------------------------------------------------------ | -------- | ----------------- |
  | `:home`                                    | mount point while taught, edition prefix once archived | no       | yes               |
  | `{:document, _}`, `{:cheatsheet, _}`       | yes                                                    | no       | yes               |
  | `{:heading, _, _}`                         | yes, unless it is a heading of the page being rendered | no       | ditto             |
  | `{:page_asset, _, _}`                      | no — document-relative                                 | yes      | no                |
  | `{:asset, _}`                              | yes                                                    | yes      | no                |
  | `{:site_file, _}`                          | yes                                                    | no       | no                |
  | `{:build_file, _}`                         | yes                                                    | build ID | no                |
  | `{:pdf, _}`                                | yes, unless published externally                       | no       | no                |
  | `{:root_file, _}`                          | never — mount point only                               | no       | no                |
  | `{:live_site, _}`, `{:current_edition, _}` | always absolute, against the current edition's site    | no       | n/a               |

  Two of those rows are what make the site addressable from anywhere: **content
  links may be absolutized while assets never are**, so a build can be served
  from a throwaway local server and still print links to the main site; and
  **assets co-located with a page stay relative to it**, so they are immune to
  the mount point, the edition prefix and the origin alike.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSite.Urls.UrlError
  alias ArchiDep.CourseSite.Urls.UrlPath

  @type logical_reference ::
          :home
          | {:document, DocumentRef.t()}
          | {:cheatsheet, String.t()}
          | {:heading, PageRef.t(), String.t()}
          | {:page_asset, PageRef.t(), String.t()}
          | {:asset, String.t()}
          | {:site_file, String.t()}
          | {:build_file, String.t()}
          | {:pdf, PageRef.t()}
          | {:root_file, String.t()}
          | {:live_site, PageRef.t()}
          | {:current_edition, PageRef.t()}
          | {:external, String.t()}

  @type error ::
          {:unknown_asset, String.t()}
          | {:unknown_page_asset, PageRef.t(), String.t(), String.t()}
          | {:unknown_pdf, PageRef.t()}
          | {:absolute_page_asset, PageRef.t(), String.t()}
          | {:invalid_page_asset, PageRef.t(), String.t()}
          | {:page_asset_outside_site, PageRef.t(), String.t()}
          | {:missing_live_site_url, logical_reference()}
          | {:missing_version, logical_reference()}
          | {:invalid_reference, term()}

  @doc """
  Resolve a logical reference to a URL, given the page being rendered.

  The page is what makes a heading of that same page resolve to a bare fragment,
  so that navigating within a page — or within an exported PDF — stays internal.
  Pass `nil` when resolving references from outside the course material itself,
  such as the application's own navigation.
  """
  @spec resolve(UrlContext.t(), logical_reference()) :: {:ok, String.t()} | {:error, error()}
  @spec resolve(UrlContext.t(), logical_reference(), PageRef.t() | nil) ::
          {:ok, String.t()} | {:error, error()}
  def resolve(context, reference, from \\ nil)

  def resolve(%UrlContext{} = context, :home, _from) do
    prefix =
      if UrlContext.home_at_base?(context) do
        context.base_path
      else
        UrlContext.content_prefix(context)
      end

    {:ok, UrlContext.content_origin(context) <> prefix <> "/"}
  end

  def resolve(%UrlContext{} = context, {:document, %DocumentRef{}} = reference, _from),
    do: {:ok, content_url(context, PageRef.output_path(reference))}

  def resolve(%UrlContext{} = context, {:cheatsheet, slug} = reference, _from)
      when is_binary(slug),
      do: {:ok, content_url(context, PageRef.output_path(reference))}

  def resolve(%UrlContext{}, {:heading, page, id}, page) when is_binary(id),
    do: {:ok, "##{id}"}

  # Every page reference is also a reference to that page's URL, so a heading of
  # another page resolves through that page.
  def resolve(%UrlContext{} = context, {:heading, page, id}, _from) when is_binary(id) do
    with {:ok, page_url} <- resolve(context, page, nil) do
      {:ok, "#{page_url}##{id}"}
    end
  end

  def resolve(%UrlContext{} = context, {:page_asset, page, path}, _from)
      when is_binary(path),
      do: page_asset_url(context, page, path)

  def resolve(%UrlContext{} = context, {:asset, path}, _from) when is_binary(path) do
    case AssetManifest.fetch(context.assets, path) do
      {:ok, digested} -> {:ok, UrlContext.content_prefix(context) <> digested}
      :error -> {:error, {:unknown_asset, path}}
    end
  end

  def resolve(%UrlContext{} = context, {:site_file, path}, _from) when is_binary(path),
    do: {:ok, UrlContext.content_prefix(context) <> "/" <> UrlPath.encode(path)}

  def resolve(%UrlContext{} = context, {:build_file, path}, _from) when is_binary(path) do
    versioned = UrlPath.insert_suffix(path, context.build_id)
    {:ok, UrlContext.content_prefix(context) <> "/" <> UrlPath.encode(versioned)}
  end

  def resolve(%UrlContext{} = context, {:pdf, page}, _from), do: pdf_url(context, page)

  def resolve(%UrlContext{} = context, {:root_file, path}, _from) when is_binary(path),
    do: {:ok, context.base_path <> "/" <> UrlPath.encode(path)}

  # The home page of an edition sits at the root of the live site while that
  # edition is being taught and moves under its own prefix once archived, which
  # is the rule `:home` follows for this build.
  def resolve(%UrlContext{} = context, {:live_site, :home} = reference, _from) do
    with {:ok, live_site_url} <- live_site_url(context, reference) do
      {:ok, live_site_url <> live_site_home_prefix(context) <> "/"}
    end
  end

  def resolve(%UrlContext{} = context, {:live_site, page} = reference, _from) do
    with {:ok, live_site_url} <- live_site_url(context, reference) do
      {:ok, live_site_url <> UrlContext.edition_prefix(context) <> PageRef.output_path(page)}
    end
  end

  def resolve(%UrlContext{} = context, {:current_edition, page} = reference, _from) do
    with {:ok, live_site_url} <- live_site_url(context, reference),
         {:ok, version} <- version(context, reference) do
      {:ok, "#{live_site_url}/latest/#{version}#{PageRef.output_path(page)}"}
    end
  end

  def resolve(%UrlContext{}, {:external, url}, _from) when is_binary(url), do: {:ok, url}

  def resolve(%UrlContext{}, reference, _from), do: {:error, {:invalid_reference, reference}}

  @doc """
  Resolve a logical reference to a URL, raising a
  `ArchiDep.CourseSite.Urls.UrlError` when it cannot be resolved.

  Use this where an unresolvable reference is a programmer error rather than a
  fact about the content, e.g. the application's own navigation, which refers to
  the course material through values that must exist. The build, which reports
  every broken reference of a document rather than stopping at the first, uses
  `resolve/3` instead.
  """
  @spec resolve!(UrlContext.t(), logical_reference()) :: String.t()
  @spec resolve!(UrlContext.t(), logical_reference(), PageRef.t() | nil) :: String.t()
  def resolve!(%UrlContext{} = context, reference, from \\ nil) do
    case resolve(context, reference, from) do
      {:ok, url} -> url
      {:error, error} -> raise UrlError, format_error(error)
    end
  end

  @doc """
  Whether a URL written into a page of this build points at another site.

  Only this module can answer that, and it is why the question is asked here
  rather than by looking at the URL: a build that bakes in an absolute base URL
  — the one printed to PDF — emits its own links as `https://archidep.ch/…`,
  which nothing else can tell apart from a link to somewhere else. A build that
  bakes in none has no absolute URL of its own at all, so an absolute link in it
  is by construction a link away from the site; that is a property of [the
  seam](`resolve/3`), not an assumption about the content, since a link to
  another page of the course is a reference rather than a URL an author wrote.

  A URL naming no host — a path, a fragment, a `mailto:` — is not a link to
  another site and is answered `false`.
  """
  @spec external?(UrlContext.t(), String.t()) :: boolean()
  def external?(%UrlContext{} = context, url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} -> false
      %URI{host: host} -> downcase(host) != own_host(context)
    end
  end

  @doc """
  Describe why a reference could not be resolved, in terms an author can act on.

  The build report, the renderer's own errors and
  `ArchiDep.CourseSite.Urls.UrlError` all use this wording.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unknown_asset, path}),
    do: "Global asset #{inspect(path)} is not in the asset manifest"

  def format_error({:unknown_page_asset, page, path, output_path}),
    do:
      "Page asset #{inspect(path)} of page #{describe_page(page)} is not in the page asset manifest (looked for #{inspect(output_path)})"

  def format_error({:unknown_pdf, page}),
    do: "No PDF has been published for page #{describe_page(page)}"

  def format_error({:absolute_page_asset, page, path}),
    do:
      "Page asset #{inspect(path)} of page #{describe_page(page)} must be relative to the page; use an {:asset, path} reference for a global asset"

  def format_error({:invalid_page_asset, page, path}),
    do:
      "Page asset #{inspect(path)} of page #{describe_page(page)} must not contain a query string or a fragment"

  def format_error({:page_asset_outside_site, page, path}),
    do:
      "Page asset #{inspect(path)} of page #{describe_page(page)} points outside the site's root"

  def format_error({:missing_live_site_url, reference}),
    do: "Reference #{inspect(reference)} requires the URL of the current edition's site"

  def format_error({:missing_version, reference}),
    do: "Reference #{inspect(reference)} requires the build to have a version"

  def format_error({:invalid_reference, reference}),
    do: "#{inspect(reference)} is not a valid reference"

  defp own_host(%UrlContext{} = context) do
    case URI.parse(UrlContext.content_origin(context)) do
      %URI{host: nil} -> nil
      %URI{host: host} -> downcase(host)
    end
  end

  defp downcase(host), do: String.downcase(host, :ascii)

  defp live_site_home_prefix(context) do
    if UrlContext.home_at_base?(context), do: "", else: UrlContext.edition_prefix(context)
  end

  defp content_url(context, output_path),
    do: UrlContext.content_origin(context) <> UrlContext.content_prefix(context) <> output_path

  defp page_asset_url(context, page, path) do
    with :ok <- validate_relative_asset_path(page, path),
         {:ok, output_path} <- page_asset_output_path(page, path),
         {:ok, digested} <- fetch_page_asset(context, page, path, output_path) do
      {:ok, UrlPath.encode(UrlPath.join(UrlPath.dirname(path), digested))}
    end
  end

  defp validate_relative_asset_path(page, path) do
    cond do
      String.starts_with?(path, "/") or String.contains?(path, ":") ->
        {:error, {:absolute_page_asset, page, path}}

      String.contains?(path, ["?", "#"]) ->
        {:error, {:invalid_page_asset, page, path}}

      true ->
        :ok
    end
  end

  defp page_asset_output_path(page, path) do
    case page |> PageRef.output_path() |> UrlPath.join(path) |> UrlPath.normalize() do
      {:ok, output_path} -> {:ok, output_path}
      {:error, :escapes_root} -> {:error, {:page_asset_outside_site, page, path}}
    end
  end

  defp fetch_page_asset(context, page, path, output_path) do
    case PageAssetManifest.fetch(context.page_assets, output_path) do
      {:ok, digested} -> {:ok, digested}
      :error -> {:error, {:unknown_page_asset, page, path, output_path}}
    end
  end

  defp pdf_url(context, page) do
    %UrlContext{pdfs: %PdfManifest{base: base} = pdfs} = context

    case PdfManifest.fetch(pdfs, page) do
      {:ok, {:url, url}} -> {:ok, url}
      {:ok, name} when base == :site -> {:ok, site_pdf_url(context, name)}
      {:ok, name} -> {:ok, external_pdf_url(base, name)}
      :error -> {:error, {:unknown_pdf, page}}
    end
  end

  defp site_pdf_url(context, name),
    do: UrlContext.content_prefix(context) <> "/pdf/" <> UrlPath.encode(name)

  defp external_pdf_url({:external, base}, name), do: base <> "/" <> UrlPath.encode(name)

  defp live_site_url(%UrlContext{live_site_url: nil}, reference),
    do: {:error, {:missing_live_site_url, reference}}

  defp live_site_url(%UrlContext{live_site_url: live_site_url}, _reference),
    do: {:ok, live_site_url}

  defp version(%UrlContext{version: nil}, reference), do: {:error, {:missing_version, reference}}
  defp version(%UrlContext{version: version}, _reference), do: {:ok, version}

  defp describe_page(:home), do: "the home page"

  defp describe_page({:document, %DocumentRef{} = document}),
    do: "#{DocumentRef.dir(document)} (#{document.type})"

  defp describe_page({:cheatsheet, slug}), do: "the #{slug} cheatsheet"
end
