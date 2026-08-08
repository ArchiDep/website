defmodule ArchiDep.CourseSite.Urls.RootFileManifestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Urls.RootFileManifest

  doctest ArchiDep.CourseSite.Urls.RootFileManifest

  describe "new/1" do
    test "builds a manifest" do
      assert RootFileManifest.new(["/favicon.ico", "/favicons/heig.png"]) ==
               %RootFileManifest{paths: MapSet.new(["/favicon.ico", "/favicons/heig.png"])}
    end

    test "builds an empty manifest" do
      assert RootFileManifest.new([]) == %RootFileManifest{paths: MapSet.new()}
    end
  end
end
