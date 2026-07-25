defmodule ArchiDep.Support.CourseSiteFactory do
  @moduledoc """
  Test fixtures and generators for the course material site's rendering
  subsystem.
  """

  use ArchiDep.Support, :factory
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext

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

    {assets, attrs!} = Map.pop_lazy(attrs!, :assets, fn -> AssetManifest.new(%{}) end)

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

  defp slug, do: sequence(:course_site_slug, &"slug-#{&1}")

  defp slug_generator do
    gen all(word <- string(:alphanumeric, min_length: 1)) do
      String.downcase(word)
    end
  end
end
