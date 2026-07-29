defmodule Mix.Tasks.Archidep.CourseSite.Assets do
  @shortdoc "Digest the files of the course material site and check what refers to them"

  @moduledoc """
  Build the asset manifests of the course material site from the real content
  and the real assets, then render every document against them.

  This is the check the manifests exist for: a reference the build cannot
  resolve is reported here rather than published as a broken image. **It writes
  nothing.** What a file is called follows from its content, so knowing every
  name and resolving every reference against it needs no output directory at
  all.

      mix archidep.course_site.assets

  Options:

  - `--content` — the course collections directory. Defaults to
    `../course/collections`.
  - `--includes` — the directory of partials a document may include. Defaults to
    `../course/_includes`.
  - `--static` — the static directory holding the global assets. Defaults to
    `priv/static`. Its `cache_manifest.json` is read when it is there, and the
    assets are taken to be undigested when it is not.
  """

  use Mix.Task

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Urls.UrlContext

  @requirements ["app.config"]

  @app_dir Path.expand("../../../../..", __DIR__)

  @impl Mix.Task
  def run(args) do
    {opts, [], []} =
      OptionParser.parse(args, strict: [content: :string, includes: :string, static: :string])

    content_dir = Keyword.get(opts, :content, Path.join(@app_dir, "../course/collections"))
    includes_dir = Keyword.get(opts, :includes, Path.join(@app_dir, "../course/_includes"))
    static_dir = Keyword.get(opts, :static, Path.join(@app_dir, "priv/static"))

    tree = tree!(content_dir)
    page_assets = page_assets!(tree, content_dir)
    assets = assets!(static_dir)
    includes = includes!(includes_dir)
    progress = progress!(content_dir)

    urls =
      UrlContext.new(mode: :live, build_id: "check", assets: assets, page_assets: page_assets)

    report(
      tree,
      problems_rendering(tree, content_dir, urls, includes, progress),
      withheld(tree, progress)
    )
  end

  defp tree!(content_dir) do
    case Build.content_tree(content_dir) do
      {:ok, tree} ->
        Mix.shell().info(
          "Read #{map_size(tree.documents)} documents, #{map_size(tree.cheatsheets)} cheatsheets and #{map_size(tree.page_assets)} files next to a page from #{content_dir}"
        )

        tree

      {:error, errors} ->
        abort!("The content directory could not be read", errors, &Build.format_error/1)
    end
  end

  defp page_assets!(tree, content_dir) do
    case Build.page_asset_manifest(tree, content_dir) do
      {:ok, manifest} ->
        Mix.shell().info("Digested #{map_size(manifest.page_assets)} files next to a page")
        manifest

      {:error, errors} ->
        abort!("The files next to the pages could not be digested", errors, &Build.format_error/1)
    end
  end

  defp assets!(static_dir) do
    case Build.asset_manifest(static_dir) do
      {:ok, manifest} ->
        Mix.shell().info("Read #{map_size(manifest.assets)} digested assets from #{static_dir}")
        manifest

      {:error, [{:missing_manifest, _path}]} ->
        manifest = Build.undigested_asset_manifest(static_dir)

        Mix.shell().info(
          "Read #{map_size(manifest.assets)} undigested assets from #{static_dir}, which was never digested"
        )

        manifest

      {:error, errors} ->
        abort!("The asset manifest could not be read", errors, &Build.format_error/1)
    end
  end

  defp includes!(includes_dir) do
    case Build.includes(includes_dir) do
      {:ok, includes} ->
        Mix.shell().info("Parsed #{map_size(includes)} partials from #{includes_dir}")
        includes

      {:error, errors} ->
        abort!("The partials could not be read", errors, &Build.format_error/1)
    end
  end

  defp progress!(content_dir) do
    progress = content_dir |> Build.progress_entries!() |> Progress.new()

    Mix.shell().info(
      "Read the progress through the course: #{MapSet.size(progress.done)} sections and chapters are done"
    )

    progress
  end

  # A page that is not a chapter has no status to consult, and may not hold an
  # answer at all: the renderer refuses a solution written on the home page or
  # in a cheatsheet rather than showing it.
  defp solutions({:document, %DocumentRef{num: num}}, progress),
    do: if(Progress.solutions_revealed?(progress, num), do: :revealed, else: :hidden)

  defp solutions(_page, _progress), do: :revealed

  defp withheld(%ContentTree{documents: documents}, progress),
    do:
      Enum.count(documents, fn {ref, _source_path} ->
        solutions({:document, ref}, progress) == :hidden
      end)

  defp problems_rendering(%ContentTree{} = tree, content_dir, urls, includes, progress) do
    documents =
      Enum.map(tree.documents, fn {ref, source_path} -> {{:document, ref}, source_path} end) ++
        Enum.map(tree.cheatsheets, fn {slug, source_path} ->
          {{:cheatsheet, slug}, source_path}
        end)

    Enum.flat_map(documents, fn {page, source_path} ->
      problems_rendering_one(page, source_path, content_dir, urls, includes, progress)
    end)
  end

  defp problems_rendering_one(page, source_path, content_dir, urls, includes, progress) do
    contents = content_dir |> Path.join(source_path) |> File.read!()

    case Source.parse(contents) do
      {:ok, source} ->
        context =
          RenderContext.new(
            source: source,
            source_path: source_path,
            urls: urls,
            page: page,
            includes: includes,
            solutions: solutions(page, progress)
          )

        page |> render(context) |> problems(source_path)

      {:error, error} ->
        [{:other, source_path, "the document could not be taken apart: #{inspect(error)}"}]
    end
  end

  defp render({:document, %DocumentRef{type: :slides}}, context),
    do: Renderer.render_slides(context)

  defp render(_page, context), do: Renderer.render_page(context)

  defp problems({:ok, _rendered}, _source_path), do: []

  defp problems({:error, errors}, source_path),
    do: Enum.map(errors, &{kind(&1), source_path, RenderError.message(&1)})

  # A document may be wrong in ways that have nothing to do with what it refers
  # to. Those are shown but not failed on: this task answers for the manifests,
  # and the rest of what a document gets wrong belongs to whatever renders the
  # site.
  defp kind(%RenderError{reason: {:url, _error}}), do: :reference
  defp kind(%RenderError{}), do: :other

  defp report(%ContentTree{} = tree, problems, withheld) do
    {unresolved, other} = Enum.split_with(problems, &(elem(&1, 0) == :reference))

    rendered = map_size(tree.documents) + map_size(tree.cheatsheets)

    Mix.shell().info(
      "Withheld the answers of #{withheld} documents the course has not covered yet"
    )

    if other != [] do
      Mix.shell().info("#{length(other)} documents are wrong in ways this task does not fail on:")
      Enum.each(Enum.sort(other), &Mix.shell().info("  " <> describe(&1)))
    end

    if unresolved == [] do
      Mix.shell().info("Rendered #{rendered} documents; every reference resolves")
    else
      Mix.shell().error("#{length(unresolved)} references could not be resolved:")
      Enum.each(Enum.sort(unresolved), &Mix.shell().error("  " <> describe(&1)))
      exit({:shutdown, 1})
    end
  end

  defp describe({_kind, source_path, message}), do: "#{source_path}: #{message}"

  defp abort!(what, errors, format) do
    Mix.shell().error("#{what}:")
    Enum.each(errors, &Mix.shell().error("  " <> format.(&1)))
    exit({:shutdown, 1})
  end
end
