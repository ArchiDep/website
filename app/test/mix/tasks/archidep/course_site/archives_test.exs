defmodule Mix.Tasks.Archidep.CourseSite.ArchivesTest do
  # `Mix.shell/0` and the application environment are global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers

  alias ArchiDep.CourseSite.Archives.Manifest
  alias ArchiDep.CourseSite.Build
  alias Mix.Tasks.Archidep.CourseSite.Archives

  @moduletag :tmp_dir

  setup :capture_mix_shell

  describe "run/1" do
    test "writes the manifest of the course it is pointed at, where it is told",
         %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "content")
      declarations_file = Path.join(tmp_dir, "declarations.yml")
      output_file = Path.join([tmp_dir, "somewhere", "recorded.json"])

      write!(content_dir, "chapters/104-ssh/subject.md", "---\ntitle: SSH\n---\n\nConnect.\n")
      File.write!(declarations_file, "---\nsections:\n  - title: Remote\ncheatsheets: []\n")

      put_course_site_config(version: "2031")

      Archives.run([
        "--content",
        content_dir,
        "--declarations",
        declarations_file,
        "--version",
        "2042",
        "--output",
        output_file
      ])

      assert File.read!(output_file) ==
               Manifest.to_json(
                 Manifest.of("2042", Build.course!(content_dir, declarations_file))
               )

      assert shell_output() == [
               {:info, "Recorded the 2 pages of edition 2042 in #{output_file}"}
             ]
    end

    # The edition being recorded and the file it goes in are the two things a
    # rollover must not have to remember, so both are taken from the course.
    test "records the configured edition into the archives of the course it names",
         %{tmp_dir: tmp_dir} do
      course_dir = Path.join(tmp_dir, "course")
      output_file = Path.join([course_dir, "archives", "2031.json"])

      write!(
        course_dir,
        "chapters/102-security/subject.md",
        "---\ntitle: Security\n---\n\nLock.\n"
      )

      write!(
        course_dir,
        "cheatsheets/openssl/cheatsheet.md",
        "---\ntitle: OpenSSL Cheatsheet\nsidebar_title: OpenSSL\n---\n\nSign.\n"
      )

      File.write!(
        Path.join(course_dir, "course.yml"),
        "---\nsections:\n  - title: Safety\ncheatsheets:\n  - openssl\n"
      )

      put_course_site_config(version: "2031")

      Archives.run(["--course", course_dir])

      assert File.read!(output_file) ==
               Manifest.to_json(
                 Manifest.of(
                   "2031",
                   Build.course!(course_dir, Path.join(course_dir, "course.yml"))
                 )
               )

      assert shell_output() == [
               {:info, "Recorded the 3 pages of edition 2031 in #{output_file}"}
             ]
    end

    test "records nothing when it is told no edition and none is configured",
         %{tmp_dir: tmp_dir} do
      course_dir = Path.join(tmp_dir, "course")
      write!(course_dir, "chapters/104-ssh/subject.md", "---\ntitle: SSH\n---\n\nConnect.\n")
      File.write!(Path.join(course_dir, "course.yml"), "---\nsections: []\ncheatsheets: []\n")

      put_course_site_config(years: "2031-2032")

      assert_raise Mix.Error, "No edition is configured; say which one with --version", fn ->
        Archives.run(["--course", course_dir])
      end

      assert File.exists?(Path.join(course_dir, "archives")) == false
      assert shell_output() == []
    end
  end

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
