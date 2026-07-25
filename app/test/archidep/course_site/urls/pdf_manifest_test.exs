defmodule ArchiDep.CourseSite.Urls.PdfManifestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Urls.PdfManifest

  doctest ArchiDep.CourseSite.Urls.PdfManifest

  describe "new/2" do
    test "builds a manifest of PDFs published alongside the site" do
      entries = %{
        {:document, DocumentRef.new(202, "git-branching", :slides)} =>
          "ArchiDep 202 - Version control - Git branching - Slides.pdf"
      }

      assert PdfManifest.new(:site, entries) == %PdfManifest{base: :site, entries: entries}
    end

    test "builds a manifest of PDFs published under an absolute base URL" do
      entries = %{{:cheatsheet, "docker"} => "ArchiDep 999 - Docker.pdf"}

      assert PdfManifest.new({:external, "https://pdfs.example.com/2026"}, entries) ==
               %PdfManifest{base: {:external, "https://pdfs.example.com/2026"}, entries: entries}
    end

    test "builds a manifest of PDFs published at URLs of their own" do
      entries = %{
        {:cheatsheet, "git"} => {:url, "https://example.com/releases/ArchiDep.999.-.Git.pdf"}
      }

      assert PdfManifest.new({:external, "https://example.com/releases"}, entries) ==
               %PdfManifest{base: {:external, "https://example.com/releases"}, entries: entries}
    end

    test "rejects a base URL ending with a slash" do
      assert_raise ArgumentError,
                   "PDF base URL \"https://pdfs.example.com/2027/\" must not end with a slash",
                   fn -> PdfManifest.new({:external, "https://pdfs.example.com/2027/"}, %{}) end
    end

    test "rejects an unknown publication base" do
      assert_raise ArgumentError, "Invalid PDF publication base :bucket", fn ->
        PdfManifest.new(:bucket, %{})
      end
    end
  end
end
