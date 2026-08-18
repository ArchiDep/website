defmodule Mix.Tasks.Archidep.CourseSite.BuildTest do
  # `Mix.shell/0` and the application environment are global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers

  alias Mix.Tasks.Archidep.CourseSite.Build

  @moduletag :tmp_dir

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

      assert catch_exit(Build.run(args(dirs, progress_file: missing))) == {:shutdown, 1}

      assert shell_output() == [
               {:error, "The progress through the course could not be read:"},
               {:error, "  The progress file #{missing} does not exist"}
             ]

      assert File.exists?(dirs.output_dir) == false
    end
  end

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
      ~s({"sessions":[{"date":"2031-02-02","title":"CLI","done":[100,101],"due":[],"next":[]}]})
    )

    put_course_site_config(
      version: "2031",
      years: "2031-2032",
      years_short: "31-32",
      build_id: "test-build"
    )

    dirs
  end

  defp args(dirs, overrides \\ []),
    do: [
      "--course",
      dirs.course_dir,
      "--static",
      dirs.static_dir,
      "--progress",
      Keyword.get(overrides, :progress_file, dirs.progress_file),
      "--output",
      dirs.output_dir,
      "--minimal",
      "--undigested",
      "--no-source-maps"
    ]

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
