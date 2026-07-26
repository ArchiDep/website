defmodule ArchiDep.CourseSite.Build.PageAssetDigestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.PageAssetDigest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  doctest ArchiDep.CourseSite.Build.PageAssetDigest

  describe "digested_name/2" do
    test "names a file the way the digester of the site's other assets does" do
      contents = "the contents of an image"

      assert PageAssetDigest.digested_name("cli.jpg", :erlang.md5(contents)) ==
               "cli-#{Base.encode16(:erlang.md5(contents), case: :lower)}.jpg"
    end
  end

  describe "manifest/1" do
    test "publishes each file under the name its content gives it" do
      zone_md5 = Base.decode16!("A1B2C3D4E5F60718293A4B5C6D7E8F90")
      htop_md5 = Base.decode16!("0F1E2D3C4B5A69788796A5B4C3D2E1F0")

      assert PageAssetDigest.manifest(%{
               "/course/507-dns/images/zone.png" => zone_md5,
               "/cheatsheets/sysadmin/images/htop.png" => htop_md5
             }) ==
               {:ok,
                %PageAssetManifest{
                  page_assets: %{
                    "/course/507-dns/images/zone.png" =>
                      "zone-a1b2c3d4e5f60718293a4b5c6d7e8f90.png",
                    "/cheatsheets/sysadmin/images/htop.png" =>
                      "htop-0f1e2d3c4b5a69788796a5b4c3d2e1f0.png"
                  },
                  digested: %{
                    "/course/507-dns/images/zone-a1b2c3d4e5f60718293a4b5c6d7e8f90.png" =>
                      "zone-a1b2c3d4e5f60718293a4b5c6d7e8f90.png",
                    "/cheatsheets/sysadmin/images/htop-0f1e2d3c4b5a69788796a5b4c3d2e1f0.png" =>
                      "htop-0f1e2d3c4b5a69788796a5b4c3d2e1f0.png"
                  }
                }}
    end

    test "publishes nothing when a build has no file next to any page" do
      assert PageAssetDigest.manifest(%{}) ==
               {:ok, %PageAssetManifest{page_assets: %{}, digested: %{}}}
    end

    test "refuses a file named the way the file next to it is published" do
      # `vm.png` publishes as `vm-<digest>.png`, which is the name the other
      # file is already written under — so one lookup would answer for both and
      # a reference resolved once would resolve to somebody else.
      digest = "1234567890abcdef1234567890abcdef"

      assert PageAssetDigest.manifest(%{
               "/course/403-linux/images/vm.png" => Base.decode16!(digest, case: :mixed),
               "/course/403-linux/images/vm-#{digest}.png" =>
                 Base.decode16!("FEDCBA0987654321FEDCBA0987654321")
             }) ==
               {:error,
                [
                  {:digested_name_collision, "/course/403-linux/images/vm-#{digest}.png",
                   [
                     "/course/403-linux/images/vm-#{digest}.png",
                     "/course/403-linux/images/vm.png"
                   ]}
                ]}
    end
  end

  describe "format_error/1" do
    test "describes a name two files would be published under" do
      assert PageAssetDigest.format_error(
               {:digested_name_collision, "/course/404-unix-basics/images/a-ff00.png",
                [
                  "/course/404-unix-basics/images/a-ff00.png",
                  "/course/404-unix-basics/images/a.png"
                ]}
             ) ==
               ~s{Published path "/course/404-unix-basics/images/a-ff00.png" would be written by "/course/404-unix-basics/images/a-ff00.png" and "/course/404-unix-basics/images/a.png"}
    end
  end
end
