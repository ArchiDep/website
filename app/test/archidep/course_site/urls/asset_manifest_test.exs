defmodule ArchiDep.CourseSite.Urls.AssetManifestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Urls.AssetManifest

  doctest ArchiDep.CourseSite.Urls.AssetManifest

  describe "new/1" do
    test "builds a manifest" do
      assert AssetManifest.new(%{"/assets/app/app.js" => "/assets/app/app-4d5e6f.js"}) ==
               %AssetManifest{assets: %{"/assets/app/app.js" => "/assets/app/app-4d5e6f.js"}}
    end
  end
end
