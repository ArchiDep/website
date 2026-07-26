defmodule ArchiDep.CourseSite.Build.AssetDigestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.AssetDigest
  alias ArchiDep.CourseSite.Urls.AssetManifest

  doctest ArchiDep.CourseSite.Build.AssetDigest

  describe "from_cache_manifest/1" do
    test "roots every path of the digester's latest map" do
      assert AssetDigest.from_cache_manifest(%{
               "version" => 1,
               "latest" => %{
                 "assets/app/app.js" => "assets/app/app-4d5e6f.js",
                 "assets/emoji/1f4da.svg" => "assets/emoji/1f4da-7a8b9c.svg"
               },
               "digests" => %{}
             }) ==
               {:ok,
                %AssetManifest{
                  assets: %{
                    "/assets/app/app.js" => "/assets/app/app-4d5e6f.js",
                    "/assets/emoji/1f4da.svg" => "/assets/emoji/1f4da-7a8b9c.svg"
                  }
                }}
    end

    test "keeps the source map of an asset, which the digester names after that asset" do
      assert AssetDigest.from_cache_manifest(%{
               "version" => 1,
               "latest" => %{
                 "assets/search/search.js" => "assets/search/search-1122aa.js",
                 "assets/search/search.js.map" => "assets/search/search-1122aa.js.map"
               }
             }) ==
               {:ok,
                %AssetManifest{
                  assets: %{
                    "/assets/search/search.js" => "/assets/search/search-1122aa.js",
                    "/assets/search/search.js.map" => "/assets/search/search-1122aa.js.map"
                  }
                }}
    end

    test "reads a manifest holding stale digests exactly as one holding none" do
      latest = %{"assets/theme/slides.css" => "assets/theme/slides-99aabb.css"}

      with_digests =
        AssetDigest.from_cache_manifest(%{
          "version" => 1,
          "latest" => latest,
          "digests" => %{
            "assets/theme/slides-000000.css" => %{
              "logical_path" => "assets/theme/slides.css",
              "size" => 12,
              "mtime" => 1,
              "digest" => "000000",
              "sha512" => "irrelevant"
            }
          }
        })

      assert with_digests ==
               AssetDigest.from_cache_manifest(%{"version" => 1, "latest" => latest})
    end

    test "reads an empty manifest" do
      assert AssetDigest.from_cache_manifest(%{"version" => 1, "latest" => %{}, "digests" => %{}}) ==
               {:ok, %AssetManifest{assets: %{}}}
    end

    test "refuses a manifest of another version" do
      assert AssetDigest.from_cache_manifest(%{
               "version" => 7,
               "latest" => %{"assets/app/app.js" => "assets/app/app-cafe01.js"}
             }) == {:error, {:unsupported_manifest_version, 7}}
    end

    test "refuses a manifest with no version" do
      assert AssetDigest.from_cache_manifest(%{"latest" => %{}}) ==
               {:error, {:malformed_manifest, ~s{no "version"}}}
    end

    test "refuses a manifest whose latest map is not a map" do
      assert AssetDigest.from_cache_manifest(%{"version" => 1, "latest" => []}) ==
               {:error, {:malformed_manifest, ~s{"latest" is not a map}}}
    end

    test "refuses a manifest publishing a path as something that is not a path" do
      assert AssetDigest.from_cache_manifest(%{
               "version" => 1,
               "latest" => %{"assets/theme/theme.css" => nil}
             }) ==
               {:error, {:malformed_manifest, ~s{"assets/theme/theme.css" is published as nil}}}
    end
  end

  describe "undigested/1" do
    test "publishes every asset under the name it is written with" do
      assert AssetDigest.undigested([
               "/assets/course/course.js",
               "/assets/course/course.css"
             ]) ==
               %AssetManifest{
                 assets: %{
                   "/assets/course/course.js" => "/assets/course/course.js",
                   "/assets/course/course.css" => "/assets/course/course.css"
                 }
               }
    end

    test "publishes nothing when the build wrote no assets" do
      assert AssetDigest.undigested([]) == %AssetManifest{assets: %{}}
    end
  end

  describe "format_error/1" do
    test "describes a manifest of an unsupported version" do
      assert AssetDigest.format_error({:unsupported_manifest_version, 4}) ==
               "Asset manifest version 4 is not version 1, the one this build reads"
    end

    test "describes a malformed manifest" do
      assert AssetDigest.format_error({:malformed_manifest, ~s{no "latest" map}}) ==
               ~s{Asset manifest is malformed: no "latest" map}
    end
  end
end
