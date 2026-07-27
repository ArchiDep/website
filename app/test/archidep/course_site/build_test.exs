defmodule ArchiDep.CourseSite.BuildTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Headings
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  @moduletag :tmp_dir

  describe "content_files/1" do
    test "lists the files a build reads, sorted, litter included", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/509-reverse-proxy/subject.md", "# Reverse proxy")
      write!(content_dir, "_course/101-command-line/subject.md", "# Command line")
      write!(content_dir, "_course/101-command-line/.DS_Store", "litter")
      write!(content_dir, "_cheatsheets/git/cheatsheet.md", "# Git")
      write!(content_dir, "_progress/2025-09-19-cli.md", "---\ndone: [101]\n---\n")
      File.mkdir_p!(Path.join(content_dir, "_course/510-empty"))

      assert Build.content_files(content_dir) == [
               "_cheatsheets/git/cheatsheet.md",
               "_course/101-command-line/.DS_Store",
               "_course/101-command-line/subject.md",
               "_course/509-reverse-proxy/subject.md"
             ]
    end

    test "lists nothing of an empty content directory", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      File.mkdir_p!(content_dir)

      assert Build.content_files(content_dir) == []
    end
  end

  describe "content_digest/1" do
    test "hashes the names of the files a build reads", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/301-security/subject.md", "# Security")
      write!(content_dir, "_course/301-security/images/lock.png", "a lock")
      write!(content_dir, "_cheatsheets/docker/cheatsheet.md", "# Docker")

      assert Build.content_digest(content_dir) ==
               :crypto.hash(
                 :sha256,
                 Enum.join(
                   [
                     "_cheatsheets/docker/cheatsheet.md",
                     "_course/301-security/images/lock.png",
                     "_course/301-security/subject.md"
                   ],
                   "\n"
                 )
               )
    end

    test "hashes a content directory differently once a file is added", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/302-cloud-computing/subject.md", "# Cloud computing")
      digest = Build.content_digest(content_dir)

      write!(content_dir, "_course/302-cloud-computing/images/cloud.png", "a cloud")

      refute Build.content_digest(content_dir) == digest
    end

    test "hashes a content directory differently once a file is removed", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/303-hashing/subject.md", "# Hashing")
      write!(content_dir, "_course/303-hashing/slides.md", "# Hashing, presented")
      digest = Build.content_digest(content_dir)

      File.rm!(Path.join(content_dir, "_course/303-hashing/slides.md"))

      refute Build.content_digest(content_dir) == digest
    end

    test "hashes a content directory the same when only what a file holds changes", %{
      tmp_dir: tmp_dir
    } do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/304-tls/subject.md", "# TLS")
      digest = Build.content_digest(content_dir)

      write!(content_dir, "_course/304-tls/subject.md", "# Transport Layer Security")

      assert Build.content_digest(content_dir) == digest
    end
  end

  describe "course!/2" do
    test "works out what the course is from a content directory", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      declarations_file = Path.join(tmp_dir, "course.yml")

      write!(
        content_dir,
        "_course/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\nType.\n"
      )

      write!(
        content_dir,
        "_course/101-command-line/slides.md",
        "---\ntitle: Command Line Slides\n---\n\nType.\n"
      )

      write!(
        content_dir,
        "_course/205-php-todolist/exercise.md",
        "---\ntitle: PHP Todolist\ngraded: true\n---\n\nBuild it.\n"
      )

      write!(
        content_dir,
        "_cheatsheets/git/cheatsheet.md",
        "---\ntitle: Git Cheatsheet\nsidebar_title: Git\n---\n\nCommit.\n"
      )

      File.write!(declarations_file, """
      ---
      sections:
        - title: Introduction
        - title: Version Control
      cheatsheets:
        - git
      """)

      assert Build.course!(content_dir, declarations_file) == %Structure{
               sections: [
                 Section.new(1, "Introduction", [
                   Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line",
                     slides: DocumentRef.new(101, "command-line", :slides)
                   )
                 ]),
                 Section.new(2, "Version Control", [
                   Chapter.new(DocumentRef.new(205, "php-todolist", :exercise), "PHP Todolist",
                     graded?: true
                   )
                 ])
               ],
               cheatsheets: [Cheatsheet.new("git", "Git Cheatsheet", "Git")]
             }
    end

    test "reports every file of the content directory it cannot place", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      declarations_file = Path.join(tmp_dir, "course.yml")

      write!(content_dir, "_course/103-ssh/notes.md", "# Notes")
      write!(content_dir, "_course/103-ssh/todo.md", "# Todo")

      assert_raise RuntimeError,
                   """
                   The content directory could not be read:
                     Source file "_course/103-ssh/notes.md" is neither a document nor a file of a page
                     Source file "_course/103-ssh/todo.md" is neither a document nor a file of a page\
                   """,
                   fn -> Build.course!(content_dir, declarations_file) end
    end

    test "reports every page of the content directory it cannot take apart", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      declarations_file = Path.join(tmp_dir, "course.yml")

      write!(content_dir, "_course/104-git/subject.md", "---\ntitle: Git\n")
      write!(content_dir, "_cheatsheets/git/cheatsheet.md", "---\ntitle: [\n---\n\nCommit.\n")

      assert_raise RuntimeError,
                   """
                   The pages of the content directory could not be read:
                     Document "_cheatsheets/git/cheatsheet.md" has invalid front matter: malformed yaml
                     Document "_course/104-git/subject.md" opens front matter it never closes\
                   """,
                   fn -> Build.course!(content_dir, declarations_file) end
    end

    test "reports declarations it cannot read", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      declarations_file = Path.join(tmp_dir, "course.yml")

      write!(content_dir, "_course/105-tls/subject.md", "---\ntitle: TLS\n---\n\nEncrypt.\n")

      assert_raise RuntimeError,
                   """
                   The course declarations could not be read:
                     Course declarations #{inspect(declarations_file)} do not exist\
                   """,
                   fn -> Build.course!(content_dir, declarations_file) end
    end

    test "reports everything that makes the content not a course", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      declarations_file = Path.join(tmp_dir, "course.yml")

      write!(content_dir, "_course/106-dns/subject.md", "---\nlayout: subject\n---\n\nName.\n")

      write!(
        content_dir,
        "_cheatsheets/docker/cheatsheet.md",
        "---\ntitle: Docker\n---\n\nRun.\n"
      )

      File.write!(declarations_file, """
      ---
      sections:
        - title: Introduction
      cheatsheets: []
      """)

      assert_raise RuntimeError,
                   """
                   What the course says it is could not be worked out:
                     Document "_course/106-dns/subject.md" has no title
                     Cheatsheet "docker" is not one of the declared cheatsheets\
                   """,
                   fn -> Build.course!(content_dir, declarations_file) end
    end
  end

  describe "include_files/1" do
    test "lists the partials a document may include, sorted", %{tmp_dir: tmp_dir} do
      includes_dir = Path.join(tmp_dir, "_includes")

      write!(includes_dir, "icons/photo.html", "<svg/>")
      write!(includes_dir, "icons/nested/gem.html", "<svg/>")
      write!(includes_dir, "icons/README.md", "Icons.")
      write!(includes_dir, "head.html", "{% seo %}")

      assert Build.include_files(includes_dir) == ["icons/nested/gem.html", "icons/photo.html"]
    end

    test "lists nothing when there is no includes directory", %{tmp_dir: tmp_dir} do
      assert Build.include_files(Path.join(tmp_dir, "_includes")) == []
    end
  end

  describe "includes/1" do
    test "parses the partials a document may include", %{tmp_dir: tmp_dir} do
      includes_dir = Path.join(tmp_dir, "_includes")

      write!(includes_dir, "icons/photo.html", ~s(<svg class="{{ include.class }}"/>))

      {:ok, expected} =
        Renderer.compile_includes(%{
          "icons/photo.html" => ~s(<svg class="{{ include.class }}"/>)
        })

      assert Build.includes(includes_dir) == {:ok, expected}
    end

    test "parses nothing when there is no includes directory", %{tmp_dir: tmp_dir} do
      assert Build.includes(Path.join(tmp_dir, "_includes")) == {:ok, %{}}
    end

    test "reports every partial it cannot parse", %{tmp_dir: tmp_dir} do
      includes_dir = Path.join(tmp_dir, "_includes")

      write!(includes_dir, "icons/broken.html", "{% endunless %}")

      assert Build.includes(includes_dir) ==
               {:error,
                [
                  {:unparsable_include,
                   RenderError.new(
                     {:liquid, "Unexpected tag 'endunless'"},
                     "icons/broken.html",
                     %{line: 1, column: 1}
                   )}
                ]}
    end
  end

  describe "headings!/3" do
    test "identifies the headings of the pages it is asked about", %{tmp_dir: tmp_dir} do
      {content_dir, includes_dir} = course_with_headings(tmp_dir)

      exercise = {:document, DocumentRef.new(402, "run-virtual-server", :exercise)}

      assert Build.headings!(content_dir, includes_dir, [exercise, {:cheatsheet, "sysadmin"}]) ==
               Headings.new(%{
                 exercise => ["create-your-server", "configure-open-ports"],
                 {:cheatsheet, "sysadmin"} => ["how-do-i-change-my-username-usermod"]
               })
    end

    test "identifies the headings of no page at all", %{tmp_dir: tmp_dir} do
      {content_dir, includes_dir} = course_with_headings(tmp_dir)

      assert Build.headings!(content_dir, includes_dir, []) == Headings.new(%{})
    end

    test "refuses a page the content directory does not hold", %{tmp_dir: tmp_dir} do
      {content_dir, includes_dir} = course_with_headings(tmp_dir)

      assert_raise RuntimeError,
                   """
                   The headings of the course material could not be read:
                     The content directory holds no page at "/cheatsheets/docker/"
                     The content directory holds no page at "/"\
                   """,
                   fn ->
                     Build.headings!(content_dir, includes_dir, [{:cheatsheet, "docker"}, :home])
                   end
    end

    test "reports what is wrong with a page it cannot render", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      includes_dir = Path.join(tmp_dir, "_includes")

      write!(
        content_dir,
        "_course/507-dns/subject.md",
        "---\ntitle: DNS\n---\n\n{% include icons/gone.html %}\n"
      )

      assert_raise RuntimeError,
                   """
                   The headings of the course material could not be read:
                     Document "_course/507-dns/subject.md" could not be rendered: There is no include named "icons/gone.html" in _course/507-dns/subject.md at line 5, column 1\
                   """,
                   fn ->
                     Build.headings!(content_dir, includes_dir, [
                       {:document, DocumentRef.new(507, "dns", :subject)}
                     ])
                   end
    end
  end

  describe "progress_entries!/1" do
    test "reads what each session said about the progress through the course, in order", %{
      tmp_dir: tmp_dir
    } do
      content_dir = Path.join(tmp_dir, "collections")

      write!(
        content_dir,
        "_progress/2025-09-26-ssh.md",
        "---\ndone: [101]\ndue: [102]\n---\n\nSecond session\n"
      )

      write!(
        content_dir,
        "_progress/2025-09-19-cli.md",
        "---\nnext: [100, 101, 102]\n---\n\nFirst session\n"
      )

      write!(
        content_dir,
        "_course/101-command-line/subject.md",
        "---\ntitle: CLI\n---\n\nType.\n"
      )

      assert Build.progress_entries!(content_dir) == [
               %{"next" => [100, 101, 102]},
               %{"done" => [101], "due" => [102]}
             ]
    end

    test "reads nothing from a course that has been taught no session", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      File.mkdir_p!(content_dir)

      assert Build.progress_entries!(content_dir) == []
    end

    test "reports every session it cannot take apart", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_progress/2025-10-03-git.md", "---\ndone: [\n---\n\nThird session\n")
      write!(content_dir, "_progress/2025-10-10-cloud.md", "---\ndue: [204]\n")

      assert_raise RuntimeError,
                   """
                   The progress through the course could not be read:
                     Document "_progress/2025-10-03-git.md" has invalid front matter: malformed yaml
                     Document "_progress/2025-10-10-cloud.md" opens front matter it never closes\
                   """,
                   fn -> Build.progress_entries!(content_dir) end
    end
  end

  describe "content_tree/1" do
    test "sorts the files of a content directory, litter included", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/509-reverse-proxy/subject.md", "# Reverse proxy")
      write!(content_dir, "_course/509-reverse-proxy/images/proxy.png", "a picture")
      write!(content_dir, "_course/509-reverse-proxy/.DS_Store", "litter")
      write!(content_dir, "_cheatsheets/git/cheatsheet.md", "# Git")

      assert Build.content_tree(content_dir) ==
               {:ok,
                %ContentTree{
                  documents: %{
                    DocumentRef.new(509, "reverse-proxy", :subject) =>
                      "_course/509-reverse-proxy/subject.md"
                  },
                  cheatsheets: %{"git" => "_cheatsheets/git/cheatsheet.md"},
                  page_assets: %{
                    "/course/509-reverse-proxy/images/proxy.png" =>
                      "_course/509-reverse-proxy/images/proxy.png"
                  },
                  ignored: ["_course/509-reverse-proxy/.DS_Store"]
                }}
    end

    test "sorts an empty content directory", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      File.mkdir_p!(content_dir)

      assert Build.content_tree(content_dir) ==
               {:ok,
                %ContentTree{documents: %{}, cheatsheets: %{}, page_assets: %{}, ignored: []}}
    end
  end

  describe "declarations/1" do
    test "reads what the course declares about itself", %{tmp_dir: tmp_dir} do
      file = Path.join(tmp_dir, "course.yml")

      File.write!(file, """
      ---
      sections:
        - title: Introduction
        - title: Version Control
      cheatsheets:
        - command-line
        - git
      """)

      assert Build.declarations(file) ==
               {:ok,
                %{
                  "sections" => [%{"title" => "Introduction"}, %{"title" => "Version Control"}],
                  "cheatsheets" => ["command-line", "git"]
                }}
    end

    test "reports declarations that are not there", %{tmp_dir: tmp_dir} do
      file = Path.join(tmp_dir, "course.yml")

      assert Build.declarations(file) == {:error, [{:missing_declarations, file}]}
    end

    test "reports declarations that are not YAML", %{tmp_dir: tmp_dir} do
      file = Path.join(tmp_dir, "course.yml")
      File.write!(file, "sections:\n  - title: Introduction\n   - title: Security\n")

      assert Build.declarations(file) ==
               {:error,
                [
                  {:undecodable_declarations, file,
                   ~s{Unexpected "yamerl_collection_start" token following a "yamerl_collection_end" token (line: 3, column: 4)}}
                ]}
    end
  end

  describe "sources/2" do
    test "takes every page of a content directory apart", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/507-dns/subject.md", "---\ntitle: DNS\n---\n\nA name.\n")
      write!(content_dir, "_cheatsheets/git/cheatsheet.md", "---\ntitle: Git\n---\n\nA commit.\n")

      {:ok, tree} = Build.content_tree(content_dir)
      {:ok, subject} = Source.parse("---\ntitle: DNS\n---\n\nA name.\n")
      {:ok, cheatsheet} = Source.parse("---\ntitle: Git\n---\n\nA commit.\n")

      assert Build.sources(tree, content_dir) ==
               {:ok,
                %{
                  {:document, DocumentRef.new(507, "dns", :subject)} => subject,
                  {:cheatsheet, "git"} => cheatsheet
                }}
    end

    test "reports every page that cannot be taken apart rather than the first", %{
      tmp_dir: tmp_dir
    } do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/101-command-line/subject.md", "---\ntitle: Command Line\n")
      write!(content_dir, "_cheatsheets/git/cheatsheet.md", "---\ntitle: [\n---\n\nA commit.\n")

      {:ok, tree} = Build.content_tree(content_dir)

      assert Build.sources(tree, content_dir) ==
               {:error,
                [
                  {:unparsable_document, "_cheatsheets/git/cheatsheet.md",
                   {:invalid_front_matter, "malformed yaml"}},
                  {:unparsable_document, "_course/101-command-line/subject.md",
                   :unterminated_front_matter}
                ]}
    end
  end

  describe "front_matter/1" do
    test "reads what every page of a content directory says it is", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(
        content_dir,
        "_course/205-php-todolist/exercise.md",
        "---\ntitle: PHP Todolist\ngraded: true\n---\n\nBuild it.\n"
      )

      write!(
        content_dir,
        "_cheatsheets/docker/cheatsheet.md",
        "A cheatsheet with no front matter"
      )

      {:ok, tree} = Build.content_tree(content_dir)
      {:ok, sources} = Build.sources(tree, content_dir)

      assert Build.front_matter(sources) == %{
               {:document, DocumentRef.new(205, "php-todolist", :exercise)} => %{
                 "title" => "PHP Todolist",
                 "graded" => true
               },
               {:cheatsheet, "docker"} => %{}
             }
    end
  end

  describe "page_asset_manifest/2" do
    test "names each file after the content it holds", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/801-docker/slides/slides.md", "# Docker")
      write!(content_dir, "_course/801-docker/slides/images/whale.png", "a whale")
      write!(content_dir, "_course/801-docker/images/layers.png", "some layers")

      {:ok, tree} = Build.content_tree(content_dir)

      assert Build.page_asset_manifest(tree, content_dir) ==
               {:ok,
                PageAssetManifest.new(%{
                  "/course/801-docker/slides/images/whale.png" =>
                    digested("whale.png", "a whale"),
                  "/course/801-docker/images/layers.png" => digested("layers.png", "some layers")
                })}
    end

    test "names nothing when no page has a file next to it", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/802-docker-fibscale/subject.md", "# Fibscale")

      {:ok, tree} = Build.content_tree(content_dir)

      assert Build.page_asset_manifest(tree, content_dir) == {:ok, PageAssetManifest.new(%{})}
    end

    test "reports every file it cannot read", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")

      write!(content_dir, "_course/803-docker-isolation/images/there.png", "a picture")

      tree = %ContentTree{
        documents: %{},
        cheatsheets: %{},
        page_assets: %{
          "/course/803-docker-isolation/images/there.png" =>
            "_course/803-docker-isolation/images/there.png",
          "/course/803-docker-isolation/images/gone.png" =>
            "_course/803-docker-isolation/images/gone.png"
        },
        ignored: []
      }

      assert Build.page_asset_manifest(tree, content_dir) ==
               {:error,
                [
                  {:unreadable_source, "/course/803-docker-isolation/images/gone.png",
                   "_course/803-docker-isolation/images/gone.png", :enoent}
                ]}
    end
  end

  describe "publish_page_assets/4" do
    test "copies each file under the name it is published as", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      output_dir = Path.join(tmp_dir, "build")

      write!(content_dir, "_course/804-docker-compose/slides/slides.md", "# Compose")
      write!(content_dir, "_course/804-docker-compose/slides/images/stack.png", "a stack")
      write!(content_dir, "_course/804-docker-compose/images/network.png", "a network")

      {:ok, tree} = Build.content_tree(content_dir)
      {:ok, manifest} = Build.page_asset_manifest(tree, content_dir)

      stack = digested("stack.png", "a stack")
      network = digested("network.png", "a network")

      assert Build.publish_page_assets(manifest, tree, content_dir, output_dir) == :ok

      assert written(output_dir) == %{
               "/course/804-docker-compose/images/#{network}" => "a network",
               "/course/804-docker-compose/slides/images/#{stack}" => "a stack"
             }
    end

    test "copies nothing when there is nothing to publish", %{tmp_dir: tmp_dir} do
      content_dir = Path.join(tmp_dir, "collections")
      output_dir = Path.join(tmp_dir, "build")

      write!(content_dir, "_course/805-docker-swarm/subject.md", "# Swarm")

      {:ok, tree} = Build.content_tree(content_dir)
      {:ok, manifest} = Build.page_asset_manifest(tree, content_dir)

      assert Build.publish_page_assets(manifest, tree, content_dir, output_dir) == :ok
      assert written(output_dir) == %{}
    end
  end

  describe "asset_manifest/1" do
    test "reads the manifest the digester wrote", %{tmp_dir: tmp_dir} do
      static_dir = Path.join(tmp_dir, "static")

      write!(
        static_dir,
        "cache_manifest.json",
        JSON.encode!(%{
          "version" => 1,
          "latest" => %{"assets/theme/theme.css" => "assets/theme/theme-abc123.css"},
          "digests" => %{}
        })
      )

      assert Build.asset_manifest(static_dir) ==
               {:ok,
                %AssetManifest{
                  assets: %{"/assets/theme/theme.css" => "/assets/theme/theme-abc123.css"}
                }}
    end

    test "refuses a build whose assets were never digested", %{tmp_dir: tmp_dir} do
      static_dir = Path.join(tmp_dir, "static")
      File.mkdir_p!(static_dir)

      assert Build.asset_manifest(static_dir) ==
               {:error, [{:missing_manifest, Path.join(static_dir, "cache_manifest.json")}]}
    end

    test "refuses a manifest that is not JSON", %{tmp_dir: tmp_dir} do
      static_dir = Path.join(tmp_dir, "static")
      write!(static_dir, "cache_manifest.json", "not json at all")

      assert Build.asset_manifest(static_dir) ==
               {:error, [{:undecodable_manifest, Path.join(static_dir, "cache_manifest.json")}]}
    end

    test "refuses a manifest of another version", %{tmp_dir: tmp_dir} do
      static_dir = Path.join(tmp_dir, "static")
      write!(static_dir, "cache_manifest.json", JSON.encode!(%{"version" => 9, "latest" => %{}}))

      assert Build.asset_manifest(static_dir) == {:error, [{:unsupported_manifest_version, 9}]}
    end
  end

  describe "undigested_asset_manifest/1" do
    test "publishes each asset of a static directory under its own name", %{tmp_dir: tmp_dir} do
      static_dir = Path.join(tmp_dir, "static")

      write!(static_dir, "assets/app/app.js", "the application")
      write!(static_dir, "assets/emoji/2615.svg", "a coffee")
      write!(static_dir, "index.html", "the home page")

      assert Build.undigested_asset_manifest(static_dir) ==
               %AssetManifest{
                 assets: %{
                   "/assets/app/app.js" => "/assets/app/app.js",
                   "/assets/emoji/2615.svg" => "/assets/emoji/2615.svg"
                 }
               }
    end
  end

  describe "output_files/1" do
    test "names every file a build wrote, as an output path", %{tmp_dir: tmp_dir} do
      output_dir = Path.join(tmp_dir, "build")

      write!(output_dir, "index.html", "the home page")
      write!(output_dir, "course/804-docker-compose/index.html", "a chapter")
      write!(output_dir, "course/804-docker-compose/images/stack-9f8e.png", "a picture")

      assert Build.output_files(output_dir) ==
               MapSet.new([
                 "/index.html",
                 "/course/804-docker-compose/index.html",
                 "/course/804-docker-compose/images/stack-9f8e.png"
               ])
    end
  end

  describe "format_error/1" do
    test "describes a build whose assets were never digested" do
      assert Build.format_error({:missing_manifest, "/build/static/cache_manifest.json"}) ==
               ~s{Asset manifest "/build/static/cache_manifest.json" does not exist; run the digest step before building}
    end

    test "describes a manifest that could not be read" do
      assert Build.format_error({:unreadable_manifest, "/build/cache_manifest.json", :eacces}) ==
               ~s{Asset manifest "/build/cache_manifest.json" could not be read: permission denied}
    end

    test "describes a manifest that is not JSON" do
      assert Build.format_error({:undecodable_manifest, "/build/cache_manifest.json"}) ==
               ~s{Asset manifest "/build/cache_manifest.json" is not JSON}
    end

    test "describes a file that could not be read" do
      assert Build.format_error(
               {:unreadable_source, "/course/805-swarm/images/x.png",
                "_course/805-swarm/images/x.png", :enoent}
             ) ==
               ~s{File "_course/805-swarm/images/x.png", published at "/course/805-swarm/images/x.png", could not be read: no such file or directory}
    end

    test "describes a file that could not be written" do
      assert Build.format_error(
               {:unwritable_output, "/course/806-k8s/images/x.png",
                "/build/course/806-k8s/images/x-ff00.png", :eacces}
             ) ==
               ~s{File published at "/course/806-k8s/images/x.png" could not be written to "/build/course/806-k8s/images/x-ff00.png": permission denied}
    end

    test "describes a partial that could not be read" do
      assert Build.format_error(
               {:unreadable_include, "icons/photo.html", "/build/_includes/icons/photo.html",
                :eacces}
             ) ==
               ~s{Partial "icons/photo.html" could not be read from "/build/_includes/icons/photo.html": permission denied}
    end

    test "describes a partial that could not be parsed" do
      error =
        RenderError.new(
          {:liquid, "Unexpected tag 'endunless'"},
          "icons/broken.html",
          %{line: 1, column: 1}
        )

      assert Build.format_error({:unparsable_include, error}) ==
               "A partial could not be parsed: Unexpected tag 'endunless' in icons/broken.html at line 1, column 1"
    end

    test "describes a page the content directory does not hold" do
      assert Build.format_error({:unknown_page, {:cheatsheet, "docker"}}) ==
               ~s{The content directory holds no page at "/cheatsheets/docker/"}
    end

    test "describes a document that could not be rendered" do
      error =
        RenderError.new(
          {:invalid_tag, "note", "this tag always fails"},
          "_course/507-dns/subject.md",
          %{line: 3, column: 1}
        )

      assert Build.format_error({:unrenderable_document, "_course/507-dns/subject.md", error}) ==
               "Document \"_course/507-dns/subject.md\" could not be rendered: " <>
                 "Invalid {% note %} tag (this tag always fails) " <>
                 "in _course/507-dns/subject.md at line 3, column 1"
    end

    test "describes what went wrong in the content directory" do
      assert Build.format_error({:unknown_source, "_course/807-nomad/notes.md"}) ==
               ~s{Source file "_course/807-nomad/notes.md" is neither a document nor a file of a page}
    end

    test "describes a name two files would be published under" do
      assert Build.format_error(
               {:digested_name_collision, "/course/808-consul/images/a-ff00.png",
                ["/course/808-consul/images/a-ff00.png", "/course/808-consul/images/a.png"]}
             ) ==
               ~s{Published path "/course/808-consul/images/a-ff00.png" would be written by "/course/808-consul/images/a-ff00.png" and "/course/808-consul/images/a.png"}
    end

    test "describes declarations that are not there" do
      assert Build.format_error({:missing_declarations, "/course/_data/course.yml"}) ==
               ~s{Course declarations "/course/_data/course.yml" do not exist}
    end

    test "describes declarations that could not be read" do
      assert Build.format_error({:unreadable_declarations, "/course/_data/course.yml", :eacces}) ==
               ~s{Course declarations "/course/_data/course.yml" could not be read: permission denied}
    end

    test "describes declarations that are not YAML" do
      assert Build.format_error(
               {:undecodable_declarations, "/course/_data/course.yml", "malformed yaml"}
             ) ==
               ~s{Course declarations "/course/_data/course.yml" are not YAML: malformed yaml}
    end

    test "describes a document that could not be read" do
      assert Build.format_error(
               {:unreadable_document, "_course/809-etcd/subject.md",
                "/course/collections/_course/809-etcd/subject.md", :eacces}
             ) ==
               ~s{Document "_course/809-etcd/subject.md" could not be read from "/course/collections/_course/809-etcd/subject.md": permission denied}
    end

    test "describes a document that opens front matter it never closes" do
      assert Build.format_error(
               {:unparsable_document, "_course/810-vault/subject.md", :unterminated_front_matter}
             ) ==
               ~s{Document "_course/810-vault/subject.md" opens front matter it never closes}
    end

    test "describes a document whose front matter is not valid" do
      assert Build.format_error(
               {:unparsable_document, "_course/811-istio/subject.md",
                {:invalid_front_matter, "malformed yaml"}}
             ) ==
               ~s{Document "_course/811-istio/subject.md" has invalid front matter: malformed yaml}
    end

    test "describes a manifest of an unsupported version" do
      assert Build.format_error({:unsupported_manifest_version, 3}) ==
               "Asset manifest version 3 is not version 1, the one this build reads"
    end
  end

  # A content directory of two pages that write headings, and the one partial
  # the tag of a note draws its icon from.
  defp course_with_headings(tmp_dir) do
    content_dir = Path.join(tmp_dir, "collections")
    includes_dir = Path.join(tmp_dir, "_includes")

    write!(includes_dir, "icons/info-circle.html", "<svg/>")

    write!(content_dir, "_course/402-run-virtual-server/exercise.md", """
    ---
    title: Run your own virtual server
    ---

    Rent one.

    ## Create your server

    {% note %}
    ## Configure open ports
    {% endnote %}
    """)

    write!(content_dir, "_cheatsheets/sysadmin/cheatsheet.md", """
    ---
    title: System Administration Cheatsheet
    ---

    ### How do I change my username? (`usermod`)
    """)

    {content_dir, includes_dir}
  end

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end

  defp digested(file_name, contents) do
    extension = Path.extname(file_name)
    digest = Base.encode16(:erlang.md5(contents), case: :lower)
    "#{Path.rootname(file_name)}-#{digest}#{extension}"
  end

  # The whole of what a build left behind: every path it wrote and what is in
  # each, so that one equality pins the output directory rather than its
  # listing.
  defp written(output_dir) do
    output_dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Map.new(&{"/" <> Path.relative_to(&1, output_dir), File.read!(&1)})
  end
end
