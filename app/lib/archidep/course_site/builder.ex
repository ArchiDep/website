defmodule ArchiDep.CourseSite.Builder do
  @moduledoc """
  Running a whole build, for a caller that is not a Mix task.

  `ArchiDep.CourseSite.Build` is deliberately a set of steps rather than one
  call: each is a different kind of failure, and the task driving them decides
  what to print between them. But a build is also run from a watcher and from
  IEx, where there is no `Mix.shell/0` and no `exit/1` to abort with, so the
  order of those steps and what each of them means is named here rather than
  copied.

  Every failure comes back as strings: what could not be done and, under it,
  each thing that was wrong with it. A caller that prints them and a caller that
  logs them want the same words, and neither is in a position to make anything
  of the tuples the stages report — those are already described by the module
  that raised them.

  This orchestrates and does not touch the filesystem itself, which is what
  keeps `ArchiDep.CourseSite.Build` the one module of the subsystem that reads
  and writes files.
  """

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.LinkCheck
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Build.Site.Options
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Urls.UrlContext

  @typedoc """
  What could not be done, and everything that was wrong with it.
  """
  @type failure :: {:error, String.t(), nonempty_list(String.t())}

  @typedoc """
  What a build does with the directory it writes into:

  - `:empty` — write into it, refusing one that is not empty.
  - `:clean` — empty it first.
  - `:swap` — render beside it and put the result in its place when it is
    whole, so that a build that fails leaves the previous one being served.
  """
  @type output_mode :: :empty | :clean | :swap

  @staging_suffix ".staging"

  @doc """
  Where each of the inputs a build reads from a course directory is, so that a
  caller names the course rather than five paths inside it.

  Two callers deriving those paths separately is two chances to disagree about
  where `course.yml` is, and the disagreement would surface as a build reading
  the wrong file rather than as a build failing to compile. How far the course
  has got is **not** among them, being the one input of a build that is not part
  of the course material — see the `:progress` option of
  `ArchiDep.CourseSite.Build.site_inputs/1`.
  """
  @spec course_inputs(Path.t()) :: keyword()
  def course_inputs(course_dir),
    do: [
      content_dir: Path.join(course_dir, "collections"),
      home_file: Path.join(course_dir, "index.md"),
      includes_dir: Path.join(course_dir, "_includes"),
      declarations_file: Path.join(course_dir, "_data/course.yml"),
      root_files_dir: course_dir
    ]

  @doc """
  Read, render, write and check a whole build.

  Options are those of `ArchiDep.CourseSite.Build.site_inputs/1` — which
  `course_inputs/1` derives all but two of — and:

  - `:output_dir` (required) — where the build is published.
  - `:options` (required) — what the build is, as an
    `ArchiDep.CourseSite.Build.Site.Options`. The two asset manifests of its URL
    context are **replaced** by the ones the build read: which name each asset
    was published under is something a build finds out rather than something its
    caller can state, and threading them back in by hand is the step this exists
    to remove.
  - `:output` — see `t:output_mode/0`. Defaults to `:empty`.
  - `:carry_assets` — whether the build copies the global assets into itself.
    Defaults to `true`, which is what makes a build self-contained. The
    development build is the exception: its assets are rewritten by the watchers
    while it is being served, so a copy of them would be stale the moment a
    stylesheet is edited, and the application serves them live instead.
  """
  @spec build(keyword()) :: {:ok, Report.t()} | failure()
  def build(opts) when is_list(opts) do
    output_dir = Keyword.fetch!(opts, :output_dir)
    output = Keyword.get(opts, :output, :empty)
    write_dir = write_dir(output_dir, output)

    with {:ok, inputs} <- read(opts),
         options = options(Keyword.fetch!(opts, :options), inputs),
         edition_dir = edition_dir(write_dir, options),
         {:ok, site} <- plan(inputs, options),
         :ok <- prepare(write_dir, output),
         :ok <- publish(site, inputs, opts, write_dir, edition_dir),
         :ok <- check(site, edition_dir),
         :ok <- swap(output_dir, write_dir, output),
         do: {:ok, report(output_dir, inputs, site)}
  end

  defp read(opts) do
    case Build.site_inputs(opts) do
      {:ok, inputs} -> {:ok, inputs}
      {:error, errors} -> failure("The build could not be read", errors, &Build.format_error/1)
    end
  end

  defp options(%Options{urls: %UrlContext{} = urls} = options, inputs),
    do: %{options | urls: %{urls | assets: inputs.assets, page_assets: inputs.page_assets}}

  defp plan(inputs, options) do
    case Site.plan(inputs, options) do
      {:ok, site} -> {:ok, site}
      {:error, errors} -> failure("The site could not be rendered", errors, &Site.format_error/1)
    end
  end

  defp prepare(write_dir, output) do
    case Build.prepare_output(write_dir, prepare_mode(output)) do
      :ok ->
        :ok

      {:error, errors} ->
        failure("The output directory could not be made ready", errors, &Build.format_error/1)
    end
  end

  # The pages of an edition and the files sitting next to them go under the
  # edition; the planned files carry their own path, the mount point's among
  # them, so they are written from the output directory itself.
  defp publish(site, inputs, opts, write_dir, edition_dir) do
    result =
      with :ok <- Build.publish_site(site, write_dir),
           :ok <-
             Build.publish_page_assets(
               inputs.page_assets,
               inputs.tree,
               Keyword.fetch!(opts, :content_dir),
               edition_dir
             ),
           do: publish_assets(opts, edition_dir)

    case result do
      :ok -> :ok
      {:error, errors} -> failure("The build could not be written", errors, &Build.format_error/1)
    end
  end

  defp publish_assets(opts, edition_dir) do
    if Keyword.get(opts, :carry_assets, true) do
      Build.publish_assets(Keyword.fetch!(opts, :static_dir), edition_dir)
    else
      :ok
    end
  end

  defp check(site, edition_dir) do
    case LinkCheck.check(site.pages, Build.output_files(edition_dir)) do
      [] ->
        :ok

      [_first | _rest] = broken ->
        failure("#{length(broken)} links lead nowhere", broken, &LinkCheck.format_error/1)
    end
  end

  defp swap(output_dir, write_dir, :swap) do
    case Build.swap_output(output_dir, write_dir) do
      :ok ->
        :ok

      {:error, errors} ->
        failure("The build could not be published", errors, &Build.format_error/1)
    end
  end

  defp swap(_output_dir, _write_dir, _mode), do: :ok

  # A staging directory is emptied rather than owned, because what is in it is
  # what an earlier build left when it failed — which is precisely the case this
  # mode exists to survive.
  defp prepare_mode(:swap), do: :clean
  defp prepare_mode(mode), do: mode

  defp write_dir(output_dir, :swap), do: output_dir <> @staging_suffix
  defp write_dir(output_dir, _mode), do: output_dir

  # A build writes into the directory its mount point names, so the edition it
  # holds is a directory of that one — the same segment its URLs carry.
  defp edition_dir(write_dir, %Options{urls: urls}),
    do: write_dir <> UrlContext.edition_prefix(urls)

  defp failure(what, errors, format), do: {:error, what, Enum.map(errors, format)}

  defp report(output_dir, inputs, site),
    do: %Report{
      output_dir: output_dir,
      pages: map_size(inputs.sources),
      chapters: Enum.count(Structure.chapters(inputs.structure)),
      files: map_size(site.files),
      page_assets: map_size(inputs.page_assets.page_assets),
      assets: map_size(inputs.assets.assets)
    }
end
