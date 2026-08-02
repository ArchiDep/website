defmodule ArchiDep.Support.CourseSiteFactory do
  @moduledoc """
  Test fixtures and generators for the course material site's rendering
  subsystem.
  """

  use ArchiDep.Support, :factory
  use ExUnitProperties

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Emoji

  @doc_types [:subject, :exercise, :slides]
  @modes [:live, :backup, :archive]

  # Every way a chapter directory may be filled, which is what the rules of
  # `ArchiDep.CourseSite.Build.ContentTree` leave: a subject, a subject with a
  # deck in either source layout, an exercise graded or not, or a deck alone.
  @chapter_shapes [
    ["subject.md"],
    ["subject.md", "slides.md"],
    ["subject.md", "slides/slides.md"],
    ["exercise.md"],
    ["slides.md"]
  ]

  @spec session_factory(map()) :: Session.t()
  def session_factory(attrs!) do
    {date, attrs!} = Map.pop_lazy(attrs!, :date, fn -> Faker.Date.backward(365) end)

    {title, attrs!} =
      Map.pop_lazy(attrs!, :title, fn -> Enum.join(Faker.Lorem.words(2), " ") end)

    {done, attrs!} = Map.pop(attrs!, :done, [])
    {due, attrs!} = Map.pop(attrs!, :due, [])
    {next, attrs!} = Map.pop(attrs!, :next, [])

    [] = Map.keys(attrs!)

    Session.new(date, title, done, due, next)
  end

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
    {base_path, attrs!} =
      Map.pop_lazy(attrs!, :base_path, fn -> Enum.random(["", "/" <> slug()]) end)

    {version, attrs!} =
      Map.pop_lazy(attrs!, :version, fn -> to_string(Enum.random(2020..2039)) end)

    {build_id, attrs!} =
      Map.pop_lazy(attrs!, :build_id, fn -> sequence(:build_id, &"build-id-#{&1}") end)

    {absolute_base_url, attrs!} = Map.pop(attrs!, :absolute_base_url)

    {live_site_url, attrs!} =
      Map.pop_lazy(attrs!, :live_site_url, fn -> "https://#{slug()}.example.com" end)

    {mode, attrs!} =
      Map.pop_lazy(attrs!, :mode, fn -> Enum.random(modes(version, live_site_url)) end)

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
    {strict_variables, attrs!} = Map.pop(attrs!, :strict_variables, true)
    {tags, attrs!} = Map.pop(attrs!, :tags)
    {ast_passes, attrs!} = Map.pop(attrs!, :ast_passes)
    {html_passes, attrs!} = Map.pop(attrs!, :html_passes)

    [] = Map.keys(attrs!)

    opts =
      [strict_variables: strict_variables]
      |> optional(:ast_passes, ast_passes)
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
    {solutions, attrs!} = Map.pop(attrs!, :solutions, :revealed)

    [] = Map.keys(attrs!)

    RenderContext.new(
      source: source,
      source_path: source_path,
      urls: urls,
      page: page,
      page_variables: page_variables,
      includes: includes,
      options: options,
      solutions: solutions
    )
  end

  # Which builds the attributes a test named leave possible: an archive is
  # identified by its edition, and every build that is not the live site has to
  # say where the current edition is, so a context asked for without one of
  # those is one of the builds that does not need it. A test wanting the
  # combination `ArchiDep.CourseSite.Urls.UrlContext` refuses states it there.
  defp modes(_version, nil), do: [:live]
  defp modes(nil, _live_site_url), do: [:live, :backup]
  defp modes(_version, _live_site_url), do: @modes

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

  Every generated context knows where the live site is, so the only build a
  generated edition rules out is the archive, which is identified by the edition
  it holds.
  """
  @spec url_context_generator() :: StreamData.t(UrlContext.t())
  def url_context_generator do
    gen all(
          base_path <- one_of([constant(""), map(slug_generator(), &"/#{&1}")]),
          version <- one_of([constant(nil), map(integer(2020..2039), &to_string/1)]),
          mode <- member_of(if(version, do: @modes, else: @modes -- [:archive])),
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

  @doc """
  A generator of a whole course, for property-based tests: the content tree of
  one, the front matter of every page of it and the declarations that go with
  it.

  The three are consistent by construction — every chapter is numbered for a
  declared section, every page has a title, only an exercise is graded — so that
  a property is about what `ArchiDep.CourseSite.Structure.plan/3` makes of a
  course rather than about what it refuses.
  """
  @spec course_generator() ::
          StreamData.t({ContentTree.t(), %{PageRef.t() => map()}, %{String.t() => term()}})
  def course_generator do
    gen all(
          numbers <-
            list_of(uniq_list_of(integer(1..99), min_length: 1, max_length: 3),
              min_length: 1,
              max_length: 4
            ),
          chapter_count <- constant(Enum.count(List.flatten(numbers))),
          words <- list_of(slug_generator(), length: chapter_count),
          shapes <- list_of(member_of(@chapter_shapes), length: chapter_count),
          graded <- list_of(boolean(), length: chapter_count),
          section_words <- list_of(slug_generator(), length: length(numbers)),
          cheatsheet_slugs <- uniq_list_of(slug_generator(), max_length: 2)
        ) do
      chapter_numbers =
        numbers
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {chapter_numbers, section} ->
          chapter_numbers |> Enum.sort() |> Enum.map(&(section * 100 + &1))
        end)

      chapters = Enum.zip([chapter_numbers, words, shapes, graded])

      document_paths =
        Enum.flat_map(chapters, fn {num, word, shape, _graded?} ->
          Enum.map(shape, &"_course/#{num}-#{word}/#{&1}")
        end)

      cheatsheet_paths = Enum.map(cheatsheet_slugs, &"_cheatsheets/#{&1}/cheatsheet.md")

      {:ok, tree} = ContentTree.plan(document_paths ++ cheatsheet_paths)

      graded_chapters =
        chapters
        |> Enum.filter(fn {_num, _word, _shape, graded?} -> graded? end)
        |> MapSet.new(&elem(&1, 0))

      front_matter =
        Map.merge(
          Map.new(tree.documents, fn {ref, _source_path} ->
            {{:document, ref}, document_front_matter(ref, graded_chapters)}
          end),
          Map.new(cheatsheet_slugs, &{{:cheatsheet, &1}, %{"title" => "#{&1} cheatsheet"}})
        )

      declarations = %{
        "sections" =>
          section_words
          |> Enum.with_index(1)
          |> Enum.map(fn {word, index} -> %{"title" => "Section #{index} #{word}"} end),
        "cheatsheets" => cheatsheet_slugs
      }

      {tree, front_matter, declarations}
    end
  end

  defp document_front_matter(%DocumentRef{num: num, type: type}, graded_chapters) do
    front_matter = %{"title" => "Chapter #{num} #{type}"}

    if type == :exercise and MapSet.member?(graded_chapters, num),
      do: Map.put(front_matter, "graded", true),
      else: front_matter
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
