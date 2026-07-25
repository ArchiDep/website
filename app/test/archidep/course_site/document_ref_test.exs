defmodule ArchiDep.CourseSite.DocumentRefTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef

  doctest ArchiDep.CourseSite.DocumentRef

  describe "new/3" do
    test "builds a document reference" do
      assert DocumentRef.new(513, "docker-compose", :subject) ==
               %DocumentRef{num: 513, slug: "docker-compose", type: :subject}
    end
  end

  describe "parse_source_path/1" do
    test "parses a subject" do
      assert DocumentRef.parse_source_path("_course/104-ssh/subject.md") ==
               {:ok, %DocumentRef{num: 104, slug: "ssh", type: :subject}}
    end

    test "parses an exercise" do
      assert DocumentRef.parse_source_path("_course/205-php-todolist/exercise.md") ==
               {:ok, %DocumentRef{num: 205, slug: "php-todolist", type: :exercise}}
    end

    test "parses slides at the root of a chapter" do
      assert DocumentRef.parse_source_path("_course/401-cloud-computing/slides.md") ==
               {:ok, %DocumentRef{num: 401, slug: "cloud-computing", type: :slides}}
    end

    test "parses slides in a subdirectory as the same kind of document" do
      assert DocumentRef.parse_source_path("_course/202-git-branching/slides/slides.md") ==
               {:ok, %DocumentRef{num: 202, slug: "git-branching", type: :slides}}
    end

    test "rejects an unknown document type" do
      assert DocumentRef.parse_source_path("_course/301-nginx/README.md") ==
               {:error, {:invalid_source_path, "_course/301-nginx/README.md"}}
    end

    test "rejects a chapter number outside a section" do
      assert DocumentRef.parse_source_path("_course/042-history/subject.md") ==
               {:error, {:invalid_source_path, "_course/042-history/subject.md"}}
    end

    test "rejects a cheatsheet" do
      assert DocumentRef.parse_source_path("_cheatsheets/git/cheatsheet.md") ==
               {:error, {:invalid_source_path, "_cheatsheets/git/cheatsheet.md"}}
    end

    test "rejects slides nested deeper than one directory" do
      assert DocumentRef.parse_source_path("_course/601-ci/slides/parts/slides.md") ==
               {:error, {:invalid_source_path, "_course/601-ci/slides/parts/slides.md"}}
    end
  end
end
