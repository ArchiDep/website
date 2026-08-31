defmodule ArchiDep.CourseSiteWatcher do
  @moduledoc """
  Rebuilding the course material site whenever one of its sources changes.

  In development the site is served from a directory rather than rendered per
  request (see `ArchiDepWeb.Endpoint`), so something has to notice that a
  document was edited. This is that something: it watches the course material
  and runs a whole build when any of it changes. What that build is, and what
  running one means, is `ArchiDep.CourseSitePublisher`; this decides only when.

  It watches the course material and **nothing else**. How far the course has
  got is the one input of a build that is not part of that material, so a
  progress edit is not noticed on its own until the admin console is what makes
  it; `rebuild/1` covers it meanwhile.

  What it is careful about:

  - **Booting cannot fail because of it.** `init/1` reads nothing, so a course
    directory that is missing, unreadable or broken leaves the application
    running and the first build reporting why. Production, which renders the
    site once at boot and serves what it wrote, makes the opposite trade.
  - **The browser is told when the build is done**, not when the edit was made,
    by touching a marker file that Phoenix's live reloader watches. The output
    tree itself cannot be watched: publishing a build is a directory rename, and
    the filesystem reports that as one event without descending into it.
  """

  use GenServer

  alias ArchiDep.CourseSite.Builder
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSitePublisher
  require Logger

  # What a build reads from the course material directory. The rest of it — the
  # asset sources, the generated PDFs — is either an input of some other
  # pipeline or an output of this one, and rebuilding on it would be a rebuild
  # per rebuild. `archives.yml` sits beside `course.yml` and is deliberately not
  # here: it is compiled into `ArchiDep.CourseSite.Archives` rather than read by
  # a build, so a rebuild on it would write the same bytes again.
  @watched_dirs ["chapters", "cheatsheets", "favicons", "icons"]
  @watched_files ["course.yml", "favicon.ico", "index.md"]

  # Long enough that an editor writing a file in two goes is one rebuild, short
  # enough that saving and switching to the browser does not outrun it.
  @debounce 300

  # A build of the real course is measured in seconds, and it is run inside this
  # process, so a caller asking for one synchronously waits that long.
  @rebuild_timeout 300_000

  @enforce_keys [:build_opts, :publish_opts, :reload_marker, :course_dir, :debounce]
  defstruct [:build_opts, :publish_opts, :reload_marker, :course_dir, :debounce, :timer]

  @doc """
  Start watching the course material.

  Options:

  - `:course_dir` (required) — the course material directory.
  - `:build_dir` (required) — where the build being served is published.
  - `:reload_marker` — the file touched after a successful build, for the live
    reloader to see. Defaults to `<build_dir>.reload`.
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

  @impl GenServer
  def init(opts) do
    course_dir = Keyword.fetch!(opts, :course_dir)
    build_dir = Keyword.fetch!(opts, :build_dir)

    state = %__MODULE__{
      build_opts:
        CourseSitePublisher.options(
          Keyword.take(opts, [:static_dir, :pdf_base, :options]) ++
            [
              course_dir: course_dir,
              build_dir: build_dir,
              # The asset watchers rewrite `priv/static` while the site is being
              # served, so a development build neither digests those names nor
              # takes a copy of them: the application serves them where they
              # are.
              digested: false,
              carry_assets: false
            ]
        ),
      publish_opts: Keyword.take(opts, [:progress, :builder]),
      reload_marker: Keyword.get(opts, :reload_marker, build_dir <> ".reload"),
      course_dir: course_dir,
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

  defp run(%__MODULE__{build_opts: build_opts, publish_opts: publish_opts} = state) do
    case CourseSitePublisher.publish(build_opts, publish_opts) do
      {:ok, %Report{}} = result ->
        touch(state.reload_marker)
        result

      {:error, _what, _errors} = result ->
        result
    end
  end

  # Touched *after* the swap rather than before the build, so that the browser
  # is told to reload a build that exists.
  defp touch(marker) do
    File.mkdir_p!(Path.dirname(marker))
    File.touch!(marker)
  end

  defp course_input?([first | rest]),
    do: first in @watched_dirs or (rest == [] and first in @watched_files)

  defp course_input?([]), do: false
end
