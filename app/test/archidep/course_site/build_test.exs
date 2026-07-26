defmodule ArchiDep.CourseSite.BuildTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  @moduletag :tmp_dir

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

    test "describes a manifest of an unsupported version" do
      assert Build.format_error({:unsupported_manifest_version, 3}) ==
               "Asset manifest version 3 is not version 1, the one this build reads"
    end
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
