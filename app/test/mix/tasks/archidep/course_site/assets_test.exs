defmodule Mix.Tasks.Archidep.CourseSite.AssetsTest do
  # `Mix.shell/0` is global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers

  alias Mix.Tasks.Archidep.CourseSite.Assets

  @moduletag :tmp_dir

  setup :capture_mix_shell

  describe "run/1" do
    test "says what it read and that every reference resolves", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      write!(
        dirs.content_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\n![CLI](images/cli.jpg)\n"
      )

      write!(dirs.content_dir, "chapters/101-command-line/images/cli.jpg", "a picture")

      Assets.run(args(dirs))

      assert shell_output() == [
               {:info,
                "Read 1 documents, 0 cheatsheets and 1 files next to a page from #{dirs.content_dir}"},
               {:info, "Digested 1 files next to a page"},
               {:info,
                "Read 1 undigested assets from #{dirs.static_dir}, which was never digested"},
               {:info, "Parsed 1 partials from #{dirs.includes_dir}"},
               {:info,
                "Read 1 sessions from #{dirs.progress_file}; 2 sections and chapters are done"},
               {:info, "Withheld the answers of 0 documents the course has not covered yet"},
               {:info, "Rendered 1 documents; every reference resolves"}
             ]
    end

    test "reads the names the assets were digested under when they have been",
         %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      write!(
        dirs.content_dir,
        "chapters/102-shell-scripting/subject.md",
        "---\ntitle: Shell Scripting\n---\n\nScript.\n"
      )

      write!(
        dirs.static_dir,
        "cache_manifest.json",
        ~s({"version":1,"latest":{"assets/theme/theme.css":"assets/theme/theme-abc123.css"},"digests":{}})
      )

      Assets.run(args(dirs))

      assert shell_output() == [
               {:info,
                "Read 1 documents, 0 cheatsheets and 0 files next to a page from #{dirs.content_dir}"},
               {:info, "Digested 0 files next to a page"},
               {:info, "Read 1 digested assets from #{dirs.static_dir}"},
               {:info, "Parsed 1 partials from #{dirs.includes_dir}"},
               {:info,
                "Read 1 sessions from #{dirs.progress_file}; 2 sections and chapters are done"},
               {:info, "Withheld the answers of 1 documents the course has not covered yet"},
               {:info, "Rendered 1 documents; every reference resolves"}
             ]
    end

    test "fails on a reference to a file that is not next to the page", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)

      write!(
        dirs.content_dir,
        "chapters/103-hello-shell/exercise.md",
        "---\ntitle: Hello Shell\n---\n\n![Gone](images/gone.jpg)\n"
      )

      assert catch_exit(Assets.run(args(dirs))) == {:shutdown, 1}

      assert shell_output() == [
               {:info,
                "Read 1 documents, 0 cheatsheets and 0 files next to a page from #{dirs.content_dir}"},
               {:info, "Digested 0 files next to a page"},
               {:info,
                "Read 1 undigested assets from #{dirs.static_dir}, which was never digested"},
               {:info, "Parsed 1 partials from #{dirs.includes_dir}"},
               {:info,
                "Read 1 sessions from #{dirs.progress_file}; 2 sections and chapters are done"},
               {:info, "Withheld the answers of 1 documents the course has not covered yet"},
               {:error, "1 references could not be resolved:"},
               {:error,
                "  chapters/103-hello-shell/exercise.md: Page asset \"images/gone.jpg\" of page 103-hello-shell (exercise) is not in the page asset manifest (looked for \"/course/103-hello-shell/images/gone.jpg\") in chapters/103-hello-shell/exercise.md"}
             ]
    end

    test "reports what the course cannot read at all", %{tmp_dir: tmp_dir} do
      dirs = course!(tmp_dir)
      write!(dirs.content_dir, "chapters/104-ssh/notes.md", "# Notes")

      assert catch_exit(Assets.run(args(dirs))) == {:shutdown, 1}

      assert shell_output() == [
               {:error, "The content directory could not be read:"},
               {:error,
                ~s(  Source file "chapters/104-ssh/notes.md" is neither a document nor a file of a page)}
             ]
    end
  end

  # The inputs the task needs beyond the pages a test writes for itself: an
  # includes directory holding the icon every note draws, somewhere to read the
  # global assets from, and a progress file.
  defp course!(tmp_dir) do
    dirs = %{
      content_dir: Path.join(tmp_dir, "content"),
      includes_dir: Path.join(tmp_dir, "includes"),
      static_dir: Path.join(tmp_dir, "static"),
      progress_file: Path.join(tmp_dir, "progress.json")
    }

    write!(dirs.includes_dir, "icons/note.html", "<svg></svg>")
    write!(dirs.static_dir, "assets/theme/theme.css", "body {}")

    File.write!(
      dirs.progress_file,
      ~s({"sessions":[{"date":"1999-02-02","title":"CLI","done":[100,101],"due":[],"next":[]}]})
    )

    dirs
  end

  defp args(dirs),
    do: [
      "--content",
      dirs.content_dir,
      "--includes",
      dirs.includes_dir,
      "--static",
      dirs.static_dir,
      "--progress",
      dirs.progress_file
    ]

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
