defmodule ArchiDep.CourseSite.UrlsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSite.Urls.UrlError
  alias ArchiDep.CourseSite.Urls.UrlPath
  alias ArchiDep.Support.CourseSiteFactory

  describe "resolve/3 with :home" do
    test "resolves to the mount point of the edition being taught" do
      context = CourseSiteFactory.build(:url_context, mode: :live, base_path: "")

      assert Urls.resolve(context, :home) == {:ok, "/"}
    end

    test "resolves to the mount point of a backup of that edition" do
      context = CourseSiteFactory.build(:url_context, mode: :backup, base_path: "/website")

      assert Urls.resolve(context, :home) == {:ok, "/website/"}
    end

    test "resolves under the edition prefix once the edition is archived" do
      context =
        CourseSiteFactory.build(:url_context, mode: :archive, base_path: "", version: "2024")

      assert Urls.resolve(context, :home) == {:ok, "/2024/"}
    end

    test "resolves under the mount point and the edition prefix of an archive" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :archive,
          base_path: "/website",
          version: "2023"
        )

      assert Urls.resolve(context, :home) == {:ok, "/website/2023/"}
    end

    test "resolves against the absolute base URL of a build printed to PDF" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :live,
          base_path: "",
          absolute_base_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, :home) == {:ok, "https://archidep.example.com/"}
    end

    test "resolves to the mount point of an unversioned build" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "/website", version: nil)

      assert Urls.resolve(context, :home) == {:ok, "/website/"}
    end
  end

  describe "resolve/3 with :document" do
    test "resolves a subject under the edition prefix" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      document = CourseSiteFactory.build(:document_ref, num: 507, slug: "dns", type: :subject)

      assert Urls.resolve(context, {:document, document}) == {:ok, "/2026/course/507-dns/"}
    end

    test "resolves an exercise under the mount point and the edition prefix" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :backup,
          base_path: "/website",
          version: "2026"
        )

      document =
        CourseSiteFactory.build(:document_ref, num: 205, slug: "php-todolist", type: :exercise)

      assert Urls.resolve(context, {:document, document}) ==
               {:ok, "/website/2026/course/205-php-todolist/"}
    end

    test "resolves slides one segment below their chapter" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      document =
        CourseSiteFactory.build(:document_ref, num: 401, slug: "cloud-computing", type: :slides)

      assert Urls.resolve(context, {:document, document}) ==
               {:ok, "/2026/course/401-cloud-computing/slides/"}
    end

    test "resolves against the absolute base URL of a build printed to PDF" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :live,
          base_path: "",
          version: "2026",
          absolute_base_url: "https://archidep.example.com"
        )

      document = CourseSiteFactory.build(:document_ref, num: 104, slug: "ssh", type: :subject)

      assert Urls.resolve(context, {:document, document}) ==
               {:ok, "https://archidep.example.com/2026/course/104-ssh/"}
    end

    test "resolves without an edition prefix in an unversioned build" do
      context = CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: nil)

      document =
        CourseSiteFactory.build(:document_ref, num: 601, slug: "ci-cd", type: :exercise)

      assert Urls.resolve(context, {:document, document}) == {:ok, "/course/601-ci-cd/"}
    end
  end

  describe "resolve/3 with :cheatsheet" do
    test "resolves under the edition prefix" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      assert Urls.resolve(context, {:cheatsheet, "sysadmin"}) ==
               {:ok, "/2026/cheatsheets/sysadmin/"}
    end

    test "resolves against the absolute base URL of a build printed to PDF" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :live,
          base_path: "",
          version: "2025",
          absolute_base_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:cheatsheet, "git"}) ==
               {:ok, "https://archidep.example.com/2025/cheatsheets/git/"}
    end
  end

  describe "resolve/3 with :heading" do
    test "resolves to a bare fragment within the document being rendered" do
      context = CourseSiteFactory.build(:url_context)
      document = CourseSiteFactory.build(:document_ref, num: 402, type: :exercise)
      page = {:document, document}

      assert Urls.resolve(context, {:heading, page, "create-your-server"}, page) ==
               {:ok, "#create-your-server"}
    end

    test "resolves to a bare fragment within the cheatsheet being rendered" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(
               context,
               {:heading, {:cheatsheet, "sysadmin"}, "installing--upgrading"},
               {:cheatsheet, "sysadmin"}
             ) == {:ok, "#installing--upgrading"}
    end

    test "resolves to a bare fragment within the home page being rendered" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(context, {:heading, :home, "schedule"}, :home) == {:ok, "#schedule"}
    end

    test "resolves to a bare fragment even when content links are absolutized" do
      context =
        CourseSiteFactory.build(:url_context, absolute_base_url: "https://archidep.example.com")

      document = CourseSiteFactory.build(:document_ref, num: 409, slug: "tcp", type: :subject)
      page = {:document, document}

      assert Urls.resolve(context, {:heading, page, "establish-a-connection"}, page) ==
               {:ok, "#establish-a-connection"}
    end

    test "resolves a heading of another document in full" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      target =
        CourseSiteFactory.build(:document_ref,
          num: 402,
          slug: "run-virtual-server",
          type: :exercise
        )

      from = {:document, CourseSiteFactory.build(:document_ref, num: 104, slug: "ssh")}

      assert Urls.resolve(context, {:heading, {:document, target}, "create-your-server"}, from) ==
               {:ok, "/2026/course/402-run-virtual-server/#create-your-server"}
    end

    test "resolves a heading in full when no page is being rendered" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      target =
        CourseSiteFactory.build(:document_ref,
          num: 402,
          slug: "run-virtual-server",
          type: :exercise
        )

      assert Urls.resolve(context, {:heading, {:document, target}, "open-the-ports"}) ==
               {:ok, "/2026/course/402-run-virtual-server/#open-the-ports"}
    end

    test "resolves a heading of a cheatsheet in full" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      assert Urls.resolve(
               context,
               {:heading, {:cheatsheet, "sysadmin"}, "how-do-i-change-my-username-usermod"}
             ) == {:ok, "/2026/cheatsheets/sysadmin/#how-do-i-change-my-username-usermod"}
    end

    test "resolves a heading of another document against the absolute base URL" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :live,
          base_path: "",
          version: "2026",
          absolute_base_url: "https://archidep.example.com"
        )

      target = CourseSiteFactory.build(:document_ref, num: 507, slug: "dns", type: :subject)

      assert Urls.resolve(context, {:heading, {:document, target}, "records"}) ==
               {:ok, "https://archidep.example.com/2026/course/507-dns/#records"}
    end
  end

  describe "resolve/3 with :page_asset" do
    test "resolves an image next to a subject" do
      document =
        CourseSiteFactory.build(:document_ref, num: 101, slug: "command-line", type: :subject)

      context =
        CourseSiteFactory.build(:url_context,
          page_assets:
            PageAssetManifest.new(%{
              "/course/101-command-line/images/cli.jpg" => "cli-9f8e7d.jpg"
            })
        )

      assert Urls.resolve(context, {:page_asset, {:document, document}, "images/cli.jpg"}) ==
               {:ok, "images/cli-9f8e7d.jpg"}
    end

    test "resolves an image of a chapter referenced from slides written at the chapter's root" do
      document =
        CourseSiteFactory.build(:document_ref, num: 401, slug: "cloud-computing", type: :slides)

      context =
        CourseSiteFactory.build(:url_context,
          page_assets:
            PageAssetManifest.new(%{
              "/course/401-cloud-computing/images/client-server.jpg" => "client-server-1b2c3d.jpg"
            })
        )

      assert Urls.resolve(
               context,
               {:page_asset, {:document, document}, "../images/client-server.jpg"}
             ) == {:ok, "../images/client-server-1b2c3d.jpg"}
    end

    test "resolves an image next to slides written in their own directory" do
      document =
        CourseSiteFactory.build(:document_ref, num: 101, slug: "command-line", type: :slides)

      context =
        CourseSiteFactory.build(:url_context,
          page_assets:
            PageAssetManifest.new(%{
              "/course/101-command-line/slides/images/tty.jpg" => "tty-4e5f6a.jpg"
            })
        )

      assert Urls.resolve(context, {:page_asset, {:document, document}, "images/tty.jpg"}) ==
               {:ok, "images/tty-4e5f6a.jpg"}
    end

    test "resolves an image next to a cheatsheet" do
      context =
        CourseSiteFactory.build(:url_context,
          page_assets:
            PageAssetManifest.new(%{
              "/cheatsheets/sysadmin/images/apt.png" => "apt-7b8c9d.png"
            })
        )

      assert Urls.resolve(context, {:page_asset, {:cheatsheet, "sysadmin"}, "./images/apt.png"}) ==
               {:ok, "./images/apt-7b8c9d.png"}
    end

    test "resolves identically under two unrelated deployment configurations" do
      document =
        CourseSiteFactory.build(:document_ref, num: 403, slug: "docker", type: :slides)

      page_assets =
        PageAssetManifest.new(%{"/course/403-docker/images/whale.png" => "whale-3c4d5e.png"})

      live =
        CourseSiteFactory.build(:url_context,
          mode: :live,
          base_path: "",
          version: "2026",
          page_assets: page_assets
        )

      archived =
        CourseSiteFactory.build(:url_context,
          mode: :archive,
          base_path: "/website",
          version: "2021",
          absolute_base_url: "https://archidep.example.com",
          page_assets: page_assets
        )

      reference = {:page_asset, {:document, document}, "../images/whale.png"}

      assert Urls.resolve(live, reference) == {:ok, "../images/whale-3c4d5e.png"}
      assert Urls.resolve(archived, reference) == {:ok, "../images/whale-3c4d5e.png"}
    end

    test "encodes a name that is not safe in a URL" do
      context =
        CourseSiteFactory.build(:url_context,
          page_assets:
            PageAssetManifest.new(%{
              "/cheatsheets/git/images/git log.png" => "git log-6f7a8b.png"
            })
        )

      assert Urls.resolve(context, {:page_asset, {:cheatsheet, "git"}, "images/git log.png"}) ==
               {:ok, "images/git%20log-6f7a8b.png"}
    end

    test "reports an asset that is not in the manifest" do
      document =
        CourseSiteFactory.build(:document_ref, num: 507, slug: "dns", type: :subject)

      context = CourseSiteFactory.build(:url_context, page_assets: PageAssetManifest.new(%{}))

      assert Urls.resolve(context, {:page_asset, {:document, document}, "images/typo.png"}) ==
               {:error,
                {:unknown_page_asset, {:document, document}, "images/typo.png",
                 "/course/507-dns/images/typo.png"}}
    end

    test "reports an asset referenced from the site's root" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(
               context,
               {:page_asset, {:cheatsheet, "docker"}, "/assets/theme/theme.css"}
             ) ==
               {:error,
                {:absolute_page_asset, {:cheatsheet, "docker"}, "/assets/theme/theme.css"}}
    end

    test "reports an asset referenced by an absolute URL" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(
               context,
               {:page_asset, {:cheatsheet, "docker"}, "https://example.com/whale.png"}
             ) ==
               {:error,
                {:absolute_page_asset, {:cheatsheet, "docker"}, "https://example.com/whale.png"}}
    end

    test "reports an asset referenced with a query string" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(context, {:page_asset, {:cheatsheet, "git"}, "images/log.png?v=2"}) ==
               {:error, {:invalid_page_asset, {:cheatsheet, "git"}, "images/log.png?v=2"}}
    end

    test "reports an asset pointing outside the site" do
      document =
        CourseSiteFactory.build(:document_ref, num: 104, slug: "ssh", type: :subject)

      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(
               context,
               {:page_asset, {:document, document}, "../../../images/key.png"}
             ) ==
               {:error,
                {:page_asset_outside_site, {:document, document}, "../../../images/key.png"}}
    end
  end

  describe "resolve/3 with :asset" do
    test "resolves to the digested path under the edition prefix" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "",
          version: "2026",
          assets:
            AssetManifest.new(%{"/assets/theme/theme.css" => "/assets/theme/theme-1a2b3c.css"})
        )

      assert Urls.resolve(context, {:asset, "/assets/theme/theme.css"}) ==
               {:ok, "/2026/assets/theme/theme-1a2b3c.css"}
    end

    test "resolves under the mount point and the edition prefix" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "/website",
          version: "2026",
          assets: AssetManifest.new(%{"/assets/app/app.js" => "/assets/app/app-4d5e6f.js"})
        )

      assert Urls.resolve(context, {:asset, "/assets/app/app.js"}) ==
               {:ok, "/website/2026/assets/app/app-4d5e6f.js"}
    end

    test "stays relative to the build even when content links are absolutized" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "",
          version: "2026",
          absolute_base_url: "https://archidep.example.com",
          assets:
            AssetManifest.new(%{"/assets/search/search.js" => "/assets/search/search-8b9c0d.js"})
        )

      assert Urls.resolve(context, {:asset, "/assets/search/search.js"}) ==
               {:ok, "/2026/assets/search/search-8b9c0d.js"}
    end

    test "reports an asset that is not in the manifest" do
      context = CourseSiteFactory.build(:url_context, assets: AssetManifest.new(%{}))

      assert Urls.resolve(context, {:asset, "/assets/course/course.js"}) ==
               {:error, {:unknown_asset, "/assets/course/course.js"}}
    end
  end

  describe "resolve/3 with :build_file" do
    test "names the file after the build that produced it" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "",
          version: "2026",
          build_id: "5e6f7a"
        )

      assert Urls.resolve(context, {:build_file, "lunr.json"}) ==
               {:ok, "/2026/lunr-5e6f7a.json"}
    end

    test "names the file under the mount point and the edition prefix" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "/website",
          version: "2025",
          build_id: "8a9b0c"
        )

      assert Urls.resolve(context, {:build_file, "search.json"}) ==
               {:ok, "/website/2025/search-8a9b0c.json"}
    end
  end

  describe "resolve/3 with :site_file" do
    test "resolves under the edition prefix without a build ID" do
      context =
        CourseSiteFactory.build(:url_context, base_path: "", version: "2026")

      assert Urls.resolve(context, {:site_file, "archidep.json"}) ==
               {:ok, "/2026/archidep.json"}
    end

    test "resolves under the mount point and the edition prefix" do
      context = CourseSiteFactory.build(:url_context, base_path: "/website", version: "2026")

      assert Urls.resolve(context, {:site_file, "version.json"}) ==
               {:ok, "/website/2026/version.json"}
    end
  end

  describe "resolve/3 with :root_file" do
    test "resolves at the host's root when the site is not mounted under a path" do
      context = CourseSiteFactory.build(:url_context, base_path: "", version: "2026")

      assert Urls.resolve(context, {:root_file, "favicon.ico"}) == {:ok, "/favicon.ico"}
    end

    test "resolves under the mount point but never under the edition prefix" do
      context = CourseSiteFactory.build(:url_context, base_path: "/website", version: "2026")

      assert Urls.resolve(context, {:root_file, "robots.txt"}) == {:ok, "/website/robots.txt"}
    end
  end

  describe "resolve/3 with :pdf" do
    test "resolves a PDF published alongside the site" do
      document =
        CourseSiteFactory.build(:document_ref, num: 202, slug: "git-branching", type: :slides)

      context =
        CourseSiteFactory.build(:url_context,
          base_path: "",
          version: "2026",
          pdfs:
            PdfManifest.new(:site, %{
              {:document, document} => "archidep-202-git-branching-slides.pdf"
            })
        )

      assert Urls.resolve(context, {:pdf, {:document, document}}) ==
               {:ok, "/2026/pdf/archidep-202-git-branching-slides.pdf"}
    end

    test "resolves a PDF whose name a URL cannot carry as it is" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "",
          version: "2026",
          pdfs: PdfManifest.new(:site, %{home: "ArchiDep 000 - Course.pdf"})
        )

      assert Urls.resolve(context, {:pdf, :home}) ==
               {:ok, "/2026/pdf/ArchiDep%20000%20-%20Course.pdf"}
    end

    test "resolves a PDF published under an absolute base URL" do
      context =
        CourseSiteFactory.build(:url_context,
          base_path: "/website",
          version: "2026",
          pdfs:
            PdfManifest.new({:external, "https://pdfs.example.com/2026"}, %{
              {:cheatsheet, "docker"} => "archidep-999-docker.pdf"
            })
        )

      assert Urls.resolve(context, {:pdf, {:cheatsheet, "docker"}}) ==
               {:ok, "https://pdfs.example.com/2026/archidep-999-docker.pdf"}
    end

    test "resolves a PDF published at a URL of its own, which a host may have renamed" do
      context =
        CourseSiteFactory.build(:url_context,
          pdfs:
            PdfManifest.new({:external, "https://example.com/releases/pdf-2026"}, %{
              {:cheatsheet, "git"} =>
                {:url, "https://example.com/releases/pdf-2026/archidep-999-git.1.pdf"}
            })
        )

      assert Urls.resolve(context, {:pdf, {:cheatsheet, "git"}}) ==
               {:ok, "https://example.com/releases/pdf-2026/archidep-999-git.1.pdf"}
    end

    test "reports a page whose PDF has not been published" do
      document =
        CourseSiteFactory.build(:document_ref, num: 704, slug: "render-deployment", type: :slides)

      context = CourseSiteFactory.build(:url_context, pdfs: PdfManifest.new(:site, %{}))

      assert Urls.resolve(context, {:pdf, {:document, document}}) ==
               {:error, {:unknown_pdf, {:document, document}}}
    end
  end

  describe "resolve/3 with :live_site" do
    test "resolves a page of a backup copy to the same page on the live site" do
      document =
        CourseSiteFactory.build(:document_ref, num: 104, slug: "ssh", type: :subject)

      context =
        CourseSiteFactory.build(:url_context,
          mode: :backup,
          base_path: "/website",
          version: "2026",
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:live_site, {:document, document}}) ==
               {:ok, "https://archidep.example.com/2026/course/104-ssh/"}
    end

    test "resolves the home page of a backup copy to the live site's home page" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :backup,
          base_path: "/website",
          version: nil,
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:live_site, :home}) == {:ok, "https://archidep.example.com/"}
    end

    test "resolves the home page of a backup copy of an edition being taught to the mount point of the live site" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :backup,
          base_path: "/website",
          version: "2026",
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:live_site, :home}) == {:ok, "https://archidep.example.com/"}
    end

    test "resolves the home page of an archived edition to that edition's home page on the live site" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :archive,
          base_path: "/website",
          version: "2025",
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:live_site, :home}) ==
               {:ok, "https://archidep.example.com/2025/"}
    end

    test "reports a build that does not know where the live site is" do
      context = CourseSiteFactory.build(:url_context, live_site_url: nil)

      assert Urls.resolve(context, {:live_site, :home}) ==
               {:error, {:missing_live_site_url, {:live_site, :home}}}
    end
  end

  describe "resolve/3 with :current_edition" do
    test "resolves an archived page to the application route that resolves it" do
      document =
        CourseSiteFactory.build(:document_ref, num: 104, slug: "ssh", type: :subject)

      context =
        CourseSiteFactory.build(:url_context,
          mode: :archive,
          base_path: "/website",
          version: "2025",
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:current_edition, {:document, document}}) ==
               {:ok, "https://archidep.example.com/latest?to=/2025/course/104-ssh/"}
    end

    test "names the archived page by the path it has on the live site, whatever mounts this copy" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :archive,
          base_path: "/website",
          version: "2025",
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:current_edition, :home}) ==
               {:ok, "https://archidep.example.com/latest?to=/2025/"}
    end

    test "reports a build that has no edition to resolve from" do
      context =
        CourseSiteFactory.build(:url_context,
          mode: :backup,
          version: nil,
          live_site_url: "https://archidep.example.com"
        )

      assert Urls.resolve(context, {:current_edition, :home}) ==
               {:error, {:missing_version, {:current_edition, :home}}}
    end
  end

  describe "resolve/3 with :external" do
    test "resolves an absolute URL unchanged" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(context, {:external, "https://azure.microsoft.com/"}) ==
               {:ok, "https://azure.microsoft.com/"}
    end

    test "resolves a mail address unchanged" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(context, {:external, "mailto:teacher@example.com"}) ==
               {:ok, "mailto:teacher@example.com"}
    end
  end

  describe "external?/2" do
    test "says a URL of another site points away from this one" do
      context = CourseSiteFactory.build(:url_context, absolute_base_url: nil)

      assert Urls.external?(context, "https://man7.org/linux/man-pages/") == true
    end

    test "says a URL of another site points away from this one whatever it is written as" do
      context = CourseSiteFactory.build(:url_context, absolute_base_url: nil)

      assert Urls.external?(context, "//man7.org/linux/man-pages/") == true
    end

    test "says a path of this site does not point away from it" do
      context = CourseSiteFactory.build(:url_context, absolute_base_url: nil)

      assert Urls.external?(context, "/2026/course/104-ssh/") == false
    end

    test "says a fragment does not point away from the page it is on" do
      context = CourseSiteFactory.build(:url_context, absolute_base_url: nil)

      assert Urls.external?(context, "#create-your-server") == false
    end

    test "says an address that is not a site's does not point at another site" do
      context = CourseSiteFactory.build(:url_context, absolute_base_url: nil)

      assert Urls.external?(context, "mailto:contact@archidep.ch") == false
    end

    test "says a URL of this site does not point away from it, in a build writing URLs in full" do
      context =
        CourseSiteFactory.build(:url_context, absolute_base_url: "https://archidep.example.com")

      assert Urls.external?(context, "https://archidep.example.com/2026/course/104-ssh/") == false
    end

    test "says a URL of this site does not point away from it whatever its case" do
      context =
        CourseSiteFactory.build(:url_context, absolute_base_url: "https://archidep.example.com")

      assert Urls.external?(context, "https://ArchiDep.Example.com/2026/") == false
    end

    test "says another site's URL points away from a build writing URLs in full" do
      context =
        CourseSiteFactory.build(:url_context, absolute_base_url: "https://archidep.example.com")

      assert Urls.external?(context, "https://backup.example.com/2026/") == true
    end

    test "says a URL of this site points away from a build that has no address of its own" do
      context = CourseSiteFactory.build(:url_context, absolute_base_url: nil)

      assert Urls.external?(context, "https://archidep.example.com/2026/") == true
    end
  end

  describe "resolve/3 with an unknown reference" do
    test "reports the reference" do
      context = CourseSiteFactory.build(:url_context)

      assert Urls.resolve(context, {:progress, "2026-02-13"}) ==
               {:error, {:invalid_reference, {:progress, "2026-02-13"}}}
    end
  end

  describe "resolve!/3" do
    test "returns the URL of a resolvable reference" do
      context =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2026")

      assert Urls.resolve!(context, {:cheatsheet, "command-line"}) ==
               "/2026/cheatsheets/command-line/"
    end

    test "raises for a reference that cannot be resolved" do
      context = CourseSiteFactory.build(:url_context, assets: AssetManifest.new(%{}))

      assert_raise UrlError,
                   "Global asset \"/assets/theme/slides.css\" is not in the asset manifest",
                   fn -> Urls.resolve!(context, {:asset, "/assets/theme/slides.css"}) end
    end
  end

  describe "format_error/1" do
    test "describes a global asset missing from the manifest" do
      assert Urls.format_error({:unknown_asset, "/assets/course/course.js"}) ==
               "Global asset \"/assets/course/course.js\" is not in the asset manifest"
    end

    test "describes a page asset missing from the manifest, and where it was looked for" do
      page = {:document, DocumentRef.new(507, "dns", :subject)}

      assert Urls.format_error(
               {:unknown_page_asset, page, "images/typo.png", "/course/507-dns/images/typo.png"}
             ) ==
               "Page asset \"images/typo.png\" of page 507-dns (subject) is not in the page asset manifest (looked for \"/course/507-dns/images/typo.png\")"
    end

    test "describes a page whose PDF has not been published" do
      assert Urls.format_error({:unknown_pdf, {:cheatsheet, "sysadmin"}}) ==
               "No PDF has been published for page the sysadmin cheatsheet"
    end

    test "describes a page asset that is not relative to its page" do
      assert Urls.format_error({:absolute_page_asset, :home, "/images/logo.png"}) ==
               "Page asset \"/images/logo.png\" of page the home page must be relative to the page; use an {:asset, path} reference for a global asset"
    end

    test "describes a page asset carrying a query string or a fragment" do
      assert Urls.format_error({:invalid_page_asset, {:cheatsheet, "git"}, "images/log.png?v=2"}) ==
               "Page asset \"images/log.png?v=2\" of page the git cheatsheet must not contain a query string or a fragment"
    end

    test "describes a page asset pointing outside the site" do
      page = {:document, DocumentRef.new(101, "command-line", :slides)}

      assert Urls.format_error({:page_asset_outside_site, page, "../../../images/tty.jpg"}) ==
               "Page asset \"../../../images/tty.jpg\" of page 101-command-line (slides) points outside the site's root"
    end

    test "describes a reference needing the live site's URL" do
      assert Urls.format_error({:missing_live_site_url, {:live_site, :home}}) ==
               "Reference {:live_site, :home} requires the URL of the current edition's site"
    end

    test "describes a reference needing an edition" do
      assert Urls.format_error({:missing_version, {:current_edition, :home}}) ==
               "Reference {:current_edition, :home} requires the build to have a version"
    end

    test "describes an unknown reference" do
      assert Urls.format_error({:invalid_reference, {:progress, "2026-02-13"}}) ==
               "{:progress, \"2026-02-13\"} is not a valid reference"
    end
  end

  describe "resolve/3 in every configuration a build is published under" do
    test "resolves every reference for the edition being taught" do
      assert resolve_all(
               mode: :live,
               base_path: "",
               version: "2026",
               absolute_base_url: nil
             ) == %{
               home: "/",
               document: "/2026/course/402-run-virtual-server/",
               slides: "/2026/course/401-cloud-computing/slides/",
               cheatsheet: "/2026/cheatsheets/sysadmin/",
               same_page_heading: "#create-your-server",
               other_page_heading: "/2026/course/402-run-virtual-server/#create-your-server",
               page_asset: "../images/cloud-9f8e7d.png",
               asset: "/2026/assets/theme/theme-1a2b3c.css",
               build_file: "/2026/lunr-abc123.json",
               site_file: "/2026/archidep.json",
               pdf: "/2026/pdf/archidep-103-hello-shell-exercise.pdf",
               root_file: "/favicon.ico",
               live_site: "https://archidep.example.com/2026/course/104-ssh/",
               current_edition: "https://archidep.example.com/latest?to=/2026/course/104-ssh/",
               external: "https://azure.microsoft.com/"
             }
    end

    test "resolves every reference for a backup copy of that edition" do
      assert resolve_all(
               mode: :backup,
               base_path: "/website",
               version: "2026",
               absolute_base_url: nil
             ) == %{
               home: "/website/",
               document: "/website/2026/course/402-run-virtual-server/",
               slides: "/website/2026/course/401-cloud-computing/slides/",
               cheatsheet: "/website/2026/cheatsheets/sysadmin/",
               same_page_heading: "#create-your-server",
               other_page_heading:
                 "/website/2026/course/402-run-virtual-server/#create-your-server",
               page_asset: "../images/cloud-9f8e7d.png",
               asset: "/website/2026/assets/theme/theme-1a2b3c.css",
               build_file: "/website/2026/lunr-abc123.json",
               site_file: "/website/2026/archidep.json",
               pdf: "/website/2026/pdf/archidep-103-hello-shell-exercise.pdf",
               root_file: "/website/favicon.ico",
               live_site: "https://archidep.example.com/2026/course/104-ssh/",
               current_edition: "https://archidep.example.com/latest?to=/2026/course/104-ssh/",
               external: "https://azure.microsoft.com/"
             }
    end

    test "resolves every reference for an archived edition on the main site" do
      assert resolve_all(
               mode: :archive,
               base_path: "",
               version: "2025",
               absolute_base_url: nil
             ) == %{
               home: "/2025/",
               document: "/2025/course/402-run-virtual-server/",
               slides: "/2025/course/401-cloud-computing/slides/",
               cheatsheet: "/2025/cheatsheets/sysadmin/",
               same_page_heading: "#create-your-server",
               other_page_heading: "/2025/course/402-run-virtual-server/#create-your-server",
               page_asset: "../images/cloud-9f8e7d.png",
               asset: "/2025/assets/theme/theme-1a2b3c.css",
               build_file: "/2025/lunr-abc123.json",
               site_file: "/2025/archidep.json",
               pdf: "/2025/pdf/archidep-103-hello-shell-exercise.pdf",
               root_file: "/favicon.ico",
               live_site: "https://archidep.example.com/2025/course/104-ssh/",
               current_edition: "https://archidep.example.com/latest?to=/2025/course/104-ssh/",
               external: "https://azure.microsoft.com/"
             }
    end

    test "resolves every reference for an archived edition of a backup copy" do
      assert resolve_all(
               mode: :archive,
               base_path: "/website",
               version: "2025",
               absolute_base_url: nil
             ) == %{
               home: "/website/2025/",
               document: "/website/2025/course/402-run-virtual-server/",
               slides: "/website/2025/course/401-cloud-computing/slides/",
               cheatsheet: "/website/2025/cheatsheets/sysadmin/",
               same_page_heading: "#create-your-server",
               other_page_heading:
                 "/website/2025/course/402-run-virtual-server/#create-your-server",
               page_asset: "../images/cloud-9f8e7d.png",
               asset: "/website/2025/assets/theme/theme-1a2b3c.css",
               build_file: "/website/2025/lunr-abc123.json",
               site_file: "/website/2025/archidep.json",
               pdf: "/website/2025/pdf/archidep-103-hello-shell-exercise.pdf",
               root_file: "/website/favicon.ico",
               live_site: "https://archidep.example.com/2025/course/104-ssh/",
               current_edition: "https://archidep.example.com/latest?to=/2025/course/104-ssh/",
               external: "https://azure.microsoft.com/"
             }
    end

    test "resolves every reference for a build printed to PDF" do
      assert resolve_all(
               mode: :live,
               base_path: "",
               version: "2026",
               absolute_base_url: "https://archidep.example.com"
             ) == %{
               home: "https://archidep.example.com/",
               document: "https://archidep.example.com/2026/course/402-run-virtual-server/",
               slides: "https://archidep.example.com/2026/course/401-cloud-computing/slides/",
               cheatsheet: "https://archidep.example.com/2026/cheatsheets/sysadmin/",
               same_page_heading: "#create-your-server",
               other_page_heading:
                 "https://archidep.example.com/2026/course/402-run-virtual-server/#create-your-server",
               page_asset: "../images/cloud-9f8e7d.png",
               asset: "/2026/assets/theme/theme-1a2b3c.css",
               build_file: "/2026/lunr-abc123.json",
               site_file: "/2026/archidep.json",
               pdf: "/2026/pdf/archidep-103-hello-shell-exercise.pdf",
               root_file: "/favicon.ico",
               live_site: "https://archidep.example.com/2026/course/104-ssh/",
               current_edition: "https://archidep.example.com/latest?to=/2026/course/104-ssh/",
               external: "https://azure.microsoft.com/"
             }
    end
  end

  describe "resolve/3 invariants" do
    property "an asset next to a page is unaffected by how the build is published" do
      page_assets =
        PageAssetManifest.new(%{"/course/403-docker/images/whale.png" => "whale-3c4d5e.png"})

      reference =
        {:page_asset, {:document, DocumentRef.new(403, "docker", :slides)}, "../images/whale.png"}

      check all %UrlContext{} = one <- CourseSiteFactory.url_context_generator(),
                %UrlContext{} = other <- CourseSiteFactory.url_context_generator() do
        assert Urls.resolve(%{one | page_assets: page_assets}, reference) ==
                 Urls.resolve(%{other | page_assets: page_assets}, reference)
      end
    end

    property "resolving an asset next to a page again is resolving it once" do
      page_assets =
        PageAssetManifest.new(%{
          "/course/509-reverse-proxy/images/nginx.png" => "nginx-7a8b9c.png"
        })

      page = {:document, DocumentRef.new(509, "reverse-proxy", :slides)}

      check all %UrlContext{} = generated <- CourseSiteFactory.url_context_generator() do
        context = %{generated | page_assets: page_assets}

        {:ok, url} = Urls.resolve(context, {:page_asset, page, "../images/nginx.png"})

        assert Urls.resolve(context, {:page_asset, page, url}) == {:ok, url}
      end
    end

    property "a global asset is never absolutized" do
      assets = AssetManifest.new(%{"/assets/app/app.js" => "/assets/app/app-4d5e6f.js"})
      reference = {:asset, "/assets/app/app.js"}

      check all %UrlContext{} = generated <- CourseSiteFactory.url_context_generator() do
        context = %{generated | assets: assets}
        local = %{context | absolute_base_url: nil}

        assert Urls.resolve(context, reference) == Urls.resolve(local, reference)
      end
    end

    property "a heading of the page being rendered is a bare fragment" do
      check all context <- CourseSiteFactory.url_context_generator(),
                page <- CourseSiteFactory.page_ref_generator(),
                id <- string(:alphanumeric, min_length: 1) do
        assert Urls.resolve(context, {:heading, page, id}, page) == {:ok, "##{id}"}
      end
    end

    property "every reference resolves to an already normalized path" do
      check all %UrlContext{} = generated <- CourseSiteFactory.url_context_generator(),
                page <- CourseSiteFactory.page_ref_generator(),
                reference <- prefixed_reference(page) do
        context = %{
          generated
          | assets: AssetManifest.new(%{"/assets/app/app.js" => "/assets/app/app-4d5e6f.js"}),
            pdfs: PdfManifest.new(:site, %{page => "archidep-103-hello-shell-exercise.pdf"})
        }

        {:ok, url} = Urls.resolve(context, reference)
        path = URI.parse(url).path

        assert UrlPath.normalize(path) == {:ok, path}
      end
    end
  end

  defp resolve_all(opts) do
    document = DocumentRef.new(402, "run-virtual-server", :exercise)
    slides = DocumentRef.new(401, "cloud-computing", :slides)
    ssh = DocumentRef.new(104, "ssh", :subject)
    hello_shell = DocumentRef.new(103, "hello-shell", :exercise)

    context =
      UrlContext.new(
        Keyword.merge(opts,
          build_id: "abc123",
          live_site_url: "https://archidep.example.com",
          assets:
            AssetManifest.new(%{"/assets/theme/theme.css" => "/assets/theme/theme-1a2b3c.css"}),
          page_assets:
            PageAssetManifest.new(%{
              "/course/401-cloud-computing/images/cloud.png" => "cloud-9f8e7d.png"
            }),
          pdfs:
            PdfManifest.new(:site, %{
              {:document, hello_shell} => "archidep-103-hello-shell-exercise.pdf"
            })
        )
      )

    %{
      home: Urls.resolve!(context, :home),
      document: Urls.resolve!(context, {:document, document}),
      slides: Urls.resolve!(context, {:document, slides}),
      cheatsheet: Urls.resolve!(context, {:cheatsheet, "sysadmin"}),
      same_page_heading:
        Urls.resolve!(
          context,
          {:heading, {:document, document}, "create-your-server"},
          {:document, document}
        ),
      other_page_heading:
        Urls.resolve!(
          context,
          {:heading, {:document, document}, "create-your-server"},
          {:document, ssh}
        ),
      page_asset:
        Urls.resolve!(context, {:page_asset, {:document, slides}, "../images/cloud.png"}),
      asset: Urls.resolve!(context, {:asset, "/assets/theme/theme.css"}),
      build_file: Urls.resolve!(context, {:build_file, "lunr.json"}),
      site_file: Urls.resolve!(context, {:site_file, "archidep.json"}),
      pdf: Urls.resolve!(context, {:pdf, {:document, hello_shell}}),
      root_file: Urls.resolve!(context, {:root_file, "favicon.ico"}),
      live_site: Urls.resolve!(context, {:live_site, {:document, ssh}}),
      current_edition: Urls.resolve!(context, {:current_edition, {:document, ssh}}),
      external: Urls.resolve!(context, {:external, "https://azure.microsoft.com/"})
    }
  end

  defp prefixed_reference(page) do
    one_of([
      constant(:home),
      constant({:cheatsheet, "sysadmin"}),
      constant({:asset, "/assets/app/app.js"}),
      constant({:build_file, "lunr.json"}),
      constant({:site_file, "archidep.json"}),
      constant({:root_file, "favicon.ico"}),
      constant({:pdf, page}),
      map(CourseSiteFactory.document_ref_generator(), &{:document, &1}),
      map(string(:alphanumeric, min_length: 1), &{:heading, page, &1})
    ])
  end
end
