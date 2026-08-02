defmodule ArchiDep.CourseSiteWatcherTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSiteWatcher

  @moduletag :tmp_dir

  # Short enough that a test waiting out the window is not felt, long enough
  # that two events sent one after the other land inside it.
  @debounce 100

  @course_dir "/archidep/course"

  describe "rebuild?/2" do
    test "rebuilds for what a build reads" do
      for path <- [
            "/archidep/course/collections/_course/101-command-line/subject.md",
            "/archidep/course/collections/_cheatsheets/git/cheatsheet.md",
            "/archidep/course/_data/course.yml",
            "/archidep/course/_includes/icons/tip.html",
            "/archidep/course/favicons/heig.png",
            "/archidep/course/favicon.ico",
            "/archidep/course/index.md"
          ] do
        assert CourseSiteWatcher.rebuild?(path, @course_dir) == true,
               "expected #{path} to rebuild"
      end
    end

    test "rebuilds for nothing else" do
      for path <- [
            "/archidep/course/node_modules/reveal.js/dist/reveal.js",
            "/archidep/course/src/scripts/pdf.ts",
            "/archidep/course/pdf/101-command-line.pdf",
            "/archidep/course/README.md",
            "/archidep/app/priv/course/progress.json",
            "/archidep/app/priv/static/assets/app/app.js",
            "/somewhere/else/entirely.md"
          ] do
        assert CourseSiteWatcher.rebuild?(path, @course_dir) == false,
               "expected #{path} not to rebuild"
      end
    end
  end

  describe "the first build" do
    test "runs everything a build of this course takes", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      options = options()
      start_watcher!(dirs, options: options)

      assert_receive {:built, opts}

      assert opts == [
               progress: sessions(),
               content_dir: Path.join(dirs.course_dir, "collections"),
               home_file: Path.join(dirs.course_dir, "index.md"),
               includes_dir: Path.join(dirs.course_dir, "_includes"),
               declarations_file: Path.join(dirs.course_dir, "_data/course.yml"),
               root_files_dir: dirs.course_dir,
               static_dir: dirs.static_dir,
               digested: false,
               output_dir: dirs.build_dir,
               output: :swap,
               options: options
             ]
    end
  end

  describe "a file that changed" do
    test "rebuilds when it is one a build reads", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      watcher = start_watcher!(dirs)

      assert_receive {:built, _first}

      send(
        watcher,
        file_event(Path.join(dirs.course_dir, "collections/_course/507-dns/subject.md"))
      )

      assert_receive {:built, _second}, @debounce * 10
    end

    test "does not rebuild when it is not", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      watcher = start_watcher!(dirs)

      assert_receive {:built, _first}

      send(
        watcher,
        file_event(Path.join(dirs.course_dir, "node_modules/reveal.js/dist/reveal.js"))
      )

      refute_receive {:built, _second}, @debounce * 5
    end

    test "is one build even when several changed at once", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      watcher = start_watcher!(dirs)

      assert_receive {:built, _first}

      send(
        watcher,
        file_event(Path.join(dirs.course_dir, "collections/_course/507-dns/subject.md"))
      )

      send(
        watcher,
        file_event(Path.join(dirs.course_dir, "collections/_course/508-tls/subject.md"))
      )

      assert_receive {:built, _second}, @debounce * 10
      refute_receive {:built, _third}, @debounce * 5
    end
  end

  describe "rebuild/1" do
    test "builds now and says what came of it", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      watcher = start_watcher!(dirs)

      assert_receive {:built, _first}

      assert CourseSiteWatcher.rebuild(watcher) == {:ok, report()}
      assert_receive {:built, _second}
    end

    test "tells the browser to reload once the build is published", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      watcher = start_watcher!(dirs)

      # Answered only once the build it ran was published, which is when the
      # marker the live reloader watches is touched.
      assert CourseSiteWatcher.rebuild(watcher) == {:ok, report()}
      assert File.exists?(dirs.build_dir <> ".reload") == true
    end

    test "survives a build that failed, and tells no browser to reload", %{tmp_dir: tmp_dir} do
      dirs = dirs(tmp_dir)
      failure = {:error, "The site could not be rendered", ["a document says nothing"]}

      capture_log(fn ->
        watcher = start_watcher!(dirs, result: failure)

        assert_receive {:built, _first}

        # A call rather than a sleep: being answered at all is what says the
        # process took the failure rather than the failure taking the process.
        assert CourseSiteWatcher.rebuild(watcher) == failure
      end)

      assert File.exists?(dirs.build_dir <> ".reload") == false
    end
  end

  defp dirs(tmp_dir) do
    dirs = %{
      course_dir: Path.join(tmp_dir, "course"),
      static_dir: Path.join(tmp_dir, "static"),
      build_dir: Path.join(tmp_dir, "build")
    }

    File.mkdir_p!(dirs.course_dir)

    dirs
  end

  defp start_watcher!(dirs, overrides \\ []) do
    test = self()
    result = Keyword.get(overrides, :result, {:ok, report()})

    start_supervised!(
      {CourseSiteWatcher,
       [
         name: nil,
         course_dir: dirs.course_dir,
         build_dir: dirs.build_dir,
         progress: fn -> sessions() end,
         static_dir: dirs.static_dir,
         debounce: @debounce,
         options: Keyword.get(overrides, :options, options()),
         builder: fn opts ->
           send(test, {:built, opts})
           result
         end
       ]}
    )
  end

  defp file_event(path), do: {:file_event, self(), {path, [:modified]}}

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
