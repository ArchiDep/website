defmodule Mix.Tasks.Archidep.CourseSite.StructureTest do
  # `Mix.shell/0` is global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers

  alias Mix.Tasks.Archidep.CourseSite.Structure

  @moduletag :tmp_dir

  setup :capture_mix_shell

  describe "run/1" do
    test "describes every section, chapter and cheatsheet of the course it read",
         %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "content")
      declarations_file = Path.join(tmp_dir, "declarations.yml")

      write!(
        content_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\nType.\n"
      )

      write!(
        content_dir,
        "chapters/101-command-line/slides.md",
        "---\ntitle: Command Line Slides\n---\n\nType.\n"
      )

      write!(
        content_dir,
        "chapters/102-shell-scripting/slides.md",
        "---\ntitle: Shell Scripting\n---\n\nScript.\n"
      )

      write!(
        content_dir,
        "chapters/205-php-todolist/exercise.md",
        "---\ntitle: PHP Todolist\ngraded: true\n---\n\nBuild it.\n"
      )

      write!(
        content_dir,
        "cheatsheets/git/cheatsheet.md",
        "---\ntitle: Git Cheatsheet\nsidebar_title: Git\n---\n\nCommit.\n"
      )

      File.write!(
        declarations_file,
        "---\nsections:\n  - title: Introduction\n  - title: Version Control\ncheatsheets:\n  - git\n"
      )

      Structure.run(["--content", content_dir, "--declarations", declarations_file])

      assert shell_output() == [
               {:info, "Read 5 pages from #{content_dir}"},
               {:info, "100 Introduction (introduction, 2 chapters)"},
               {:info, "  101 Command Line (command-line, subject, slides)"},
               {:info, "  102 Shell Scripting (shell-scripting, slides)"},
               {:info, "200 Version Control (version-control, 1 chapters)"},
               {:info, "  205 PHP Todolist (php-todolist, exercise, graded)"},
               {:info, "Cheatsheets"},
               {:info, "  Git Cheatsheet (git, listed as Git)"},
               {:info,
                "2 sections, 3 chapters (1 with slides beside their page, 1 that are slides) and 1 cheatsheets"}
             ]
    end

    test "reports a file it cannot place rather than publishing a blank page",
         %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "content")
      declarations_file = Path.join(tmp_dir, "declarations.yml")

      write!(content_dir, "chapters/301-security/notes.md", "# Notes")
      File.write!(declarations_file, "---\nsections: []\ncheatsheets: []\n")

      assert catch_exit(
               Structure.run(["--content", content_dir, "--declarations", declarations_file])
             ) == {:shutdown, 1}

      assert shell_output() == [
               {:error, "The content directory could not be read:"},
               {:error,
                ~s(  Source file "chapters/301-security/notes.md" is neither a document nor a file of a page)}
             ]
    end

    test "reports declarations it cannot read", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "content")
      declarations_file = Path.join(tmp_dir, "declarations.yml")

      write!(content_dir, "chapters/401-cloud/subject.md", "---\ntitle: Cloud\n---\n\nRent.\n")

      assert catch_exit(
               Structure.run(["--content", content_dir, "--declarations", declarations_file])
             ) == {:shutdown, 1}

      assert shell_output() == [
               {:info, "Read 1 pages from #{content_dir}"},
               {:error, "The course declarations could not be read:"},
               {:error, ~s(  Course declarations "#{declarations_file}" do not exist)}
             ]
    end

    test "reports a chapter in a section nobody declared", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "content")
      declarations_file = Path.join(tmp_dir, "declarations.yml")

      write!(content_dir, "chapters/501-deploy/subject.md", "---\ntitle: Deploy\n---\n\nShip.\n")
      File.write!(declarations_file, "---\nsections:\n  - title: Introduction\ncheatsheets: []\n")

      assert catch_exit(
               Structure.run(["--content", content_dir, "--declarations", declarations_file])
             ) == {:shutdown, 1}

      assert shell_output() == [
               {:info, "Read 1 pages from #{content_dir}"},
               {:error, "2 problems with what the course says it is:"},
               {:error, "  Chapter \"501-deploy\" is in section 5, which is not declared"},
               {:error, "  Section 1 (\"Introduction\") has no chapters"}
             ]
    end
  end

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
