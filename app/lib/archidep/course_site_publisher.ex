defmodule ArchiDep.CourseSitePublisher do
  @moduledoc """
  Rendering the course material site from the running application.

  The site is a build rather than a set of pages rendered per request, so
  something has to run that build. That something is
  `ArchiDep.CourseSiteRebuilder`, which decides *when*. What is here is *what*:
  what a build of this deployment is, and what running one means.

  It is here rather than inside `ArchiDep.CourseSite` because that subsystem is
  a set of pure functions over its inputs and reads no configuration; deciding
  which build this deployment renders is the application's business, the way
  fetching Git metadata is.

  What it is careful about:

  - **A build is self-contained unless it is told otherwise.** The defaults are
    the build a static server can be pointed at: digested asset names, and a
    copy of those assets inside the build. Development is the exception and
    states it at the call, its assets being rewritten by the watchers while the
    site is being served.
  - **A failed build changes nothing.** Builds go through
    `ArchiDep.CourseSite.Builder` in `:swap` mode, so what is being served is
    replaced only by a build that succeeded, everything that was wrong with it
    being logged instead. That is what makes a half-written document safe to
    save, and what lets a deployment that cannot render refuse to serve without
    taking away the build it was already serving.
  - **How far the course has got is read afresh for every build**, through
    `ArchiDep.Course.course_sessions/0`, so a build reflects what the record
    says at the moment it runs rather than what it said when the application
    booted.

  One build at a time writes into one output directory. Publishing is a rename
  of a staging directory beside it, and two builds sharing an output directory
  would race over both that and the directory the previous build is moved to.
  Nothing here enforces it; `ArchiDep.CourseSiteRebuilder` is what does.
  """

  alias ArchiDep.Course
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Git
  require Logger

  @doc """
  Where this deployment's build reads from and writes to, as the options of
  `ArchiDep.CourseSite.Builder.build/1`.

  Options:

  - `:course_dir` (required) — the course material directory. The five inputs a
    build reads from it are derived by
    `ArchiDep.CourseSite.Builder.course_inputs/1`.
  - `:build_dir` (required) — where the build is published.
  - `:static_dir` — where the global assets were published. Defaults to the
    application's own `priv/static`, which is where both `mix phx.digest` and
    the asset watchers write.
  - `:digested` — whether those assets are named after their contents. Defaults
    to `true`.
  - `:carry_assets` — whether the build takes a copy of them. Defaults to
    `true`.
  - `:pdf_base` — where the generated PDFs of this build are published. Defaults
    to the `course_site` configuration, which is where the one fact about them
    that is not worked out from the course already lives.
  - `:options` — what the build is, as an
    `ArchiDep.CourseSite.Build.Site.Options`. Defaults to `build_options/0`.
  """
  @spec options(keyword()) :: keyword()
  def options(opts) when is_list(opts) do
    build_dir = Keyword.fetch!(opts, :build_dir)

    opts
    |> Keyword.fetch!(:course_dir)
    |> Builder.course_inputs()
    |> Kernel.++(
      static_dir: Keyword.get_lazy(opts, :static_dir, &static_dir/0),
      digested: Keyword.get(opts, :digested, true),
      carry_assets: Keyword.get(opts, :carry_assets, true),
      pdf_base: Keyword.get_lazy(opts, :pdf_base, &pdf_base/0),
      output_dir: build_dir,
      output: :swap,
      options: Keyword.get_lazy(opts, :options, &build_options/0)
    )
  end

  @doc """
  Run a build and say what came of it, logging what it did or everything that
  was wrong with it.

  The first argument is what `options/1` returns. The rest is what a caller may
  stand in for:

  - `:progress` — how far the course has got, as a function returning the
    sessions. Called for every build, so a build always reflects what the record
    says now. Defaults to `ArchiDep.Course.course_sessions/0`.
  - `:builder` — what runs a build, as a function of the build's options.
    Defaults to `ArchiDep.CourseSite.Builder.build/1`.
  """
  @spec publish(keyword(), keyword()) :: {:ok, Report.t()} | Builder.failure()
  def publish(build_opts, opts \\ []) when is_list(build_opts) and is_list(opts) do
    progress = Keyword.get(opts, :progress, &Course.course_sessions/0)
    builder = Keyword.get(opts, :builder, &Builder.build/1)

    case builder.([{:progress, progress.()} | build_opts]) do
      {:ok, %Report{} = report} = result ->
        Logger.info(
          "Built the course material site: #{report.pages} pages and #{report.files} files in #{report.output_dir}"
        )

        result

      {:error, what, errors} = result ->
        Logger.error("#{what}:\n" <> Enum.map_join(errors, "\n", &("  " <> &1)))
        result
    end
  end

  @doc """
  What the application builds the course material site as.

  Everything about where the build is published comes from the `course_site`
  configuration the dashboard's own links already come from. The build's
  identifier comes from there too rather than from the checkout: the dashboard
  names the same search index this build writes, and configuration is the one
  place both of them read.
  """
  @spec build_options() :: Site.Options.t()
  def build_options do
    config = Application.get_env(:archidep, :course_site, [])

    Site.Options.new(
      urls:
        UrlContext.new(
          mode: Keyword.get(config, :mode, :live),
          base_path: Keyword.get(config, :base_path, ""),
          version: Keyword.get(config, :version),
          build_id: Keyword.fetch!(config, :build_id)
        ),
      site:
        SiteInfo.new(
          version: to_string(Application.spec(:archidep, :vsn)),
          git_branch: Git.git_branch(),
          git_revision: Git.git_revision(),
          years: Keyword.fetch!(config, :years),
          years_short: Keyword.fetch!(config, :years_short)
        )
    )
  end

  defp static_dir, do: Application.app_dir(:archidep, "priv/static")

  # Stated in the seam's own terms — `:site` or `{:external, url}` — because
  # configuration is Elixir; only a command line has a string to parse.
  defp pdf_base,
    do: :archidep |> Application.get_env(:course_site, []) |> Keyword.get(:pdf_base)
end
