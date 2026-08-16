defmodule ArchiDep.CourseSite.Build.ContentTreeTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Urls.UrlPath

  doctest ArchiDep.CourseSite.Build.ContentTree

  describe "plan/1" do
    test "sorts a chapter whose deck is written at its root" do
      assert ContentTree.plan([
               "chapters/401-cloud-computing/subject.md",
               "chapters/401-cloud-computing/slides.md",
               "chapters/401-cloud-computing/images/cloud.png"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(401, "cloud-computing", :subject) =>
                      "chapters/401-cloud-computing/subject.md",
                    DocumentRef.new(401, "cloud-computing", :slides) =>
                      "chapters/401-cloud-computing/slides.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{
                    "/course/401-cloud-computing/images/cloud.png" =>
                      "chapters/401-cloud-computing/images/cloud.png"
                  },
                  ignored: []
                }}
    end

    test "sorts a chapter whose deck is written in a directory of its own" do
      assert ContentTree.plan([
               "chapters/104-ssh/subject.md",
               "chapters/104-ssh/slides/slides.md",
               "chapters/104-ssh/slides/images/hash.png"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(104, "ssh", :subject) => "chapters/104-ssh/subject.md",
                    DocumentRef.new(104, "ssh", :slides) => "chapters/104-ssh/slides/slides.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{
                    "/course/104-ssh/slides/images/hash.png" =>
                      "chapters/104-ssh/slides/images/hash.png"
                  },
                  ignored: []
                }}
    end

    test "sorts a chapter that is an exercise with a file of any type next to it" do
      assert ContentTree.plan([
               "chapters/205-php-todolist/exercise.md",
               "chapters/205-php-todolist/images/architecture.pdf"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(205, "php-todolist", :exercise) =>
                      "chapters/205-php-todolist/exercise.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{
                    "/course/205-php-todolist/images/architecture.pdf" =>
                      "chapters/205-php-todolist/images/architecture.pdf"
                  },
                  ignored: []
                }}
    end

    test "sorts a cheatsheet" do
      assert ContentTree.plan([
               "cheatsheets/sysadmin/cheatsheet.md",
               "cheatsheets/sysadmin/images/htop.png"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{},
                  cheatsheets: %{"sysadmin" => "cheatsheets/sysadmin/cheatsheet.md"},
                  page_assets: %{
                    "/cheatsheets/sysadmin/images/htop.png" =>
                      "cheatsheets/sysadmin/images/htop.png"
                  },
                  ignored: []
                }}
    end

    test "records the litter it skips rather than dropping it" do
      assert ContentTree.plan([
               "chapters/.DS_Store",
               "chapters/803-docker-isolation/images/.DS_Store",
               "chapters/803-docker-isolation/subject.md"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(803, "docker-isolation", :subject) =>
                      "chapters/803-docker-isolation/subject.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{},
                  ignored: [
                    "chapters/.DS_Store",
                    "chapters/803-docker-isolation/images/.DS_Store"
                  ]
                }}
    end

    test "sorts nothing at all" do
      assert ContentTree.plan([]) ==
               {:ok,
                %ContentTree{documents: %{}, cheatsheets: %{}, page_assets: %{}, ignored: []}}
    end

    test "refuses a Markdown file the content layout does not recognise" do
      assert ContentTree.plan([
               "chapters/507-dns/notes.md",
               "cheatsheets/git/notes.md"
             ]) ==
               {:error,
                [
                  {:unknown_source, "chapters/507-dns/notes.md"},
                  {:unknown_source, "cheatsheets/git/notes.md"}
                ]}
    end

    test "refuses a file that belongs to no collection" do
      assert ContentTree.plan(["_notices/banner.png", "chapters/stray.png"]) ==
               {:error,
                [
                  {:unknown_source, "_notices/banner.png"},
                  {:unknown_source, "chapters/stray.png"}
                ]}
    end

    test "refuses a file whose name would have to be percent-encoded" do
      assert ContentTree.plan(["chapters/509-reverse-proxy/images/open proxy.png"]) ==
               {:error,
                [
                  {:unsafe_name, "chapters/509-reverse-proxy/images/open proxy.png",
                   "open proxy.png"}
                ]}
    end

    test "refuses a file inside a directory whose name would have to be percent-encoded" do
      assert ContentTree.plan(["chapters/408-unix-networking/mes images/dns.png"]) ==
               {:error,
                [
                  {:unsafe_name, "chapters/408-unix-networking/mes images/dns.png", "mes images"}
                ]}
    end

    test "refuses to be handed one file twice, which would publish one path from two" do
      assert ContentTree.plan([
               "cheatsheets/docker/images/ps.png",
               "cheatsheets/docker/images/ps.png"
             ]) ==
               {:error,
                [
                  {:duplicate_output_path, "/cheatsheets/docker/images/ps.png",
                   ["cheatsheets/docker/images/ps.png", "cheatsheets/docker/images/ps.png"]}
                ]}
    end

    test "refuses a chapter writing its deck in both source layouts" do
      assert ContentTree.plan([
               "chapters/104-ssh/subject.md",
               "chapters/104-ssh/slides.md",
               "chapters/104-ssh/slides/slides.md"
             ]) ==
               {:error,
                [
                  {:duplicate_document, "104-ssh", :slides,
                   ["chapters/104-ssh/slides.md", "chapters/104-ssh/slides/slides.md"]}
                ]}
    end

    test "refuses two chapter directories sharing a number" do
      assert ContentTree.plan([
               "chapters/401-cloud-computing/subject.md",
               "chapters/401-flying-cows/exercise.md"
             ]) ==
               {:error,
                [
                  {:duplicate_chapter_number, 401, ["401-cloud-computing", "401-flying-cows"]}
                ]}
    end

    test "reads the documents of one chapter as one chapter" do
      assert ContentTree.plan([
               "chapters/104-ssh/subject.md",
               "chapters/104-ssh/slides.md"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(104, "ssh", :subject) => "chapters/104-ssh/subject.md",
                    DocumentRef.new(104, "ssh", :slides) => "chapters/104-ssh/slides.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{},
                  ignored: []
                }}
    end

    test "refuses a chapter that has both a subject and an exercise" do
      assert ContentTree.plan([
               "chapters/402-run-virtual-server/subject.md",
               "chapters/402-run-virtual-server/exercise.md",
               "chapters/402-run-virtual-server/images/vm.png"
             ]) ==
               {:error,
                [
                  {:subject_and_exercise, "402-run-virtual-server",
                   [
                     "chapters/402-run-virtual-server/exercise.md",
                     "chapters/402-run-virtual-server/subject.md"
                   ]}
                ]}
    end

    test "refuses a chapter that is an exercise and has slides" do
      assert ContentTree.plan([
               "chapters/205-php-todolist/exercise.md",
               "chapters/205-php-todolist/slides.md"
             ]) ==
               {:error,
                [
                  {:exercise_with_slides, "205-php-todolist",
                   [
                     "chapters/205-php-todolist/exercise.md",
                     "chapters/205-php-todolist/slides.md"
                   ]}
                ]}
    end

    test "refuses a chapter that is an exercise and has slides in a directory of their own" do
      assert ContentTree.plan([
               "chapters/205-php-todolist/exercise.md",
               "chapters/205-php-todolist/slides/slides.md"
             ]) ==
               {:error,
                [
                  {:exercise_with_slides, "205-php-todolist",
                   [
                     "chapters/205-php-todolist/exercise.md",
                     "chapters/205-php-todolist/slides/slides.md"
                   ]}
                ]}
    end

    test "tells a chapter breaking both rules about both" do
      assert ContentTree.plan([
               "chapters/205-php-todolist/subject.md",
               "chapters/205-php-todolist/exercise.md",
               "chapters/205-php-todolist/slides.md"
             ]) ==
               {:error,
                [
                  {:subject_and_exercise, "205-php-todolist",
                   [
                     "chapters/205-php-todolist/exercise.md",
                     "chapters/205-php-todolist/subject.md"
                   ]},
                  {:exercise_with_slides, "205-php-todolist",
                   [
                     "chapters/205-php-todolist/exercise.md",
                     "chapters/205-php-todolist/slides.md"
                   ]}
                ]}
    end

    test "accepts a chapter that is a subject with slides, and one that is slides alone" do
      assert ContentTree.plan([
               "chapters/401-cloud-computing/subject.md",
               "chapters/401-cloud-computing/slides.md",
               "chapters/403-sysadmin/slides.md",
               "chapters/205-php-todolist/exercise.md"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(401, "cloud-computing", :subject) =>
                      "chapters/401-cloud-computing/subject.md",
                    DocumentRef.new(401, "cloud-computing", :slides) =>
                      "chapters/401-cloud-computing/slides.md",
                    DocumentRef.new(403, "sysadmin", :slides) =>
                      "chapters/403-sysadmin/slides.md",
                    DocumentRef.new(205, "php-todolist", :exercise) =>
                      "chapters/205-php-todolist/exercise.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{},
                  ignored: []
                }}
    end

    test "reads the rules per chapter rather than across the course" do
      assert ContentTree.plan([
               "chapters/401-cloud-computing/subject.md",
               "chapters/205-php-todolist/exercise.md",
               "chapters/205-php-todolist/slides.md"
             ]) ==
               {:error,
                [
                  {:exercise_with_slides, "205-php-todolist",
                   [
                     "chapters/205-php-todolist/exercise.md",
                     "chapters/205-php-todolist/slides.md"
                   ]}
                ]}
    end

    test "reports every offending file rather than the first" do
      assert ContentTree.plan([
               "chapters/301-security/notes.md",
               "chapters/301-security/images/a b.png",
               "chapters/301-security/subject.md"
             ]) ==
               {:error,
                [
                  {:unknown_source, "chapters/301-security/notes.md"},
                  {:unsafe_name, "chapters/301-security/images/a b.png", "a b.png"}
                ]}
    end

    test "reports every offending chapter rather than the first" do
      assert ContentTree.plan([
               "chapters/205-php-todolist/exercise.md",
               "chapters/205-php-todolist/slides.md",
               "chapters/402-run-virtual-server/subject.md",
               "chapters/402-run-virtual-server/exercise.md"
             ]) ==
               {:error,
                [
                  {:exercise_with_slides, "205-php-todolist",
                   [
                     "chapters/205-php-todolist/exercise.md",
                     "chapters/205-php-todolist/slides.md"
                   ]},
                  {:subject_and_exercise, "402-run-virtual-server",
                   [
                     "chapters/402-run-virtual-server/exercise.md",
                     "chapters/402-run-virtual-server/subject.md"
                   ]}
                ]}
    end
  end

  describe "format_error/1" do
    test "describes a file that is neither a document nor a file of a page" do
      assert ContentTree.format_error({:unknown_source, "chapters/601-deployment/notes.md"}) ==
               ~s{Source file "chapters/601-deployment/notes.md" is neither a document nor a file of a page}
    end

    test "describes a file whose published name would have to be percent-encoded" do
      assert ContentTree.format_error(
               {:unsafe_name, "chapters/602-hello/images/a b.png", "a b.png"}
             ) ==
               ~s{Source file "chapters/602-hello/images/a b.png" is published under a path whose segment "a b.png" is not made of letters, digits, dots, underscores and dashes}
    end

    test "describes two files publishing one path" do
      assert ContentTree.format_error(
               {:duplicate_output_path, "/course/603-floodit/images/x.png",
                ["chapters/603-floodit/images/x.png", "chapters/603-floodit/images/x.PNG"]}
             ) ==
               ~s{Output path "/course/603-floodit/images/x.png" is written by "chapters/603-floodit/images/x.png" and "chapters/603-floodit/images/x.PNG"}
    end

    test "describes a document written twice" do
      assert ContentTree.format_error(
               {:duplicate_document, "104-ssh", :slides,
                ["chapters/104-ssh/slides.md", "chapters/104-ssh/slides/slides.md"]}
             ) ==
               ~s{Chapter "104-ssh" has more than one slides document, written by "chapters/104-ssh/slides.md" and "chapters/104-ssh/slides/slides.md"}
    end

    test "describes a chapter number used twice" do
      assert ContentTree.format_error(
               {:duplicate_chapter_number, 401, ["401-cloud-computing", "401-flying-cows"]}
             ) ==
               ~s{Chapter number 401 is used by "401-cloud-computing" and "401-flying-cows"}
    end

    test "describes a chapter that has both a subject and an exercise" do
      assert ContentTree.format_error(
               {:subject_and_exercise, "402-run-virtual-server",
                [
                  "chapters/402-run-virtual-server/exercise.md",
                  "chapters/402-run-virtual-server/subject.md"
                ]}
             ) ==
               ~s{Chapter "402-run-virtual-server" has both a subject and an exercise, written by "chapters/402-run-virtual-server/exercise.md" and "chapters/402-run-virtual-server/subject.md"}
    end

    test "describes a chapter that is an exercise and has slides" do
      assert ContentTree.format_error(
               {:exercise_with_slides, "205-php-todolist",
                ["chapters/205-php-todolist/exercise.md", "chapters/205-php-todolist/slides.md"]}
             ) ==
               ~s{Chapter "205-php-todolist" is an exercise and has slides, written by "chapters/205-php-todolist/exercise.md" and "chapters/205-php-todolist/slides.md"}
    end
  end

  describe "where a file is published" do
    test "a file is published where the page next to it refers to it" do
      # The claim the whole build rests on: a reference resolves against the
      # page's *output* directory, and a deck written at a chapter's root is
      # published one segment deeper than it is written while its images are
      # not.
      references = [
        {"chapters/401-cloud-computing/images/cloud.png",
         {:document, DocumentRef.new(401, "cloud-computing", :slides)}, "../images/cloud.png"},
        {"chapters/401-cloud-computing/images/cloud.png",
         {:document, DocumentRef.new(401, "cloud-computing", :subject)}, "images/cloud.png"},
        {"chapters/104-ssh/slides/images/hash.png",
         {:document, DocumentRef.new(104, "ssh", :slides)}, "images/hash.png"},
        {"chapters/104-ssh/images/ssh.png", {:document, DocumentRef.new(104, "ssh", :subject)},
         "./images/ssh.png"},
        {"chapters/205-php-todolist/images/architecture.pdf",
         {:document, DocumentRef.new(205, "php-todolist", :exercise)},
         "./images/architecture.pdf"},
        {"cheatsheets/sysadmin/images/htop.png", {:cheatsheet, "sysadmin"}, "images/htop.png"}
      ]

      page_assets =
        Map.new(references, fn {source_path, page, written} ->
          {:ok, output_path} =
            page |> PageRef.output_path() |> UrlPath.join(written) |> UrlPath.normalize()

          {output_path, source_path}
        end)

      assert references |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> ContentTree.plan() ==
               {:ok,
                %ContentTree{
                  documents: %{},
                  cheatsheets: %{},
                  page_assets: page_assets,
                  ignored: []
                }}
    end
  end
end
