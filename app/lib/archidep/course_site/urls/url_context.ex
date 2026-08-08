defmodule ArchiDep.CourseSite.Urls.UrlContext do
  @moduledoc """
  How one build of the course material site addresses itself: where it is
  mounted, which edition of the course it holds, and where its assets, PDFs and
  live counterpart are.

  Every build of the site — the live one, the backup copy on GitHub Pages, a
  past year's archive on either host, and the one printed to PDF — is a
  configuration of this struct rather than a variation of the renderer. See
  `ArchiDep.CourseSite.Urls` for what each knob does to an emitted URL.

  The deployment mount point (`base_path`) and the edition (`version`) are kept
  separate because the home page needs the mount point on its own: during the
  year it sits at the mount point rather than under the year prefix.
  """

  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.RootFileManifest

  @enforce_keys [:mode, :build_id]
  defstruct mode: nil,
            base_path: "",
            version: nil,
            build_id: nil,
            absolute_base_url: nil,
            live_site_url: nil,
            assets: nil,
            page_assets: nil,
            pdfs: nil,
            root_files: nil

  @typedoc """
  What a build is:

  - `:live` — the current edition on the main site.
  - `:backup` — the current edition mirrored elsewhere, in case the main site is
    unreachable.
  - `:archive` — a past edition, frozen.
  """
  @type mode :: :live | :backup | :archive

  @type t :: %__MODULE__{
          mode: mode(),
          base_path: String.t(),
          version: String.t() | nil,
          build_id: String.t(),
          absolute_base_url: String.t() | nil,
          live_site_url: String.t() | nil,
          assets: AssetManifest.t(),
          page_assets: PageAssetManifest.t(),
          pdfs: PdfManifest.t(),
          root_files: RootFileManifest.t()
        }

  @modes [:live, :backup, :archive]

  @doc """
  Build a URL context, raising an `ArgumentError` when a knob is malformed.

  A malformed knob is a deployment configuration error rather than a per-URL
  failure, and every build makes exactly one context, so this raises instead of
  returning an error.

  Options:

  - `:mode` (required) — see `t:mode/0`.
  - `:build_id` (required) — identifies the build's inputs, and names the search
    assets, which cannot be named after their own content.
  - `:base_path` — where the site is mounted, e.g. `"/website"`. Empty by
    default, meaning the host's root. Must not end with a slash.
  - `:version` — the edition, i.e. the starting year of the academic year, e.g.
    `"2026"`. When absent, the build is not versioned. Required of an archive,
    which is identified by the edition it holds.
  - `:absolute_base_url` — baked onto content links so that they point at the
    main site wherever the build itself is served from. Set for the PDF export
    only.
  - `:live_site_url` — where the current edition lives. Required of every build
    that is not it.
  - `:assets`, `:page_assets`, `:pdfs`, `:root_files` — the manifests, empty by
    default.

  Those last two requirements are what a build that is not the live site owes
  its reader: a copy that cannot say where the current edition is cannot tell
  them they are not reading it. Stating them here rather than where the page
  offering that link is drawn is what keeps such a build unrepresentable instead
  of leaving it to fail one page at a time.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    mode = validate_mode!(Keyword.fetch!(opts, :mode))

    %__MODULE__{
      mode: mode,
      build_id: validate_build_id!(Keyword.fetch!(opts, :build_id)),
      base_path: opts |> Keyword.get(:base_path, "") |> validate_base_path!(),
      version: opts |> Keyword.get(:version) |> validate_version!() |> validate_edition!(mode),
      absolute_base_url:
        opts |> Keyword.get(:absolute_base_url) |> validate_url!(:absolute_base_url),
      live_site_url:
        opts
        |> Keyword.get(:live_site_url)
        |> validate_url!(:live_site_url)
        |> validate_counterpart!(mode),
      assets: Keyword.get(opts, :assets) || AssetManifest.new(%{}),
      page_assets: Keyword.get(opts, :page_assets) || PageAssetManifest.new(%{}),
      pdfs: Keyword.get(opts, :pdfs) || PdfManifest.new(:site, %{}),
      root_files: Keyword.get(opts, :root_files) || RootFileManifest.new([])
    }
  end

  @doc """
  Where the content of this build lives: its mount point followed by its
  edition.

      iex> UrlContext.content_prefix(UrlContext.new(mode: :live, build_id: "abc123", version: "2026"))
      "/2026"

      iex> UrlContext.content_prefix(
      ...>   UrlContext.new(
      ...>     mode: :backup,
      ...>     build_id: "abc123",
      ...>     base_path: "/website",
      ...>     version: "2026",
      ...>     live_site_url: "https://archidep.ch"
      ...>   )
      ...> )
      "/website/2026"

      iex> UrlContext.content_prefix(UrlContext.new(mode: :live, build_id: "abc123"))
      ""
  """
  @spec content_prefix(t()) :: String.t()
  def content_prefix(%__MODULE__{base_path: base_path} = context),
    do: base_path <> edition_prefix(context)

  @doc """
  What this build's edition adds to a path, below the mount point.

  It is the half of `content_prefix/1` that says *which* edition rather than
  where the site is mounted, and so what tells an edition's own files from the
  ones a host keeps one of — which is why `ArchiDep.CourseSite.Build.Site`
  writes a build in these terms.

      iex> UrlContext.edition_prefix(UrlContext.new(mode: :live, build_id: "abc123", version: "2026"))
      "/2026"

      iex> UrlContext.edition_prefix(UrlContext.new(mode: :live, build_id: "abc123"))
      ""
  """
  @spec edition_prefix(t()) :: String.t()
  def edition_prefix(%__MODULE__{version: nil}), do: ""
  def edition_prefix(%__MODULE__{version: version}), do: "/" <> version

  @doc """
  The origin content links are emitted against: nothing at all, unless the build
  bakes in an absolute base URL.

      iex> UrlContext.content_origin(UrlContext.new(mode: :live, build_id: "abc123"))
      ""

      iex> UrlContext.content_origin(
      ...>   UrlContext.new(mode: :live, build_id: "abc123", absolute_base_url: "https://archidep.ch")
      ...> )
      "https://archidep.ch"
  """
  @spec content_origin(t()) :: String.t()
  def content_origin(%__MODULE__{absolute_base_url: nil}), do: ""
  def content_origin(%__MODULE__{absolute_base_url: absolute_base_url}), do: absolute_base_url

  @doc """
  The same build, addressed as it is served rather than as its content links
  say.

  A build's pages may be given an absolute base URL so that they point at the
  main site wherever they are served from. A file *describing* the build is read
  by a consumer that is about to walk it, and so has to say where things are in
  the copy in front of it — which is the rule assets already follow, applied to
  a surface that is not content.

      iex> UrlContext.content_origin(
      ...>   UrlContext.local(
      ...>     UrlContext.new(
      ...>       mode: :live,
      ...>       build_id: "abc123",
      ...>       absolute_base_url: "https://archidep.ch"
      ...>     )
      ...>   )
      ...> )
      ""
  """
  @spec local(t()) :: t()
  def local(%__MODULE__{} = context), do: %__MODULE__{context | absolute_base_url: nil}

  @doc """
  Whether the home page of this build sits at its mount point rather than under
  its edition prefix. It does for the edition currently being taught, while an
  archived edition keeps its home page under its own prefix.

      iex> UrlContext.home_at_base?(UrlContext.new(mode: :live, build_id: "abc123"))
      true

      iex> UrlContext.home_at_base?(
      ...>   UrlContext.new(
      ...>     mode: :archive,
      ...>     build_id: "abc123",
      ...>     version: "2025",
      ...>     live_site_url: "https://archidep.ch"
      ...>   )
      ...> )
      false
  """
  @spec home_at_base?(t()) :: boolean()
  def home_at_base?(%__MODULE__{mode: mode}), do: mode != :archive

  defp validate_mode!(mode) when mode in @modes, do: mode

  defp validate_mode!(mode),
    do: raise(ArgumentError, "Build mode #{inspect(mode)} must be one of #{inspect(@modes)}")

  defp validate_build_id!(build_id) when is_binary(build_id) and build_id != "", do: build_id

  defp validate_build_id!(build_id),
    do: raise(ArgumentError, "Build ID #{inspect(build_id)} must be a non-empty string")

  defp validate_base_path!(""), do: ""

  defp validate_base_path!(base_path) when is_binary(base_path) do
    cond do
      not String.starts_with?(base_path, "/") ->
        raise ArgumentError, "Base path #{inspect(base_path)} must start with a slash"

      String.ends_with?(base_path, "/") ->
        raise ArgumentError, "Base path #{inspect(base_path)} must not end with a slash"

      true ->
        base_path
    end
  end

  defp validate_base_path!(base_path),
    do: raise(ArgumentError, "Base path #{inspect(base_path)} must be a string")

  defp validate_version!(nil), do: nil

  defp validate_version!(version) when is_binary(version) do
    if Regex.match?(~r/\A\d{4}\z/, version) do
      version
    else
      raise ArgumentError,
            "Version #{inspect(version)} must be a four-digit year, the starting year of the academic year"
    end
  end

  defp validate_version!(version),
    do: raise(ArgumentError, "Version #{inspect(version)} must be a string")

  defp validate_edition!(nil, :archive),
    do:
      raise(
        ArgumentError,
        "Option :version is required of an archive, which is identified by the edition it holds"
      )

  defp validate_edition!(version, _mode), do: version

  defp validate_counterpart!(nil, mode) when mode != :live,
    do:
      raise(
        ArgumentError,
        "Option :live_site_url is required of a build in #{inspect(mode)} mode, which has to say where the current edition is"
      )

  defp validate_counterpart!(live_site_url, _mode), do: live_site_url

  defp validate_url!(nil, _option), do: nil

  defp validate_url!(url, option) when is_binary(url) do
    cond do
      not String.starts_with?(url, ["http://", "https://"]) ->
        raise ArgumentError, "Option #{inspect(option)} #{inspect(url)} must be an absolute URL"

      String.ends_with?(url, "/") ->
        raise ArgumentError, "Option #{inspect(option)} #{inspect(url)} must not end with a slash"

      true ->
        url
    end
  end

  defp validate_url!(url, option),
    do: raise(ArgumentError, "Option #{inspect(option)} #{inspect(url)} must be a string")
end
