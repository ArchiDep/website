defmodule ArchiDep.CourseSite.Build.SiteTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.Support.CourseSiteTestLayout

  @cli_subject DocumentRef.new(101, "command-line", :subject)
  @cli_slides DocumentRef.new(101, "command-line", :slides)
  @todolist DocumentRef.new(205, "php-todolist", :exercise)
  @branching DocumentRef.new(202, "git-branching", :slides)

  describe "plan/2" do
    test "plans a file for every page of the course, and the three it writes of its own" do
      assert {:ok, site} = Site.plan(inputs(), options())

      assert site.files == %{
               "/index.html" =>
                 "/|index.md|Architecture & Deployment · ArchiDep|||Session|page:::<p>Welcome.</p>",
               "/course/101-command-line/index.html" =>
                 "/course/101-command-line/|_course/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>",
               "/course/101-command-line/slides/index.html" =>
                 "/course/101-command-line/slides/|_course/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n",
               "/course/202-git-branching/slides/index.html" =>
                 "/course/202-git-branching/slides/|_course/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n",
               "/course/205-php-todolist/index.html" =>
                 "/course/205-php-todolist/|_course/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>",
               "/cheatsheets/git/index.html" =>
                 "/cheatsheets/git/|_cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>",
               "/archidep.json" => archidep_json(),
               "/version.json" => version_json(),
               "/404.html" => not_found_html()
             }
    end

    test "plans the files anchored at the mount point, which cannot shadow its own" do
      root_files = %{
        "/favicon.ico" => "the mark",
        "/favicons/heig.png" => "the school's mark",
        "/version.json" => "a course directory claiming to say what produced the build"
      }

      assert {:ok, site} = Site.plan(inputs(root_files: root_files), options())

      assert site.files == %{
               "/index.html" =>
                 "/|index.md|Architecture & Deployment · ArchiDep|||Session|page:::<p>Welcome.</p>",
               "/course/101-command-line/index.html" =>
                 "/course/101-command-line/|_course/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>",
               "/course/101-command-line/slides/index.html" =>
                 "/course/101-command-line/slides/|_course/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n",
               "/course/202-git-branching/slides/index.html" =>
                 "/course/202-git-branching/slides/|_course/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n",
               "/course/205-php-todolist/index.html" =>
                 "/course/205-php-todolist/|_course/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>",
               "/cheatsheets/git/index.html" =>
                 "/cheatsheets/git/|_cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>",
               "/favicon.ico" => "the mark",
               "/favicons/heig.png" => "the school's mark",
               "/archidep.json" => archidep_json(),
               "/version.json" => version_json(),
               "/404.html" => not_found_html()
             }
    end

    test "hands the link check a deck as the Markdown it stays and as what was written" do
      assert {:ok, site} = Site.plan(inputs(), options())

      assert site.pages == [
               {:home, :html,
                "/|index.md|Architecture & Deployment · ArchiDep|||Session|page:::<p>Welcome.</p>"},
               {{:document, @cli_subject}, :html,
                "/course/101-command-line/|_course/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>"},
               {{:document, @cli_slides}, :markdown, "# Command Line\n"},
               {{:document, @cli_slides}, :html,
                "/course/101-command-line/slides/|_course/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n"},
               {{:document, @branching}, :markdown, "# Branching\n"},
               {{:document, @branching}, :html,
                "/course/202-git-branching/slides/|_course/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n"},
               {{:document, @todolist}, :html,
                "/course/205-php-todolist/|_course/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>"},
               {{:cheatsheet, "git"}, :html,
                "/cheatsheets/git/|_cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>"}
             ]
    end

    test "reports every page whose layout could not resolve a reference of its own" do
      assert Site.plan(inputs(), options(layout: CourseSiteTestLayout.Failing)) ==
               {:error,
                [
                  {:unlayoutable_page, :home, {:unknown_asset, "/assets/missing.css"}},
                  {:unlayoutable_page, {:cheatsheet, "git"},
                   {:unknown_asset, "/assets/missing.css"}},
                  {:unlayoutable_page, {:document, @cli_slides},
                   {:unknown_asset, "/assets/missing.css"}},
                  {:unlayoutable_page, {:document, @cli_subject},
                   {:unknown_asset, "/assets/missing.css"}},
                  {:unlayoutable_page, {:document, @branching},
                   {:unknown_asset, "/assets/missing.css"}},
                  {:unlayoutable_page, {:document, @todolist},
                   {:unknown_asset, "/assets/missing.css"}}
                ]}
    end

    test "reports every document it cannot render rather than the first" do
      sources = %{
        :home => source("---\ntitle: Architecture & Deployment\n---\n\nWelcome.\n"),
        {:document, @cli_subject} => source("---\ntitle: Command Line\n---\n\n{% link nope %}\n"),
        {:document, @todolist} => source("---\ntitle: PHP Todolist\n---\n\n{% link nope %}\n")
      }

      assert Site.plan(inputs(sources: sources, structure: two_pages()), options()) ==
               {:error,
                [
                  {:unrenderable_document, "_course/101-command-line/subject.md",
                   %RenderError{
                     reason: {:invalid_document, "nope"},
                     source_path: "_course/101-command-line/subject.md",
                     loc: %{line: 5, column: 1}
                   }},
                  {:unrenderable_document, "_course/205-php-todolist/exercise.md",
                   %RenderError{
                     reason: {:invalid_document, "nope"},
                     source_path: "_course/205-php-todolist/exercise.md",
                     loc: %{line: 5, column: 1}
                   }}
                ]}
    end
  end

  describe "format_error/1" do
    test "describes a document that could not be rendered" do
      error = %RenderError{
        reason: {:invalid_document, "nope"},
        source_path: "_course/507-dns/subject.md",
        loc: %{line: 5, column: 1}
      }

      assert Site.format_error({:unrenderable_document, "_course/507-dns/subject.md", error}) ==
               "Document _course/507-dns/subject.md could not be rendered: " <>
                 RenderError.message(error)
    end

    test "describes a page that could not be laid out" do
      assert Site.format_error(
               {:unlayoutable_page, {:cheatsheet, "git"}, {:unknown_asset, "/assets/missing.css"}}
             ) ==
               ~s{Page /cheatsheets/git/ could not be laid out: Global asset "/assets/missing.css" is not in the asset manifest}
    end
  end

  defp inputs(overrides \\ []) do
    %Site.Inputs{
      tree: tree(),
      sources: Keyword.get(overrides, :sources, sources()),
      home_source_path: "index.md",
      structure: Keyword.get(overrides, :structure, structure()),
      progress: Progress.new([Session.new(~D[2026-02-02], "Session", [100, 101], [200], [202])]),
      includes: %{},
      root_files: Keyword.get(overrides, :root_files, %{}),
      assets: AssetManifest.new(%{}),
      page_assets: PageAssetManifest.new(%{})
    }
  end

  defp options(overrides \\ []) do
    Site.Options.new(
      urls: build(:url_context, mode: :live, base_path: "", version: nil, live_site_url: nil),
      site:
        SiteInfo.new(
          version: "1.2.3",
          git_branch: "main",
          git_revision: "abc123",
          years: "2025-2026",
          years_short: "25-26"
        ),
      layout: Keyword.get(overrides, :layout, CourseSiteTestLayout.Wrapper)
    )
  end

  defp tree do
    %ContentTree{
      documents: %{
        @cli_subject => "_course/101-command-line/subject.md",
        @cli_slides => "_course/101-command-line/slides.md",
        @branching => "_course/202-git-branching/slides.md",
        @todolist => "_course/205-php-todolist/exercise.md"
      },
      cheatsheets: %{"git" => "_cheatsheets/git/cheatsheet.md"},
      page_assets: %{},
      ignored: []
    }
  end

  defp sources do
    %{
      :home => source("---\ntitle: Architecture & Deployment\n---\n\nWelcome.\n"),
      {:document, @cli_subject} => source("---\ntitle: Command Line\n---\n\n## What\n"),
      {:document, @cli_slides} =>
        source("---\ntitle: Command Line Slides\n---\n\n# Command Line\n"),
      {:document, @branching} => source("---\ntitle: Git Branching\n---\n\n# Branching\n"),
      {:document, @todolist} => source("---\ntitle: PHP Todolist\n---\n\nBuild it.\n"),
      {:cheatsheet, "git"} => source("---\ntitle: Git Cheatsheet\n---\n\nCommit.\n")
    }
  end

  defp structure do
    %Structure{
      sections: [
        Section.new(1, "Introduction", [
          Chapter.new(@cli_subject, "Command Line", slides: @cli_slides)
        ]),
        Section.new(2, "Version Control", [
          Chapter.new(@branching, "Git Branching"),
          Chapter.new(@todolist, "PHP Todolist")
        ])
      ],
      cheatsheets: [Cheatsheet.new("git", "Git Cheatsheet")]
    }
  end

  defp two_pages do
    %Structure{
      sections: [
        Section.new(1, "Introduction", [Chapter.new(@cli_subject, "Command Line")]),
        Section.new(2, "Version Control", [Chapter.new(@todolist, "PHP Todolist")])
      ],
      cheatsheets: []
    }
  end

  defp source(contents) do
    {:ok, %Source{} = source} = Source.parse(contents)
    source
  end

  defp archidep_json do
    """
    {
      "sections": [
        {
          "title": "Introduction",
          "slug": "introduction",
          "num": 100,
          "progress": "done",
          "open": false,
          "docs": [
            {
              "title": "Command Line",
              "num": 101,
              "course_type": "subject",
              "graded": false,
              "course_slug": "command-line",
              "section": 1,
              "section_chapter": 1,
              "progress": "done",
              "slides": true,
              "url": "/course/101-command-line/"
            }
          ]
        },
        {
          "title": "Version Control",
          "slug": "version-control",
          "num": 200,
          "progress": "due",
          "open": true,
          "docs": [
            {
              "title": "Git Branching",
              "num": 202,
              "course_type": "slides",
              "graded": false,
              "course_slug": "git-branching",
              "section": 2,
              "section_chapter": 2,
              "progress": "next",
              "slides": false,
              "url": "/course/202-git-branching/slides/"
            },
            {
              "title": "PHP Todolist",
              "num": 205,
              "course_type": "exercise",
              "graded": false,
              "course_slug": "php-todolist",
              "section": 2,
              "section_chapter": 5,
              "progress": "future",
              "slides": false,
              "url": "/course/205-php-todolist/"
            }
          ]
        }
      ],
      "cheatsheets": [
        {
          "title": "Git Cheatsheet",
          "sidebar_title": "Git Cheatsheet",
          "slug": "git",
          "url": "/cheatsheets/git/"
        }
      ]
    }
    """
  end

  defp version_json do
    """
    {
      "version": "1.2.3",
      "git": {
        "branch": "main",
        "revision": "abc123"
      }
    }
    """
  end

  defp not_found_html do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="robots" content="noindex" />
    <title>Page not found · ArchiDep</title>
    <style>
    :root { color-scheme: light dark }
    body { display: flex; align-items: center; justify-content: center;
      min-height: 100vh; margin: 0; background: #eceff4; color: #2e3440;
      font-family: system-ui, sans-serif; line-height: 1.5 }
    main { max-width: 40rem; padding: 2rem; text-align: center }
    h1 { margin: 0 0 1rem; font-size: 4rem; line-height: 1; letter-spacing: -1px }
    @media (prefers-color-scheme: dark) {
      body { background: #0f172a; color: #b8c4d9 }
    }
    </style>
    </head>
    <body>
    <main>
    <h1>404</h1>
    <p><strong>Page not found :(</strong></p>
    <p>The requested page could not be found.</p>
    <p><a href="/">Back to the course</a></p>
    </main>
    </body>
    </html>
    """
  end
end
