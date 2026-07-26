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
               "_course/401-cloud-computing/subject.md",
               "_course/401-cloud-computing/slides.md",
               "_course/401-cloud-computing/images/cloud.png"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(401, "cloud-computing", :subject) =>
                      "_course/401-cloud-computing/subject.md",
                    DocumentRef.new(401, "cloud-computing", :slides) =>
                      "_course/401-cloud-computing/slides.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{
                    "/course/401-cloud-computing/images/cloud.png" =>
                      "_course/401-cloud-computing/images/cloud.png"
                  },
                  ignored: []
                }}
    end

    test "sorts a chapter whose deck is written in a directory of its own" do
      assert ContentTree.plan([
               "_course/104-ssh/subject.md",
               "_course/104-ssh/slides/slides.md",
               "_course/104-ssh/slides/images/hash.png"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(104, "ssh", :subject) => "_course/104-ssh/subject.md",
                    DocumentRef.new(104, "ssh", :slides) => "_course/104-ssh/slides/slides.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{
                    "/course/104-ssh/slides/images/hash.png" =>
                      "_course/104-ssh/slides/images/hash.png"
                  },
                  ignored: []
                }}
    end

    test "sorts a chapter that is an exercise with a file of any type next to it" do
      assert ContentTree.plan([
               "_course/205-php-todolist/exercise.md",
               "_course/205-php-todolist/images/architecture.pdf"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(205, "php-todolist", :exercise) =>
                      "_course/205-php-todolist/exercise.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{
                    "/course/205-php-todolist/images/architecture.pdf" =>
                      "_course/205-php-todolist/images/architecture.pdf"
                  },
                  ignored: []
                }}
    end

    test "sorts a cheatsheet" do
      assert ContentTree.plan([
               "_cheatsheets/sysadmin/cheatsheet.md",
               "_cheatsheets/sysadmin/images/htop.png"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{},
                  cheatsheets: %{"sysadmin" => "_cheatsheets/sysadmin/cheatsheet.md"},
                  page_assets: %{
                    "/cheatsheets/sysadmin/images/htop.png" =>
                      "_cheatsheets/sysadmin/images/htop.png"
                  },
                  ignored: []
                }}
    end

    test "records the litter it skips rather than dropping it" do
      assert ContentTree.plan([
               "_course/.DS_Store",
               "_course/803-docker-isolation/images/.DS_Store",
               "_course/803-docker-isolation/subject.md"
             ]) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(803, "docker-isolation", :subject) =>
                      "_course/803-docker-isolation/subject.md"
                  },
                  cheatsheets: %{},
                  page_assets: %{},
                  ignored: [
                    "_course/.DS_Store",
                    "_course/803-docker-isolation/images/.DS_Store"
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
               "_course/507-dns/notes.md",
               "_cheatsheets/git/notes.md"
             ]) ==
               {:error,
                [
                  {:unknown_source, "_course/507-dns/notes.md"},
                  {:unknown_source, "_cheatsheets/git/notes.md"}
                ]}
    end

    test "refuses a file that belongs to no collection" do
      assert ContentTree.plan(["_notices/banner.png", "_course/stray.png"]) ==
               {:error,
                [
                  {:unknown_source, "_notices/banner.png"},
                  {:unknown_source, "_course/stray.png"}
                ]}
    end

    test "refuses a file whose name would have to be percent-encoded" do
      assert ContentTree.plan(["_course/509-reverse-proxy/images/open proxy.png"]) ==
               {:error,
                [
                  {:unsafe_name, "_course/509-reverse-proxy/images/open proxy.png",
                   "open proxy.png"}
                ]}
    end

    test "refuses a file inside a directory whose name would have to be percent-encoded" do
      assert ContentTree.plan(["_course/408-unix-networking/mes images/dns.png"]) ==
               {:error,
                [
                  {:unsafe_name, "_course/408-unix-networking/mes images/dns.png", "mes images"}
                ]}
    end

    test "refuses to be handed one file twice, which would publish one path from two" do
      assert ContentTree.plan([
               "_cheatsheets/docker/images/ps.png",
               "_cheatsheets/docker/images/ps.png"
             ]) ==
               {:error,
                [
                  {:duplicate_output_path, "/cheatsheets/docker/images/ps.png",
                   ["_cheatsheets/docker/images/ps.png", "_cheatsheets/docker/images/ps.png"]}
                ]}
    end

    test "reports every offending file rather than the first" do
      assert ContentTree.plan([
               "_course/301-security/notes.md",
               "_course/301-security/images/a b.png",
               "_course/301-security/subject.md"
             ]) ==
               {:error,
                [
                  {:unknown_source, "_course/301-security/notes.md"},
                  {:unsafe_name, "_course/301-security/images/a b.png", "a b.png"}
                ]}
    end
  end

  describe "format_error/1" do
    test "describes a file that is neither a document nor a file of a page" do
      assert ContentTree.format_error({:unknown_source, "_course/601-deployment/notes.md"}) ==
               ~s{Source file "_course/601-deployment/notes.md" is neither a document nor a file of a page}
    end

    test "describes a file whose published name would have to be percent-encoded" do
      assert ContentTree.format_error(
               {:unsafe_name, "_course/602-hello/images/a b.png", "a b.png"}
             ) ==
               ~s{Source file "_course/602-hello/images/a b.png" is published under a path whose segment "a b.png" is not made of letters, digits, dots, underscores and dashes}
    end

    test "describes two files publishing one path" do
      assert ContentTree.format_error(
               {:duplicate_output_path, "/course/603-floodit/images/x.png",
                ["_course/603-floodit/images/x.png", "_course/603-floodit/images/x.PNG"]}
             ) ==
               ~s{Output path "/course/603-floodit/images/x.png" is written by "_course/603-floodit/images/x.png" and "_course/603-floodit/images/x.PNG"}
    end
  end

  describe "where a file is published" do
    test "a file is published where the page next to it refers to it" do
      # The claim the whole build rests on: a reference resolves against the
      # page's *output* directory, and a deck written at a chapter's root is
      # published one segment deeper than it is written while its images are
      # not.
      references = [
        {"_course/401-cloud-computing/images/cloud.png",
         {:document, DocumentRef.new(401, "cloud-computing", :slides)}, "../images/cloud.png"},
        {"_course/401-cloud-computing/images/cloud.png",
         {:document, DocumentRef.new(401, "cloud-computing", :subject)}, "images/cloud.png"},
        {"_course/104-ssh/slides/images/hash.png",
         {:document, DocumentRef.new(104, "ssh", :slides)}, "images/hash.png"},
        {"_course/104-ssh/images/ssh.png", {:document, DocumentRef.new(104, "ssh", :subject)},
         "./images/ssh.png"},
        {"_course/205-php-todolist/images/architecture.pdf",
         {:document, DocumentRef.new(205, "php-todolist", :exercise)},
         "./images/architecture.pdf"},
        {"_cheatsheets/sysadmin/images/htop.png", {:cheatsheet, "sysadmin"}, "images/htop.png"}
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
