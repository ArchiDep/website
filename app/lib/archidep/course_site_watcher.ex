defmodule ArchiDep.CourseSiteWatcher do
  @moduledoc """
  Noticing that the course material changed.

  In development the site is served from a directory rather than rendered per
  request (see `ArchiDepWeb.Endpoint`), so something has to notice that a
  document was edited. This is that something, and that is the whole of it: what
  a build is, when one runs and what running one means all belong to
  `ArchiDep.CourseSiteRebuilder`, which is the one process that renders. This
  reports, and does not render.

  It watches the course material and **nothing else**. How far the course has
  got is the one input of a build that is not part of that material, and it is
  the admin console that changes it: the rebuilder hears about that directly.

  What it is careful about:

  - **Booting cannot fail because of it.** `init/1` reads nothing, so a course
    directory that is missing or unreadable leaves the application running.
  - **It decides about a path rather than about an event.** A file is watched
    because of where it is, and the filesystem's opinion of what happened to it
    — created, written, renamed — makes no difference to whether the site has to
    be rendered again.
  """

  use GenServer

  alias ArchiDep.CourseSiteRebuilder
  require Logger

  # What a build reads from the course material directory. The rest of it — the
  # asset sources, the generated PDFs — is either an input of some other
  # pipeline or an output of this one, and rebuilding on it would be a rebuild
  # per rebuild. `archives.yml` sits beside `course.yml` and is deliberately not
  # here: it is compiled into `ArchiDep.CourseSite.Archives` rather than read by
  # a build, so a rebuild on it would write the same bytes again.
  @watched_dirs ["chapters", "cheatsheets", "favicons", "icons"]
  @watched_files ["course.yml", "favicon.ico", "index.md"]

  @enforce_keys [:course_dir, :rebuilder]
  defstruct [:course_dir, :rebuilder]

  @doc """
  Start watching the course material.

  Options:

  - `:course_dir` (required) — the course material directory.
  - `:rebuilder` — what to ask for a build. Defaults to
    `ArchiDep.CourseSiteRebuilder`.
  - `:name` — the name to register under.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, if(name, do: [name: name], else: []))
  end

  @doc """
  Whether a file that changed is one a build reads.
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
    state = %__MODULE__{
      course_dir: Keyword.fetch!(opts, :course_dir),
      rebuilder: Keyword.get(opts, :rebuilder, CourseSiteRebuilder)
    }

    {:ok, state, {:continue, :watch}}
  end

  @impl GenServer
  def handle_continue(:watch, %__MODULE__{course_dir: course_dir} = state) do
    dirs = [course_dir]

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

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:file_event, _watcher, {path, _events}}, %__MODULE__{} = state) do
    if rebuild?(path, state.course_dir) do
      :ok = CourseSiteRebuilder.request(state.rebuilder)
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _watcher, :stop}, %__MODULE__{} = state) do
    Logger.warning("The course material site will not be rebuilt: the watcher stopped")
    {:noreply, state}
  end

  defp course_input?([first | rest]),
    do: first in @watched_dirs or (rest == [] and first in @watched_files)

  defp course_input?([]), do: false
end
