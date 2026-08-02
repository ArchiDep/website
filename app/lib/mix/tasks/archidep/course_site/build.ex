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

  - `--course` — the course material directory, which every input but the
    progress file below is read from. Defaults to `../course`.
  - `--content` — the course collections directory. Defaults to the
    `collections` directory of the course.
  - `--home` — the page introducing the course, which is not one of them.
    Defaults to the `index.md` of the course.
  - `--includes` — the directory of partials a document may include. Defaults to
    the `_includes` directory of the course.
  - `--root-files` — the directory the files anchored at the build's mount point
    are read from. Defaults to the course itself.
  - `--declarations` — what the course declares about itself. Defaults to the
    `_data/course.yml` of the course.
  - `--progress` — the file recording how far the course has got, which decides
    which chapters show their answers. Defaults to the application's own
    `priv/course/progress.json`. Reading it from a file is what makes this
    command able to build an edition that is over, whose progress no running
    application holds any more.
  - `--static` — the static directory holding the global assets. Defaults to
    `priv/static`.
  - `--years` — the academic year this edition covers. Defaults to what the
    application's `course_site` configuration says the edition is.
  - `--years-short` — the same year as it fits in the corner of a slide.
    Defaults to the same place.
  - `--output` — where to write. Defaults to `tmp/course_site`.
  - `--clean` — empty the output directory first.
  - `--minimal` — wrap the pages in the bare layout rather than the site's own
    chrome, to tell a page that is wrong from chrome that is.
  - `--undigested` — take the global assets to carry no digest.
  - `--no-assets` — leave the global assets out of the build, for a build
    something else serves them for.

  Where the build is published, which is what every URL in it follows from:

  - `--mode` — `live`, `backup` or `archive`. Defaults to `live`.
  - `--base-path` — the mount point, e.g. `/website`. Defaults to none.
  - `--version` — the edition, i.e. the starting year of the academic year.
    Defaults to the edition the application's `course_site` configuration says
    this deployment holds, every build being an edition's.
  - `--live-site-url` — where the main site is, for a build that is not it.
  - `--absolute-base-url` — baked onto content links, for the PDF export.
  - `--build-id` — names the files a build produces of itself. Defaults to
    `build`.
  """

  use Mix.Task

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.Layout.Chrome
  alias ArchiDep.CourseSite.Layout.Minimal
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Git

  @requirements ["app.config"]

  @app_dir Path.expand("../../../../..", __DIR__)

  @switches [
    course: :string,
    content: :string,
    home: :string,
    includes: :string,
    root_files: :string,
    years: :string,
    years_short: :string,
    declarations: :string,
    progress: :string,
    static: :string,
    output: :string,
    clean: :boolean,
    minimal: :boolean,
    undigested: :boolean,
    assets: :boolean,
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

    result =
      Builder.build(
        inputs(opts) ++
          [
            output_dir: path(opts, :output, "tmp/course_site"),
            output: if(Keyword.get(opts, :clean, false), do: :clean, else: :empty),
            carry_assets: Keyword.get(opts, :assets, true),
            options: options(opts)
          ]
      )

    case result do
      {:ok, report} -> report!(report)
      {:error, what, errors} -> abort!(what, errors)
    end
  end

  # The switches are overrides of what a course directory holds, so that naming
  # the course is enough and naming one input does not mean naming all of them.
  defp inputs(opts) do
    overrides = [
      content_dir: Keyword.get(opts, :content),
      home_file: Keyword.get(opts, :home),
      includes_dir: Keyword.get(opts, :includes),
      root_files_dir: Keyword.get(opts, :root_files),
      declarations_file: Keyword.get(opts, :declarations)
    ]

    opts
    |> path(:course, "../course")
    |> Builder.course_inputs()
    |> Keyword.merge(Enum.reject(overrides, fn {_key, value} -> is_nil(value) end))
    |> Keyword.merge(
      progress: progress!(path(opts, :progress, "priv/course/progress.json")),
      static_dir: path(opts, :static, "priv/static"),
      digested: not Keyword.get(opts, :undigested, false)
    )
  end

  # The one input a build is handed rather than pointed at, and so the one this
  # command reads for itself.
  defp progress!(file) do
    case Build.progress(file) do
      {:ok, sessions} ->
        sessions

      {:error, errors} ->
        abort!(
          "The progress through the course could not be read",
          Enum.map(errors, &Build.format_error/1)
        )
    end
  end

  defp path(opts, key, default), do: Keyword.get(opts, key, Path.join(@app_dir, default))

  defp options(opts) do
    course_site = Application.get_env(:archidep, :course_site, [])

    urls =
      UrlContext.new(
        mode: mode(opts),
        build_id: Keyword.get(opts, :build_id, "build"),
        base_path: Keyword.get(opts, :base_path, ""),
        version: Keyword.get_lazy(opts, :version, fn -> Keyword.get(course_site, :version) end),
        live_site_url: Keyword.get(opts, :live_site_url),
        absolute_base_url: Keyword.get(opts, :absolute_base_url)
      )

    Site.Options.new(
      urls: urls,
      layout: if(Keyword.get(opts, :minimal, false), do: Minimal, else: Chrome),
      site:
        SiteInfo.new(
          version: Mix.Project.config()[:version],
          git_branch: Git.git_branch(),
          git_revision: Git.git_revision(),
          years: Keyword.get_lazy(opts, :years, fn -> Keyword.fetch!(course_site, :years) end),
          years_short:
            Keyword.get_lazy(opts, :years_short, fn ->
              Keyword.fetch!(course_site, :years_short)
            end)
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

  defp report!(%Report{} = report) do
    Mix.shell().info(
      "Rendered #{report.pages} pages and #{report.chapters} chapters into #{report.files} files, beside #{report.page_assets} files next to a page and #{report.assets} global assets"
    )

    Mix.shell().info("Wrote #{report.output_dir}, and every link of it resolves")
  end

  defp abort!(what, errors) do
    Mix.shell().error("#{what}:")
    Enum.each(errors, &Mix.shell().error("  " <> &1))
    exit({:shutdown, 1})
  end
end
