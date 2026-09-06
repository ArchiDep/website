defmodule Mix.Tasks.Archidep.CourseSite.BuildTest do
  # `Mix.shell/0` and the application environment are global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers
  import Hammox

  alias Mix.Tasks.Archidep.CourseSite.Build

  @moduletag :tmp_dir

  setup :verify_on_exit!

  # The files a build publishes at its mount point, which the course fixture
  # below writes with their own path as their content.
  @root_files [
    "favicon.ico",
    "favicons/archidep-512-flat.png",
    "favicons/archidep-coffee.png",
    "favicons/archidep-rocket-16.png",
    "favicons/archidep-rocket-180.png",
    "favicons/archidep-rocket-192.png",
    "favicons/archidep-rocket-32.png",
    "favicons/archidep-rocket-48.png",
    "favicons/archidep-rocket-96.png",
    "favicons/heig.png"
  ]

  setup :capture_mix_shell

  describe "run/1" do
    test "renders the course it is pointed at and says what it wrote", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      Build.run(args(dirs))

      assert shell_output() == [
               {:info,
                "Rendered 2 pages and 1 chapters into 17 files, beside 1 files next to a page and 1 global assets"},
               {:info, "Wrote #{dirs.output_dir}, and every link of it resolves"}
             ]

      assert File.regular?(Path.join(dirs.output_dir, "index.html")) == true
    end

    # A build owns its output directory, so what is already there is a mistake
    # rather than something to write over.
    test "refuses an output directory that is not empty", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)
      write!(dirs.output_dir, "leftover.html", "from a previous build")

      assert catch_exit(Build.run(args(dirs))) == {:shutdown, 1}

      assert shell_output() == [
               {:error, "The output directory could not be made ready:"},
               {:error,
                "  Output directory \"#{dirs.output_dir}\" is not empty; a build owns its output and must start from nothing, but it holds: leftover.html"}
             ]

      assert File.read!(Path.join(dirs.output_dir, "leftover.html")) == "from a previous build"
    end

    test "empties the output directory first when told to", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)
      write!(dirs.output_dir, "leftover.html", "from a previous build")

      Build.run(args(dirs) ++ ["--clean"])

      assert shell_output() == [
               {:info,
                "Rendered 2 pages and 1 chapters into 17 files, beside 1 files next to a page and 1 global assets"},
               {:info, "Wrote #{dirs.output_dir}, and every link of it resolves"}
             ]

      assert File.exists?(Path.join(dirs.output_dir, "leftover.html")) == false
      assert File.regular?(Path.join(dirs.output_dir, "index.html")) == true
    end

    test "refuses a mode no build is published in", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      assert_raise Mix.Error, ~s(Mode must be live, backup or archive, got: "sideways"), fn ->
        Build.run(args(dirs) ++ ["--mode", "sideways"])
      end

      assert shell_output() == []
      assert File.exists?(dirs.output_dir) == false
    end

    test "reports progress through the course it cannot read", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)
      missing = Path.join(tmp_dir, "nowhere.json")

      assert_raise Mix.Error,
                   """
                   The progress through the course could not be read from #{missing}:
                     The progress file #{missing} does not exist\
                   """,
                   fn -> Build.run(args(dirs, progress_file: missing)) end

      assert shell_output() == []
      assert File.exists?(dirs.output_dir) == false
    end

    test "reads progress through the course from a running deployment", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      expect(ArchiDep.Http.Mock, :get, fn url, opts ->
        assert url == "https://archidep.example.com/api/progress"
        assert opts == []

        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "sessions" => [
               %{"date" => "1994-02-02", "title" => "CLI", "done" => [100, 101]}
             ]
           }
         }}
      end)

      Build.run(
        args(dirs, progress_file: nil) ++
          ["--progress", "https://archidep.example.com/api/progress"]
      )

      assert shell_output() == [
               {:info,
                "Rendered 2 pages and 1 chapters into 17 files, beside 1 files next to a page and 1 global assets"},
               {:info, "Wrote #{dirs.output_dir}, and every link of it resolves"}
             ]
    end

    test "reports a deployment that would not say how far the course has got", %{
      tmp_dir: tmp_dir
    } do
      dirs = course!(tmp_dir)

      expect(ArchiDep.Http.Mock, :get, fn _url, _opts ->
        {:ok, %Req.Response{status: 502, body: "nope"}}
      end)

      assert_raise Mix.Error,
                   """
                   The progress through the course could not be read from https://archidep.example.com/api/progress:
                     the server answered 502\
                   """,
                   fn ->
                     Build.run(
                       args(dirs, progress_file: nil) ++
                         ["--progress", "https://archidep.example.com/api/progress"]
                     )
                   end

      assert File.exists?(dirs.output_dir) == false
    end

    # An edition that is over has covered everything by definition, so it is the
    # one build that needs no source at all — and the only one allowed to say
    # so.
    test "takes an archived edition to be complete without being told", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      Build.run(args(dirs, progress_file: nil) ++ archive_args())

      # One file fewer than the builds above: an archive keeps its home page
      # under the edition prefix rather than also at the mount point.
      assert shell_output() == [
               {:info,
                "Rendered 2 pages and 1 chapters into 16 files, beside 1 files next to a page and 1 global assets"},
               {:info, "Wrote #{dirs.output_dir}, and every link of it resolves"}
             ]
    end

    test "takes an archived edition to be complete when told so", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      Build.run(args(dirs, progress_file: nil) ++ archive_args() ++ ["--progress", "complete"])

      assert shell_output() == [
               {:info,
                "Rendered 2 pages and 1 chapters into 16 files, beside 1 files next to a page and 1 global assets"},
               {:info, "Wrote #{dirs.output_dir}, and every link of it resolves"}
             ]
    end

    test "refuses to take the edition being taught to be complete", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      assert_raise Mix.Error, ~r/^Only an archived edition is complete/, fn ->
        Build.run(args(dirs, progress_file: nil) ++ ["--progress", "complete"])
      end

      assert File.exists?(dirs.output_dir) == false
    end

    test "refuses to guess how far the course has got", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      assert_raise Mix.Error, ~r/^This build needs to be told how far the course has got/, fn ->
        Build.run(args(dirs, progress_file: nil))
      end

      assert File.exists?(dirs.output_dir) == false
    end
  end

  defp archive_args,
    do: ["--mode", "archive", "--version", "1994", "--live-site-url", "https://archidep.ch"]

  # The smallest course this task can be run over: the home page, one chapter
  # with a picture beside it, what the course declares itself with, the files
  # anchored at the mount point and one global asset.
  defp course!(tmp_dir) do
    dirs = %{
      course_dir: Path.join(tmp_dir, "course"),
      static_dir: Path.join(tmp_dir, "static"),
      progress_file: Path.join(tmp_dir, "progress.json"),
      output_dir: Path.join(tmp_dir, "build")
    }

    Enum.each(@root_files, &write!(dirs.course_dir, &1, &1))

    write!(
      dirs.course_dir,
      "index.md",
      "---\ntitle: Architecture & Deployment\n---\n\nWelcome.\n"
    )

    write!(
      dirs.course_dir,
      "chapters/101-command-line/subject.md",
      "---\ntitle: Command Line\n---\n\n![CLI](images/cli.jpg)\n"
    )

    write!(dirs.course_dir, "chapters/101-command-line/images/cli.jpg", "a picture")

    write!(
      dirs.course_dir,
      "course.yml",
      "---\nsections:\n  - title: Introduction\ncheatsheets: []\n"
    )

    File.mkdir_p!(Path.join(dirs.course_dir, "icons"))
    write!(dirs.static_dir, "assets/theme/theme.css", "body {}")

    File.write!(
      dirs.progress_file,
      ~s({"sessions":[{"date":"1994-02-02","title":"CLI","done":[100,101],"due":[],"next":[]}]})
    )

    put_course_site_config(
      version: "1994",
      years: "1994-1995",
      years_short: "94-95",
      build_id: "test-build"
    )

    dirs
  end

  defp args(dirs, overrides \\ []) do
    progress_file = Keyword.get(overrides, :progress_file, dirs.progress_file)

    [
      "--course",
      dirs.course_dir,
      "--static",
      dirs.static_dir,
      "--output",
      dirs.output_dir,
      "--minimal",
      "--undigested",
      "--no-source-maps"
    ] ++ if(progress_file, do: ["--progress", progress_file], else: [])
  end

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
