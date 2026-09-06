defmodule ArchiDep.CourseSiteRebuilder do
  @moduledoc """
  Running the builds of the course material site that this deployment renders
  for itself.

  The site is a build rather than pages rendered per request, so something has
  to decide when to run one. This is that something, and it is the **only**
  thing that runs one inside the application: publishing a build is a directory
  rename (`ArchiDep.CourseSite.Build.swap_output/2`), and two processes
  rendering into one output directory would race over both that and the
  directory the previous build is moved aside to. What a build of this
  deployment *is* stays `ArchiDep.CourseSitePublisher`'s business; this decides
  only when.

  Three things ask for a build:

  - **Boot**, always and unconditionally. Never skipped because the output
    directory already holds one: a rollback puts an older image back, and an
    application that saw a build already there would leave the newer site being
    served by the older application.
  - **A change to how far the course has got**, which the admin console makes
    and this hears through `ArchiDep.Course.subscribe_course_sessions/0`.
    Progress is baked into the pages, so changing it means rendering them again.
  - **A change to the course material**, which `ArchiDep.CourseSiteWatcher`
    notices in development and reports here.

  What it is careful about:

  - **Rapid changes are one build.** `request/1` re-arms a timer rather than
    queueing behind itself, so saving five documents at once, or correcting a
    session straight after recording it, renders the site once.
  - **A request made during a build is not lost.** The build runs in this
    process, so anything arriving while it runs waits in the mailbox and re-arms
    the debounce when it is handled — the next build starts from what the record
    says then rather than from what it said when the running build read it.
  - **A failed build changes nothing and takes nothing down.** Builds go through
    `ArchiDep.CourseSite.Builder` in `:swap` mode, so what is being served is
    replaced only by a build that succeeded, everything that was wrong with it
    being logged instead. That is what makes a half-written document safe to
    save, and what keeps an unrenderable progress edit from ending the
    application.
  - **Except at boot, where the opposite is right.** Told `boot: :required`,
    `init/1` raises if the first build fails, which fails
    `Supervisor.start_link/2` and so `Application.start/2` — the health check
    fails, the deployment rolls back, and the static server in front goes on
    serving the previous build throughout, because the swap never happened. A
    supervisor does not retry a child that failed to *start*, so the build is
    attempted once. Development makes the opposite trade (`boot: :deferred`):
    the first build runs after `init/1` and only reports, so a course directory
    that is missing or broken leaves the application running and says why.
  """

  use GenServer

  alias ArchiDep.Course
  alias ArchiDep.CourseSite.Builder
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSitePublisher
  alias ArchiDep.PubSub.Scope
  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  # The topic the outcome of each build is announced on, before the per-test
  # scope is applied. Subscribers that can resolve the scope themselves use
  # `subscribe_builds/0`; this process is started at boot and cannot, so it is
  # handed the resolved name — see `ArchiDep.PubSub.Scope`.
  @builds_topic "course-site-builds"

  # Long enough that an editor writing a file in two goes is one rebuild, short
  # enough that saving and switching to the browser does not outrun it.
  @debounce 300

  # A build of the real course is measured in seconds, and it is run inside this
  # process, so a caller asking for one synchronously waits that long.
  @rebuild_timeout 300_000

  @enforce_keys [:build_opts, :publish_opts, :reload_marker, :builds_topic, :debounce]
  defstruct [:build_opts, :publish_opts, :reload_marker, :builds_topic, :debounce, :timer]

  @typedoc """
  What came of a build, as it is announced.
  """
  @type outcome :: {:ok, Report.t()} | Builder.failure()

  @doc """
  Start rendering the course material site for this deployment.

  Options:

  - `:course_dir` (required) — the course material directory.
  - `:build_dir` (required) — where the build is published.
  - `:boot` — `:required` to render the site in `init/1` and raise if it cannot
    be rendered, or `:deferred` to render it after `init/1` and only report.
    Defaults to `:deferred`.
  - `:reload_marker` — a file to touch after a successful build, for a live
    reloader to watch. Defaults to none, a deployment that is not being edited
    having nothing to tell a browser.
  - `:course_sessions_topic` — the topic changes to the record of how far the
    course has got arrive on, resolved by the caller. Defaults to the
    unscoped name.
  - `:builds_topic` — the topic the outcome of each build is announced on, also
    resolved by the caller.
  - `:debounce` — how long to wait for the changes to stop, in milliseconds.
  - `:static_dir`, `:digested`, `:carry_assets`, `:pdf_base`, `:options` — what
    a build of this deployment is, as `ArchiDep.CourseSitePublisher.options/1`
    takes them.
  - `:progress`, `:builder` — what a caller may stand in for, as
    `ArchiDep.CourseSitePublisher.publish/2` takes them.
  - `:name` — the name to register under.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, if(name, do: [name: name], else: []))
  end

  @doc """
  Ask for the site to be rendered again once the changes stop.
  """
  @spec request(GenServer.server()) :: :ok
  def request(server \\ __MODULE__), do: GenServer.cast(server, :request)

  @doc """
  Render the site now and say what came of it, waiting for it to finish.

  This is what covers the inputs a build reads but nothing announces — the
  global assets, which the asset watchers rewrite constantly — and it is how a
  build is asked for from IEx. A caller arriving while a build is running waits
  for that one to be published and then for their own.
  """
  @spec rebuild(GenServer.server()) :: outcome()
  def rebuild(server \\ __MODULE__), do: GenServer.call(server, :rebuild, @rebuild_timeout)

  @doc """
  Subscribe the calling process to the outcome of every build, as
  `{:course_site_built, outcome}`.
  """
  @spec subscribe_builds() :: :ok
  def subscribe_builds, do: PubSub.subscribe(@pubsub, Scope.global_topic(@builds_topic))

  @impl GenServer
  def init(opts) do
    state = %__MODULE__{
      build_opts:
        CourseSitePublisher.options(
          Keyword.take(opts, [:static_dir, :digested, :carry_assets, :pdf_base, :options]) ++
            [
              course_dir: Keyword.fetch!(opts, :course_dir),
              build_dir: Keyword.fetch!(opts, :build_dir)
            ]
        ),
      publish_opts: Keyword.take(opts, [:progress, :builder]),
      reload_marker: Keyword.get(opts, :reload_marker),
      builds_topic: Keyword.get(opts, :builds_topic, @builds_topic),
      debounce: Keyword.get(opts, :debounce, @debounce)
    }

    :ok =
      PubSub.subscribe(
        @pubsub,
        Keyword.get(opts, :course_sessions_topic, Course.course_sessions_topic())
      )

    case Keyword.get(opts, :boot, :deferred) do
      :required -> {:ok, boot!(state)}
      :deferred -> {:ok, state, {:continue, :first_build}}
    end
  end

  @impl GenServer
  def handle_continue(:first_build, %__MODULE__{} = state), do: {:noreply, build(state)}

  @impl GenServer
  def handle_call(:rebuild, _from, %__MODULE__{} = state),
    do: {:reply, run(state), cancel(state)}

  @impl GenServer
  def handle_cast(:request, %__MODULE__{} = state), do: {:noreply, schedule(state)}

  @impl GenServer
  def handle_info({message, _event, _reference}, %__MODULE__{} = state)
      when message in [
             :course_session_created,
             :course_session_updated,
             :course_session_deleted
           ],
      do: {:noreply, schedule(state)}

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

  defp boot!(%__MODULE__{} = state) do
    case run(state) do
      {:ok, %Report{}} ->
        state

      {:error, what, _errors} ->
        raise "The course material site could not be built. #{what}."
    end
  end

  defp build(%__MODULE__{} = state) do
    _outcome = run(state)
    state
  end

  defp run(%__MODULE__{build_opts: build_opts, publish_opts: publish_opts} = state) do
    outcome = CourseSitePublisher.publish(build_opts, publish_opts)

    case outcome do
      {:ok, %Report{}} -> touch(state.reload_marker)
      {:error, _what, _errors} -> :ok
    end

    :ok = PubSub.broadcast(@pubsub, state.builds_topic, {:course_site_built, outcome})

    outcome
  end

  # Touched *after* the swap rather than before the build, so that the browser
  # is told to reload a build that exists.
  defp touch(nil), do: :ok

  defp touch(marker) do
    File.mkdir_p!(Path.dirname(marker))
    File.touch!(marker)
  end
end
