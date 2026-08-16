defmodule ArchiDep.CourseSiteWatcher do
  @moduledoc """
  Rebuilding the course material site whenever one of its sources changes.

  In development the site is served from a directory rather than rendered per
  request (see `ArchiDepWeb.Endpoint`), so something has to notice that a
  document was edited. This is that something: it watches the course material
  and runs a whole build when any of it changes.

  It watches the course material and **nothing else**. How far the course has
  got is the one input of a build that is not part of that material, and it is
  read through `ArchiDep.Course.course_sessions/0` rather than from wherever it
  happens to be kept — so moving that record from a file to the database is a
  change to the context and to nothing here. What it costs is that a progress
  edit is not noticed on its own until the admin console is what makes it;
  `rebuild/1` covers it meanwhile.

  It is here rather than inside `ArchiDep.CourseSite` because that subsystem is
  a set of pure functions over its inputs and holds no processes; running one of
  them on a timer is the application's business, the way fetching Git metadata
  is.

  What it is careful about:

  - **Booting cannot fail because of it.** `init/1` reads nothing, so a course
    directory that is missing, unreadable or broken leaves the application
    running and the first build reporting why.
  - **A failed build changes nothing.** Builds go through
    `ArchiDep.CourseSite.Builder` in `:swap` mode, so what is being served is
    replaced only by a build that succeeded, errors and all being logged
    instead. That is what makes a half-written document safe to save.
  - **The browser is told when the build is done**, not when the edit was made,
    by touching a marker file that Phoenix's live reloader watches. The output
    tree itself cannot be watched: publishing a build is a directory rename, and
    the filesystem reports that as one event without descending into it.
  """

  use GenServer

  alias ArchiDep.Course
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Git
  require Logger

  # What a build reads from the course material directory. The rest of it — the
  # asset sources, the generated PDFs — is either an input of some other
  # pipeline or an output of this one, and rebuilding on it would be a rebuild
  # per rebuild.
  @watched_dirs ["_data", "_includes", "collections", "favicons"]
  @watched_files ["favicon.ico", "index.md"]

  # Long enough that an editor writing a file in two goes is one rebuild, short
  # enough that saving and switching to the browser does not outrun it.
  @debounce 300

  # A build of the real course is measured in seconds, and it is run inside this
  # process, so a caller asking for one synchronously waits that long.
  @rebuild_timeout 300_000

  @enforce_keys [:build_opts, :reload_marker, :course_dir, :progress, :builder, :debounce]
  defstruct [:build_opts, :reload_marker, :course_dir, :progress, :builder, :debounce, :timer]

  @doc """
  Start watching the course material.

  Options:

  - `:course_dir` (required) — the course material directory.
  - `:build_dir` (required) — where the build being served is published.
  - `:progress` — how far the course has got, as a function returning the
    sessions. Read afresh for every build, so a build always reflects what the
    record says now. Defaults to `ArchiDep.Course.course_sessions/0`.
  - `:static_dir` — where the global assets were published. Defaults to the
    application's own `priv/static`, which is what the asset watchers write
    into.
  - `:reload_marker` — the file touched after a successful build, for the live
    reloader to see. Defaults to `<build_dir>.reload`.
  - `:options` — what the build is, as an
    `ArchiDep.CourseSite.Build.Site.Options`. Defaults to `build_options/0`.
  - `:builder` — what runs a build, as a function of the build's options.
    Defaults to `ArchiDep.CourseSite.Builder.build/1`.
  - `:debounce` — how long to wait for the changes to stop, in milliseconds.
  - `:name` — the name to register under.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, if(name, do: [name: name], else: []))
  end

  @doc """
  Build the site now and say what came of it, waiting for it to finish.

  This is what covers the sources a build reads but nothing watches — the global
  assets, which are written by the asset watchers and churn constantly — and it
  is how a build is asked for from IEx.
  """
  @spec rebuild(GenServer.server()) :: {:ok, Report.t()} | Builder.failure()
  def rebuild(server \\ __MODULE__), do: GenServer.call(server, :rebuild, @rebuild_timeout)

  @doc """
  Whether a file that changed is one a build reads.

  This is the whole of what the process decides, and it decides it about a path
  rather than about an event: a file is watched because of where it is, and the
  filesystem's opinion of what happened to it — created, written, renamed —
  makes no difference to whether the site has to be rendered again.
  """
  @spec rebuild?(Path.t(), Path.t()) :: boolean()
  def rebuild?(path, course_dir),
    do:
      path
      |> Path.expand()
      |> Path.relative_to(Path.expand(course_dir))
      |> Path.split()
      |> course_input?()

  @doc """
  What the application builds the course material site as, when it builds it
  itself.

  A development build is not digested — the asset watchers write `priv/static`
  under the names the sources have — and it is the live site rather than a copy
  of it, everything else about where it is published coming from the
  `course_site` configuration the dashboard's own links already come from. The
  build's identifier comes from there too rather than from the checkout: the
  dashboard names the same search index this build writes, and configuration is
  the one place both of them read.
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

  @impl GenServer
  def init(opts) do
    course_dir = Keyword.fetch!(opts, :course_dir)
    build_dir = Keyword.fetch!(opts, :build_dir)

    state = %__MODULE__{
      build_opts:
        Builder.course_inputs(course_dir) ++
          [
            # The asset watchers rewrite `priv/static` while the site is being
            # served, so a development build neither digests those names nor
            # takes a copy of them: the application serves them where they are.
            static_dir: Keyword.get_lazy(opts, :static_dir, &static_dir/0),
            digested: false,
            carry_assets: false,
            pdf_base: Keyword.get_lazy(opts, :pdf_base, &pdf_base/0),
            output_dir: build_dir,
            output: :swap,
            options: Keyword.get_lazy(opts, :options, &build_options/0)
          ],
      reload_marker: Keyword.get(opts, :reload_marker, build_dir <> ".reload"),
      course_dir: course_dir,
      progress: Keyword.get(opts, :progress, &Course.course_sessions/0),
      builder: Keyword.get(opts, :builder, &Builder.build/1),
      debounce: Keyword.get(opts, :debounce, @debounce)
    }

    {:ok, state, {:continue, :watch}}
  end

  @impl GenServer
  def handle_continue(:watch, %__MODULE__{} = state) do
    dirs = [state.course_dir]

    # `FileSystem` answers `:ignore` rather than an error when it has no backend
    # for the system it is on, so anything but a watcher is a system this cannot
    # work on and is said once instead of taking the application down with it.
    case FileSystem.start_link(dirs: dirs) do
      {:ok, watcher} ->
        FileSystem.subscribe(watcher)

      anything_else ->
        Logger.error(
          "The course material site will not be rebuilt as it is edited: #{inspect(dirs)} could not be watched (#{inspect(anything_else)})"
        )
    end

    {:noreply, build(state)}
  end

  @impl GenServer
  def handle_call(:rebuild, _from, %__MODULE__{} = state),
    do: {:reply, run(state), cancel(state)}

  @impl GenServer
  def handle_info({:file_event, _watcher, {path, _events}}, %__MODULE__{} = state) do
    if rebuild?(path, state.course_dir) do
      {:noreply, schedule(state)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:file_event, _watcher, :stop}, %__MODULE__{} = state) do
    Logger.warning("The course material site will not be rebuilt: the watcher stopped")
    {:noreply, state}
  end

  def handle_info(:rebuild, %__MODULE__{} = state),
    do: {:noreply, build(%{state | timer: nil})}

  # Every change within the debounce window is one build: the timer is pushed
  # back rather than added to, so saving five documents at once renders the site
  # once.
  defp schedule(%__MODULE__{debounce: debounce} = state) do
    state = cancel(state)
    %{state | timer: Process.send_after(self(), :rebuild, debounce)}
  end

  defp cancel(%__MODULE__{timer: nil} = state), do: state

  defp cancel(%__MODULE__{timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | timer: nil}
  end

  defp build(%__MODULE__{} = state) do
    _result = run(state)
    state
  end

  defp run(%__MODULE__{builder: builder, build_opts: build_opts, progress: progress} = state) do
    case builder.([{:progress, progress.()} | build_opts]) do
      {:ok, %Report{} = report} = result ->
        Logger.info(
          "Built the course material site: #{report.pages} pages and #{report.files} files in #{report.output_dir}"
        )

        touch(state.reload_marker)
        result

      {:error, what, errors} = result ->
        Logger.error("#{what}:\n" <> Enum.map_join(errors, "\n", &("  " <> &1)))
        result
    end
  end

  # Touched *after* the swap rather than before the build, so that the browser
  # is told to reload a build that exists.
  defp touch(marker) do
    File.mkdir_p!(Path.dirname(marker))
    File.touch!(marker)
  end

  defp static_dir, do: Application.app_dir(:archidep, "priv/static")

  # Stated in the seam's own terms — `:site` or `{:external, url}` — because
  # configuration is Elixir; only a command line has a string to parse.
  defp pdf_base,
    do: :archidep |> Application.get_env(:course_site, []) |> Keyword.get(:pdf_base)

  defp course_input?([first | rest]),
    do: first in @watched_dirs or (rest == [] and first in @watched_files)

  defp course_input?([]), do: false
end
