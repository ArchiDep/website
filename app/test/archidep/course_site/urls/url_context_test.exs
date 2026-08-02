defmodule ArchiDep.CourseSite.Urls.UrlContextTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext

  doctest ArchiDep.CourseSite.Urls.UrlContext

  describe "new/1" do
    test "builds a context from its mode and build ID alone" do
      assert UrlContext.new(mode: :live, build_id: "3f2a1b") == %UrlContext{
               mode: :live,
               base_path: "",
               version: nil,
               build_id: "3f2a1b",
               absolute_base_url: nil,
               live_site_url: nil,
               assets: %AssetManifest{assets: %{}},
               page_assets: %PageAssetManifest{page_assets: %{}, digested: %{}},
               pdfs: %PdfManifest{base: :site, entries: %{}}
             }
    end

    test "builds a fully configured context" do
      assets = AssetManifest.new(%{"/assets/app/app.js" => "/assets/app/app-4d5e6f.js"})
      page_assets = PageAssetManifest.new(%{"/course/507-dns/images/dig.png" => "dig-7a8b9c.png"})
      pdfs = PdfManifest.new({:external, "https://pdfs.example.com"}, %{})

      assert UrlContext.new(
               mode: :archive,
               base_path: "/website",
               version: "2025",
               build_id: "9c8b7a",
               absolute_base_url: "https://archidep.example.com",
               live_site_url: "https://live.example.com",
               assets: assets,
               page_assets: page_assets,
               pdfs: pdfs
             ) == %UrlContext{
               mode: :archive,
               base_path: "/website",
               version: "2025",
               build_id: "9c8b7a",
               absolute_base_url: "https://archidep.example.com",
               live_site_url: "https://live.example.com",
               assets: assets,
               page_assets: page_assets,
               pdfs: pdfs
             }
    end

    test "rejects an unknown mode" do
      assert_raise ArgumentError,
                   "Build mode :preview must be one of [:live, :backup, :archive]",
                   fn -> UrlContext.new(mode: :preview, build_id: "1a2b3c") end
    end

    test "rejects an empty build ID" do
      assert_raise ArgumentError, "Build ID \"\" must be a non-empty string", fn ->
        UrlContext.new(mode: :live, build_id: "")
      end
    end

    test "rejects a base path without a leading slash" do
      assert_raise ArgumentError, "Base path \"website\" must start with a slash", fn ->
        UrlContext.new(mode: :backup, build_id: "1a2b3c", base_path: "website")
      end
    end

    test "rejects a base path with a trailing slash" do
      assert_raise ArgumentError, "Base path \"/website/\" must not end with a slash", fn ->
        UrlContext.new(mode: :backup, build_id: "1a2b3c", base_path: "/website/")
      end
    end

    test "rejects a version that is not a four-digit year" do
      assert_raise ArgumentError,
                   "Version \"2025-2026\" must be a four-digit year, the starting year of the academic year",
                   fn -> UrlContext.new(mode: :live, build_id: "1a2b3c", version: "2025-2026") end
    end

    test "rejects an absolute base URL with a trailing slash" do
      assert_raise ArgumentError,
                   "Option :absolute_base_url \"https://archidep.example.com/\" must not end with a slash",
                   fn ->
                     UrlContext.new(
                       mode: :live,
                       build_id: "1a2b3c",
                       absolute_base_url: "https://archidep.example.com/"
                     )
                   end
    end

    test "rejects a live site URL that is not absolute" do
      assert_raise ArgumentError,
                   "Option :live_site_url \"archidep.example.com\" must be an absolute URL",
                   fn ->
                     UrlContext.new(
                       mode: :backup,
                       build_id: "1a2b3c",
                       live_site_url: "archidep.example.com"
                     )
                   end
    end
  end

  describe "content_prefix/1" do
    test "returns the mount point of an unversioned build" do
      context = UrlContext.new(mode: :backup, build_id: "1a2b3c", base_path: "/website")

      assert UrlContext.content_prefix(context) == "/website"
    end
  end

  describe "edition_prefix/1" do
    test "is what the edition adds to the mount point of a versioned build" do
      context =
        UrlContext.new(mode: :backup, build_id: "1a2b3c", base_path: "/website", version: "2026")

      assert UrlContext.edition_prefix(context) == "/2026"
    end
  end

  describe "home_at_base?/1" do
    test "is true for a backup of the edition being taught" do
      assert UrlContext.home_at_base?(UrlContext.new(mode: :backup, build_id: "1a2b3c"))
    end
  end
end
