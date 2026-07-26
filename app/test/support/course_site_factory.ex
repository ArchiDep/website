defmodule ArchiDep.Support.CourseSiteFactory do
  @moduledoc """
  Test fixtures and generators for the course material site's rendering
  subsystem.
  """

  use ArchiDep.Support, :factory
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Emoji

  @doc_types [:subject, :exercise, :slides]
  @modes [:live, :backup, :archive]

  @spec document_ref_factory(map()) :: DocumentRef.t()
  def document_ref_factory(attrs!) do
    {num, attrs!} =
      Map.pop_lazy(attrs!, :num, fn -> Enum.random(1..8) * 100 + Enum.random(1..99) end)

    {slug, attrs!} = Map.pop_lazy(attrs!, :slug, &slug/0)
    {type, attrs!} = Map.pop_lazy(attrs!, :type, fn -> Enum.random(@doc_types) end)

    [] = Map.keys(attrs!)

    DocumentRef.new(num, slug, type)
  end

  @spec url_context_factory(map()) :: UrlContext.t()
  def url_context_factory(attrs!) do
    {mode, attrs!} = Map.pop_lazy(attrs!, :mode, fn -> Enum.random(@modes) end)

    {base_path, attrs!} =
      Map.pop_lazy(attrs!, :base_path, fn -> Enum.random(["", "/" <> slug()]) end)

    {version, attrs!} =
      Map.pop_lazy(attrs!, :version, fn -> to_string(Enum.random(2020..2039)) end)

    {build_id, attrs!} =
      Map.pop_lazy(attrs!, :build_id, fn -> sequence(:build_id, &"build-id-#{&1}") end)

    {absolute_base_url, attrs!} = Map.pop(attrs!, :absolute_base_url)

    {live_site_url, attrs!} =
      Map.pop_lazy(attrs!, :live_site_url, fn -> "https://#{slug()}.example.com" end)

    {assets, attrs!} = Map.pop_lazy(attrs!, :assets, fn -> AssetManifest.new(emoji_assets()) end)

    {page_assets, attrs!} =
      Map.pop_lazy(attrs!, :page_assets, fn -> PageAssetManifest.new(%{}) end)

    {pdfs, attrs!} = Map.pop_lazy(attrs!, :pdfs, fn -> PdfManifest.new(:site, %{}) end)

    [] = Map.keys(attrs!)

    UrlContext.new(
      mode: mode,
      base_path: base_path,
      version: version,
      build_id: build_id,
      absolute_base_url: absolute_base_url,
      live_site_url: live_site_url,
      assets: assets,
      page_assets: page_assets,
      pdfs: pdfs
    )
  end

  @doc """
  The emoji files of a build, undigested, as every real build has them: a page
  that shows one has nowhere to draw it from otherwise.
  """
  @spec emoji_assets() :: %{String.t() => String.t()}
  def emoji_assets do
    Map.new(Emoji.names(), fn name ->
      path = name |> Emoji.fetch!() |> Emoji.asset_path()
      {path, path}
    end)
  end

  @spec source_factory(map()) :: Source.t()
  def source_factory(attrs!) do
    {text, attrs!} = Map.pop_lazy(attrs!, :text, fn -> "Body of #{slug()}.\n" end)

    [] = Map.keys(attrs!)

    {:ok, source} = Source.parse(text)
    source
  end

  @spec render_options_factory(map()) :: RenderOptions.t()
  def render_options_factory(attrs!) do
    {reveal_all_solutions, attrs!} = Map.pop(attrs!, :reveal_all_solutions, false)
    {strict_variables, attrs!} = Map.pop(attrs!, :strict_variables, true)
    {tags, attrs!} = Map.pop(attrs!, :tags)
    {ast_passes, attrs!} = Map.pop(attrs!, :ast_passes, [])
    {html_passes, attrs!} = Map.pop(attrs!, :html_passes)

    [] = Map.keys(attrs!)

    opts =
      [
        reveal_all_solutions: reveal_all_solutions,
        strict_variables: strict_variables,
        ast_passes: ast_passes
      ]
      |> optional(:html_passes, html_passes)
      |> optional(:tags, tags)

    RenderOptions.new(opts)
  end

  @spec render_context_factory(map()) :: RenderContext.t()
  def render_context_factory(attrs!) do
    {source, attrs!} = Map.pop_lazy(attrs!, :source, fn -> build(:source) end)

    {source_path, attrs!} =
      Map.pop_lazy(attrs!, :source_path, fn -> "_course/101-#{slug()}/subject.md" end)

    {urls, attrs!} = Map.pop_lazy(attrs!, :urls, fn -> build(:url_context) end)

    {page, attrs!} =
      Map.pop_lazy(attrs!, :page, fn -> {:document, build(:document_ref, type: :subject)} end)

    {page_variables, attrs!} = Map.pop(attrs!, :page_variables, %{})
    {includes, attrs!} = Map.pop(attrs!, :includes, %{})
    {options, attrs!} = Map.pop_lazy(attrs!, :options, fn -> build(:render_options) end)

    [] = Map.keys(attrs!)

    RenderContext.new(
      source: source,
      source_path: source_path,
      urls: urls,
      page: page,
      page_variables: page_variables,
      includes: includes,
      options: options
    )
  end

  @doc """
  A generator of document references, for property-based tests.
  """
  @spec document_ref_generator() :: StreamData.t(DocumentRef.t())
  def document_ref_generator do
    gen all(
          num <- integer(100..899),
          slug <- slug_generator(),
          type <- member_of(@doc_types)
        ) do
      DocumentRef.new(num, slug, type)
    end
  end

  @doc """
  A generator of page references, for property-based tests.
  """
  @spec page_ref_generator() :: StreamData.t(PageRef.t())
  def page_ref_generator do
    one_of([
      constant(:home),
      map(document_ref_generator(), &{:document, &1}),
      map(slug_generator(), &{:cheatsheet, &1})
    ])
  end

  @doc """
  A generator of URL contexts, for property-based tests. The manifests are left
  empty: a property that needs an entry must build the context around it.
  """
  @spec url_context_generator() :: StreamData.t(UrlContext.t())
  def url_context_generator do
    gen all(
          mode <- member_of(@modes),
          base_path <- one_of([constant(""), map(slug_generator(), &"/#{&1}")]),
          version <- one_of([constant(nil), map(integer(2020..2039), &to_string/1)]),
          build_id <- slug_generator(),
          absolute_base_url <-
            one_of([constant(nil), map(slug_generator(), &"https://#{&1}.example.com")]),
          live_site_url <- map(slug_generator(), &"https://#{&1}.example.com")
        ) do
      UrlContext.new(
        mode: mode,
        base_path: base_path,
        version: version,
        build_id: build_id,
        absolute_base_url: absolute_base_url,
        live_site_url: live_site_url
      )
    end
  end

  # An option the caller did not ask about is left out, so that the defaults of
  # the thing being built are what a test gets rather than the factory's idea of
  # them.
  defp optional(opts, _key, nil), do: opts
  defp optional(opts, key, value), do: [{key, value} | opts]

  defp slug, do: sequence(:course_site_slug, &"slug-#{&1}")

  defp slug_generator do
    gen all(word <- string(:alphanumeric, min_length: 1)) do
      String.downcase(word)
    end
  end
end
