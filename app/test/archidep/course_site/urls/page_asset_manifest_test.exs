defmodule ArchiDep.CourseSite.Urls.PageAssetManifestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  doctest ArchiDep.CourseSite.Urls.PageAssetManifest

  describe "new/1" do
    test "builds a manifest, knowing each asset by both of its names" do
      page_assets = %{"/cheatsheets/sysadmin/images/apt.png" => "apt-2b3c4d.png"}

      assert PageAssetManifest.new(page_assets) ==
               %PageAssetManifest{
                 page_assets: page_assets,
                 digested: %{"/cheatsheets/sysadmin/images/apt-2b3c4d.png" => "apt-2b3c4d.png"}
               }
    end

    test "builds a manifest of an asset sitting at the root of the site" do
      assert PageAssetManifest.new(%{"/logo.svg" => "logo-5e6f7a.svg"}) ==
               %PageAssetManifest{
                 page_assets: %{"/logo.svg" => "logo-5e6f7a.svg"},
                 digested: %{"/logo-5e6f7a.svg" => "logo-5e6f7a.svg"}
               }
    end

    test "builds an empty manifest" do
      assert PageAssetManifest.new(%{}) ==
               %PageAssetManifest{page_assets: %{}, digested: %{}}
    end
  end

  describe "fetch/2" do
    test "looks up an asset that is not in the manifest" do
      manifest = PageAssetManifest.new(%{"/course/507-dns/images/zone.png" => "zone-6f7a8b.png"})

      assert PageAssetManifest.fetch(manifest, "/course/507-dns/images/typo.png") == :error
    end
  end
end
