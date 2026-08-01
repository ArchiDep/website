defmodule Mix.Tasks.Archidep.CourseSite.Build do
  @shortdoc "Render the course material site and write it"

  @moduledoc """
  Render every document, cheatsheet and deck of the course material site and
  write the whole of it, with the files sitting next to its pages.

      mix archidep.course_site.build

  The assets the pages refer to are **not** written by this: they are digested
  by `mix phx.digest` before it runs, which is what lets a page embed the name a
  file was published under. A build whose manifest is missing fails rather than
  emitting names that only resolve in development — pass `--undigested` to say
  that a build really has none.

  A build **owns** its output directory and refuses one that is not empty, so
  that what it wrote is what is there. Pass `--clean` to empty it first.

  Options:

  - `--content` — the course collections directory. Defaults to
    `../course/collections`.
  - `--home` — the page introducing the course, which is not one of them.
    Defaults to `../course/index.md`.
  - `--includes` — the directory of partials a document may include. Defaults to
    `../course/_includes`.
  - `--declarations` — what the course declares about itself. Defaults to
    `../course/_data/course.yml`.
  - `--progress` — the file recording how far the course has got, which decides
    which chapters show their answers. Defaults to the application's own
    `priv/course/progress.json`.
  - `--static` — the static directory holding the global assets. Defaults to
    `priv/static`.
  - `--years` — the academic year this edition covers. Defaults to `2025-2026`.
  - `--years-short` — the same year as it fits in the corner of a slide.
    Defaults to `25-26`.
  - `--output` — where to write. Defaults to `tmp/course_site`.
  - `--clean` — empty the output directory first.
  - `--minimal` — wrap the pages in the bare layout rather than the site's own
    chrome, to tell a page that is wrong from chrome that is.
  - `--undigested` — take the global assets to carry no digest.

  Where the build is published, which is what every URL in it follows from:

  - `--mode` — `live`, `backup` or `archive`. Defaults to `live`.
  - `--base-path` — the mount point, e.g. `/website`. Defaults to none.
  - `--version` — the edition, i.e. the starting year of the academic year.
  - `--live-site-url` — where the main site is, for a build that is not it.
  - `--absolute-base-url` — baked onto content links, for the PDF export.
  - `--build-id` — names the files a build produces of itself. Defaults to
    `build`.
  """

  use Mix.Task

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.LinkCheck
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Layout.Chrome
  alias ArchiDep.CourseSite.Layout.Minimal
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Git

  @requirements ["app.config"]

  @app_dir Path.expand("../../../../..", __DIR__)

  # The edition being taught, which nothing in the checkout states: the content
  # is the same course whichever year it is read in.
  @years "2025-2026"
  @years_short "25-26"

  @switches [
    content: :string,
    home: :string,
    includes: :string,
    years: :string,
    years_short: :string,
    declarations: :string,
    progress: :string,
    static: :string,
    output: :string,
    clean: :boolean,
    minimal: :boolean,
    undigested: :boolean,
    mode: :string,
    base_path: :string,
    version: :string,
    live_site_url: :string,
    absolute_base_url: :string,
    build_id: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, [], []} = OptionParser.parse(args, strict: @switches)

    content_dir = path(opts, :content, "../course/collections")
    output_dir = path(opts, :output, "tmp/course_site")

    inputs = inputs!(opts, content_dir)
    options = options(opts, inputs)
    site = plan!(inputs, options)

    prepare!(output_dir, if(Keyword.get(opts, :clean, false), do: :clean, else: :empty))
    publish!(site, inputs, content_dir, output_dir)

    check!(site, output_dir)
  end

  defp path(opts, key, default), do: Keyword.get(opts, key, Path.join(@app_dir, default))

  defp inputs!(opts, content_dir) do
    result =
      Build.site_inputs(
        content_dir: content_dir,
        home_file: path(opts, :home, "../course/index.md"),
        includes_dir: path(opts, :includes, "../course/_includes"),
        declarations_file: path(opts, :declarations, "../course/_data/course.yml"),
        progress_file: path(opts, :progress, "priv/course/progress.json"),
        static_dir: path(opts, :static, "priv/static"),
        digested: not Keyword.get(opts, :undigested, false)
      )

    case result do
      {:ok, inputs} ->
        Mix.shell().info(
          "Read #{map_size(inputs.sources)} pages, #{map_size(inputs.tree.page_assets)} files next to a page and #{map_size(inputs.assets.assets)} global assets"
        )

        inputs

      {:error, errors} ->
        abort!("The build could not be read", errors, &Build.format_error/1)
    end
  end

  defp options(opts, inputs) do
    urls =
      UrlContext.new(
        mode: mode(opts),
        build_id: Keyword.get(opts, :build_id, "build"),
        base_path: Keyword.get(opts, :base_path, ""),
        version: Keyword.get(opts, :version),
        live_site_url: Keyword.get(opts, :live_site_url),
        absolute_base_url: Keyword.get(opts, :absolute_base_url),
        assets: inputs.assets,
        page_assets: inputs.page_assets
      )

    Site.Options.new(
      urls: urls,
      layout: if(Keyword.get(opts, :minimal, false), do: Minimal, else: Chrome),
      site:
        SiteInfo.new(
          version: Mix.Project.config()[:version],
          git_branch: Git.git_branch(),
          git_revision: Git.git_revision(),
          years: Keyword.get(opts, :years, @years),
          years_short: Keyword.get(opts, :years_short, @years_short)
        )
    )
  end

  defp mode(opts) do
    case Keyword.get(opts, :mode, "live") do
      "live" -> :live
      "backup" -> :backup
      "archive" -> :archive
      other -> Mix.raise("Mode must be live, backup or archive, got: #{inspect(other)}")
    end
  end

  defp plan!(inputs, options) do
    case Site.plan(inputs, options) do
      {:ok, site} ->
        Mix.shell().info(
          "Rendered #{length(site.pages)} pages and #{Enum.count(Structure.chapters(inputs.structure))} chapters into #{map_size(site.files)} files"
        )

        site

      {:error, errors} ->
        abort!("The site could not be rendered", errors, &Site.format_error/1)
    end
  end

  defp prepare!(output_dir, mode) do
    case Build.prepare_output(output_dir, mode) do
      :ok ->
        Mix.shell().info("Writing into #{output_dir}")

      {:error, errors} ->
        abort!("The output directory could not be made ready", errors, &Build.format_error/1)
    end
  end

  defp publish!(site, inputs, content_dir, output_dir) do
    case Build.publish_site(site, inputs, content_dir, output_dir) do
      :ok ->
        Mix.shell().info(
          "Wrote #{map_size(site.files)} files and #{map_size(inputs.page_assets.page_assets)} files next to a page"
        )

      {:error, errors} ->
        abort!("The build could not be written", errors, &Build.format_error/1)
    end
  end

  defp check!(site, output_dir) do
    case LinkCheck.check(site.pages, Build.output_files(output_dir)) do
      [] ->
        Mix.shell().info("Every link of the build resolves")

      [_first | _rest] = broken ->
        abort!("#{length(broken)} links lead nowhere", broken, &LinkCheck.format_error/1)
    end
  end

  defp abort!(what, errors, format) do
    Mix.shell().error("#{what}:")
    Enum.each(errors, &Mix.shell().error("  " <> format.(&1)))
    exit({:shutdown, 1})
  end
end
