defmodule ArchiDep.CourseSite.Urls.PdfManifestTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Urls.PdfManifest

  doctest ArchiDep.CourseSite.Urls.PdfManifest

  describe "new/2" do
    test "builds a manifest of PDFs published alongside the site" do
      entries = %{
        {:document, DocumentRef.new(202, "git-branching", :slides)} =>
          "archidep-202-git-branching-slides.pdf"
      }

      assert PdfManifest.new(:site, entries) == %PdfManifest{base: :site, entries: entries}
    end

    test "builds a manifest of PDFs published under an absolute base URL" do
      entries = %{{:cheatsheet, "docker"} => "archidep-999-docker.pdf"}

      assert PdfManifest.new({:external, "https://pdfs.example.com/2026"}, entries) ==
               %PdfManifest{base: {:external, "https://pdfs.example.com/2026"}, entries: entries}
    end

    test "builds a manifest of PDFs published at URLs of their own" do
      entries = %{
        {:cheatsheet, "git"} => {:url, "https://example.com/releases/archidep-999-git.v2.pdf"}
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

  describe "validate_base!/1" do
    test "accepts PDFs published alongside the site" do
      assert PdfManifest.validate_base!(:site) == :site
    end

    test "accepts PDFs published under an absolute base URL" do
      assert PdfManifest.validate_base!({:external, "http://pdfs.example.com"}) ==
               {:external, "http://pdfs.example.com"}
    end

    test "rejects a base URL that is not absolute" do
      assert_raise ArgumentError,
                   "PDF base URL \"pdfs.example.com/2026\" must be an absolute URL",
                   fn -> PdfManifest.validate_base!({:external, "pdfs.example.com/2026"}) end
    end
  end
end
