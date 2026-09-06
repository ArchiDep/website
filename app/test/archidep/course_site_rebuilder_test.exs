defmodule ArchiDep.CourseSiteRebuilderTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSiteRebuilder
  alias Phoenix.PubSub

  @moduletag :tmp_dir

  # Short enough that a test waiting out the window is not felt, long enough
  # that two events sent one after the other land inside it.
  @debounce 100

  @pubsub ArchiDep.PubSub

  describe "the first build" do
    test "runs everything a build of this course takes", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      options = options()
      start_rebuilder!(dirs, options: options)

      assert_receive {:built, opts}

      assert opts == [
               progress: sessions(),
               content_dir: dirs.course_dir,
               home_file: Path.join(dirs.course_dir, "index.md"),
               includes_dir: dirs.course_dir,
               declarations_file: Path.join(dirs.course_dir, "course.yml"),
               root_files_dir: dirs.course_dir,
               static_dir: dirs.static_dir,
               digested: false,
               carry_assets: false,
               pdf_base: nil,
               output_dir: dirs.build_dir,
               output: :swap,
               options: options
             ]
    end

    test "says where the PDFs are when the configuration does", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      options = options()
      start_rebuilder!(dirs, options: options, pdf_base: {:external, "https://example.com/pdf"})

      assert_receive {:built, opts}

      assert opts == [
               progress: sessions(),
               content_dir: dirs.course_dir,
               home_file: Path.join(dirs.course_dir, "index.md"),
               includes_dir: dirs.course_dir,
               declarations_file: Path.join(dirs.course_dir, "course.yml"),
               root_files_dir: dirs.course_dir,
               static_dir: dirs.static_dir,
               digested: false,
               carry_assets: false,
               pdf_base: {:external, "https://example.com/pdf"},
               output_dir: dirs.build_dir,
               output: :swap,
               options: options
             ]
    end

    test "takes the application down when it is required and fails", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      failure = {:error, "The site could not be rendered", ["a document says nothing"]}

      capture_log(fn ->
        # The exception is wrapped in the supervisor's own report — a stacktrace
        # and the child specification, neither of which this is about — so it is
        # matched out and asserted on its own.
        assert {:error, {{%RuntimeError{} = error, _stacktrace}, _child_spec}} =
                 start_supervised(
                   {CourseSiteRebuilder, start_opts(dirs, boot: :required, result: failure)}
                 )

        assert Exception.message(error) ==
                 "The course material site could not be built. The site could not be rendered."
      end)
    end
  end

  describe "a build that was asked for" do
    test "runs once the changes stop", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      rebuilder = start_rebuilder!(dirs)

      assert_receive {:built, _first}

      :ok = CourseSiteRebuilder.request(rebuilder)

      assert_receive {:built, _second}, @debounce * 10
    end

    test "is one build for every change within the window", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      rebuilder = start_rebuilder!(dirs)

      assert_receive {:built, _first}

      :ok = CourseSiteRebuilder.request(rebuilder)
      :ok = CourseSiteRebuilder.request(rebuilder)
      :ok = CourseSiteRebuilder.request(rebuilder)

      assert_receive {:built, _second}, @debounce * 10

      assert armed?(rebuilder) == false
      refute_received {:built, _third}
    end

    test "runs again for a change that arrived while it was running", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      test = self()

      # A build that does not return until the test lets it, so that a request
      # can be made while one is provably running. The process is inside the
      # builder at that moment, so the request waits in its mailbox — which is
      # the whole of what keeps it from being lost.
      rebuilder =
        start_rebuilder!(dirs,
          builder: fn opts ->
            send(test, {:built, opts})
            receive do: (:go -> {:ok, report()})
          end
        )

      assert_receive {:built, _first}

      :ok = CourseSiteRebuilder.request(rebuilder)
      send(rebuilder, :go)

      assert_receive {:built, _second}, @debounce * 10
      send(rebuilder, :go)

      assert armed?(rebuilder) == false
      refute_received {:built, _third}
      assert Process.alive?(rebuilder) == true
    end
  end

  describe "rebuild/1" do
    test "builds now and says what came of it", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      rebuilder = start_rebuilder!(dirs)

      assert_receive {:built, _first}

      assert CourseSiteRebuilder.rebuild(rebuilder) == {:ok, report()}
      assert_receive {:built, _second}
    end

    test "tells the browser to reload once the build is published", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      rebuilder = start_rebuilder!(dirs, reload_marker: dirs.build_dir <> ".reload")

      # Answered only once the build it ran was published, which is when the
      # marker the live reloader watches is touched.
      assert CourseSiteRebuilder.rebuild(rebuilder) == {:ok, report()}
      assert File.exists?(dirs.build_dir <> ".reload") == true
    end

    test "tells no browser when nothing asked to be told", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      rebuilder = start_rebuilder!(dirs)

      assert CourseSiteRebuilder.rebuild(rebuilder) == {:ok, report()}
      assert File.exists?(dirs.build_dir <> ".reload") == false
    end

    test "survives a build that failed, and tells no browser to reload", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      failure = {:error, "The site could not be rendered", ["a document says nothing"]}

      capture_log(fn ->
        rebuilder =
          start_rebuilder!(dirs, result: failure, reload_marker: dirs.build_dir <> ".reload")

        assert_receive {:built, _first}

        # A call rather than a sleep: being answered at all is what says the
        # process took the failure rather than the failure taking the process.
        assert CourseSiteRebuilder.rebuild(rebuilder) == failure
      end)

      assert File.exists?(dirs.build_dir <> ".reload") == false
    end
  end

  describe "how far the course has got" do
    test "asks for a build when it changes", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      topic = "course-sessions-#{System.unique_integer([:positive])}"
      start_rebuilder!(dirs, course_sessions_topic: topic)

      assert_receive {:built, _first}

      :ok =
        PubSub.broadcast(@pubsub, topic, {:course_session_created, :an_event, :a_reference})

      assert_receive {:built, _second}, @debounce * 10
    end
  end

  describe "the outcome of a build" do
    test "is announced to whoever is watching", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      topic = "course-site-builds-#{System.unique_integer([:positive])}"
      :ok = PubSub.subscribe(@pubsub, topic)

      start_rebuilder!(dirs, builds_topic: topic)

      assert_receive {:course_site_built, {:ok, report}}
      assert report == report()
    end

    test "is announced when it is a failure too", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      topic = "course-site-builds-#{System.unique_integer([:positive])}"
      failure = {:error, "The site could not be rendered", ["a document says nothing"]}
      :ok = PubSub.subscribe(@pubsub, topic)

      capture_log(fn ->
        start_rebuilder!(dirs, builds_topic: topic, result: failure)
        assert_receive {:course_site_built, ^failure}
      end)
    end
  end

  # Whether another build is waiting for the changes to stop. Reading the state
  # is a synchronous call, so it is answered only once every message sent before
  # it has been handled: it says what the process will do next, and it says it
  # without waiting out a debounce window that must not fire.
  defp armed?(rebuilder), do: :sys.get_state(rebuilder).timer != nil

  defp dirs(tmp_dir) do
    dirs = %{
      course_dir: Path.join(tmp_dir, "course"),
      static_dir: Path.join(tmp_dir, "static"),
      build_dir: Path.join(tmp_dir, "build")
    }

    File.mkdir_p!(dirs.course_dir)

    dirs
  end

  defp start_rebuilder!(dirs, overrides \\ []),
    do: start_supervised!({CourseSiteRebuilder, start_opts(dirs, overrides)})

  defp start_opts(dirs, overrides) do
    test = self()
    result = Keyword.get(overrides, :result, {:ok, report()})

    [
      name: nil,
      course_dir: dirs.course_dir,
      build_dir: dirs.build_dir,
      static_dir: dirs.static_dir,
      digested: false,
      carry_assets: false,
      progress: fn -> sessions() end,
      debounce: @debounce,
      options: Keyword.get(overrides, :options, options()),
      builder:
        Keyword.get(overrides, :builder, fn opts ->
          send(test, {:built, opts})
          result
        end),
      # Both global topics are resolved by the caller rather than by the process,
      # which is started at boot and has no per-test scope to resolve — see
      # `ArchiDep.PubSub.Scope`. Unique names keep concurrent tests apart the way
      # that scope does everywhere else.
      course_sessions_topic:
        Keyword.get(
          overrides,
          :course_sessions_topic,
          "course-sessions-#{System.unique_integer([:positive])}"
        ),
      builds_topic:
        Keyword.get(
          overrides,
          :builds_topic,
          "course-site-builds-#{System.unique_integer([:positive])}"
        )
    ] ++ Keyword.take(overrides, [:pdf_base, :reload_marker, :boot])
  end

  defp sessions, do: [Session.new(~D[2026-02-02], "CLI", [100], [101], [])]

  defp options,
    do:
      Site.Options.new(
        urls: UrlContext.new(mode: :live, build_id: "test"),
        site:
          SiteInfo.new(
            version: "1.2.3",
            git_branch: "main",
            git_revision: "abc123",
            years: "2025-2026",
            years_short: "25-26"
          )
      )

  defp report,
    do: %Report{
      output_dir: "/archidep/app/tmp/course_site",
      pages: 64,
      chapters: 50,
      files: 77,
      page_assets: 362,
      assets: 143
    }
end
