defmodule ArchiDep.CourseSite.Urls.PageAssetManifestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  doctest ArchiDep.CourseSite.Urls.PageAssetManifest

  describe "new/1" do
    test "builds a manifest" do
      page_assets = %{"/cheatsheets/sysadmin/images/apt.png" => "apt-2b3c4d.png"}

      assert PageAssetManifest.new(page_assets) ==
               %PageAssetManifest{page_assets: page_assets}
    end
  end
end
