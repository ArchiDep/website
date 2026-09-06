defmodule ArchiDep.CourseSiteWatcherTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSiteWatcher
  alias ArchiDep.Support.GenServerProxy

  @moduletag :tmp_dir

  @course_dir "/archidep/course"

  describe "rebuild?/2" do
    test "rebuilds for what a build reads" do
      for path <- [
            "/archidep/course/chapters/101-command-line/subject.md",
            "/archidep/course/cheatsheets/git/cheatsheet.md",
            "/archidep/course/course.yml",
            "/archidep/course/icons/tip.html",
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
            "/archidep/course/archives.yml",
            "/archidep/course/archives/2025.json",
            "/archidep/app/priv/course/progress.json",
            "/archidep/app/priv/static/assets/app/app.js",
            "/somewhere/else/entirely.md"
          ] do
        assert CourseSiteWatcher.rebuild?(path, @course_dir) == false,
               "expected #{path} not to rebuild"
      end
    end
  end

  describe "a file that changed" do
    test "asks for a build when it is one a build reads", %{tmp_dir: tmp_dir} do
      %{watcher: watcher, course_dir: course_dir, rebuilder: rebuilder} = start_watcher!(tmp_dir)

      send(watcher, file_event(Path.join(course_dir, "chapters/507-dns/subject.md")))

      assert_receive {:proxy, ^rebuilder, {:cast, :request}}
    end

    test "asks for nothing when it is not", %{tmp_dir: tmp_dir} do
      %{watcher: watcher, course_dir: course_dir, rebuilder: rebuilder} = start_watcher!(tmp_dir)

      send(
        watcher,
        file_event(Path.join(course_dir, "node_modules/reveal.js/dist/reveal.js"))
      )

      refute_receive {:proxy, ^rebuilder, _message}
    end

    test "asks once per change, the coalescing being the rebuilder's", %{tmp_dir: tmp_dir} do
      %{watcher: watcher, course_dir: course_dir, rebuilder: rebuilder} = start_watcher!(tmp_dir)

      send(watcher, file_event(Path.join(course_dir, "chapters/507-dns/subject.md")))
      send(watcher, file_event(Path.join(course_dir, "chapters/508-tls/subject.md")))

      assert_receive {:proxy, ^rebuilder, {:cast, :request}}
      assert_receive {:proxy, ^rebuilder, {:cast, :request}}
      refute_receive {:proxy, ^rebuilder, _message}
    end
  end

  defp start_watcher!(tmp_dir) do
    course_dir = Path.join(tmp_dir, "course")
    File.mkdir_p!(course_dir)

    # A name of its own per test, so that concurrent tests do not stand in for
    # each other's rebuilder. A globally registered reference rather than an
    # atom, so that a suite that runs many tests does not mint an atom per test.
    rebuilder = {:global, make_ref()}

    start_supervised!(%{
      id: :rebuilder,
      start: {GenServerProxy, :start_link, [self(), rebuilder]}
    })

    watcher =
      start_supervised!(
        {CourseSiteWatcher, name: nil, course_dir: course_dir, rebuilder: rebuilder}
      )

    %{watcher: watcher, course_dir: course_dir, rebuilder: rebuilder}
  end

  defp file_event(path), do: {:file_event, self(), {path, [:modified]}}
end
