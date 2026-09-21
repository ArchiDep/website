defmodule ArchiDep.CourseSite.Build.SiteTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.Build.PdfNames
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
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.Support.CourseSiteTestLayout

  @cli_subject DocumentRef.new(101, "command-line", :subject)
  @cli_slides DocumentRef.new(101, "command-line", :slides)
  @todolist DocumentRef.new(205, "php-todolist", :exercise)
  @branching DocumentRef.new(202, "git-branching", :slides)

  describe "plan/2" do
    test "plans a file for every page of the course, and the four it writes of its own" do
      assert {:ok, site} = Site.plan(inputs(), options())

      assert site.files == %{
               "/index.html" =>
                 "/|index.md|Architecture & Deployment · ArchiDep|||Session|page:::<p>Welcome.</p>",
               "/course/101-command-line/index.html" =>
                 "/course/101-command-line/|chapters/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>",
               "/course/101-command-line/slides/index.html" =>
                 "/course/101-command-line/slides/|chapters/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n",
               "/course/202-git-branching/slides/index.html" =>
                 "/course/202-git-branching/slides/|chapters/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n",
               "/course/205-php-todolist/index.html" =>
                 "/course/205-php-todolist/|chapters/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>",
               "/cheatsheets/git/index.html" =>
                 "/cheatsheets/git/|cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>",
               "/archidep.json" => archidep_json(),
               "/search-abc123.json" => search_json(),
               "/version.json" => version_json(),
               "/404.html" => not_found_html(),
               "/llms.txt" => llms_txt()
             }
    end

    test "says what every page's PDF is called whether or not the build publishes one" do
      published =
        PdfNames.manifest({:external, "https://example.com/pdf/2026"}, structure())

      assert {:ok, publishing} = Site.plan(inputs(), options(pdfs: published))
      assert {:ok, publishing_none} = Site.plan(inputs(), options())

      assert publishing.files == publishing_none.files
    end

    test "says where things are in this build, whatever its pages say they link to" do
      absolute = "https://archidep.example.com"

      assert {:ok, printed} = Site.plan(inputs(), options(absolute_base_url: absolute))
      assert {:ok, served} = Site.plan(inputs(), options())

      assert printed == %{
               served
               | files: %{served.files | "/404.html" => not_found_html(absolute <> "/")}
             }
    end

    test "writes no index for agents on a build that is not the live site" do
      options =
        options(mode: :backup, live_site_url: "https://archidep.example.com")

      assert {:ok, live} = Site.plan(inputs(), options())
      assert {:ok, backup} = Site.plan(inputs(), options)

      assert backup == %Site{
               live
               | files: %{
                   "/index.html" =>
                     "/|index.md|Architecture & Deployment · ArchiDep|||Session|page:::<p>Welcome.</p>",
                   "/course/101-command-line/index.html" =>
                     "/course/101-command-line/|chapters/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>",
                   "/course/101-command-line/slides/index.html" =>
                     "/course/101-command-line/slides/|chapters/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n",
                   "/course/202-git-branching/slides/index.html" =>
                     "/course/202-git-branching/slides/|chapters/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n",
                   "/course/205-php-todolist/index.html" =>
                     "/course/205-php-todolist/|chapters/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>",
                   "/cheatsheets/git/index.html" =>
                     "/cheatsheets/git/|cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>",
                   "/archidep.json" => archidep_json(),
                   "/search-abc123.json" => search_json(dashboard: false),
                   "/version.json" => version_json(),
                   "/404.html" => not_found_html()
                 }
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
                 "/course/101-command-line/|chapters/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>",
               "/course/101-command-line/slides/index.html" =>
                 "/course/101-command-line/slides/|chapters/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n",
               "/course/202-git-branching/slides/index.html" =>
                 "/course/202-git-branching/slides/|chapters/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n",
               "/course/205-php-todolist/index.html" =>
                 "/course/205-php-todolist/|chapters/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>",
               "/cheatsheets/git/index.html" =>
                 "/cheatsheets/git/|cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>",
               "/favicon.ico" => "the mark",
               "/favicons/heig.png" => "the school's mark",
               "/archidep.json" => archidep_json(),
               "/search-abc123.json" => search_json(),
               "/version.json" => version_json(),
               "/404.html" => not_found_html(),
               "/llms.txt" => llms_txt()
             }
    end

    test "publishes a chapter's tutor notes with the map of its page, linked from the index" do
      sources =
        Map.put(
          sources(),
          {:document, @todolist},
          source(
            "---\ntitle: PHP Todolist\ndescription: Deploy the PHP todolist.\n---\n\n" <>
              "Build it.\n\n## Troubleshooting\n\n### It fails\n"
          )
        )

      tutor_notes = %{
        "101-command-line" => "# Notes of 101\n",
        "202-git-branching" => "# Notes of 202\n",
        "205-php-todolist" => "# Notes of 205\n"
      }

      todolist_notes = """
      # Notes of 205

      ## Troubleshooting on the page

      The page's "Troubleshooting" section: https://archidep.ch/course/205-php-todolist/#troubleshooting

      Its entries, with their anchors on that page:

      - It fails (#it-fails)
      """

      assert {:ok, without_notes} = Site.plan(inputs(sources: sources), options())

      assert {:ok, with_notes} =
               Site.plan(inputs(sources: sources, tutor_notes: tutor_notes), options())

      assert with_notes == %Site{
               without_notes
               | files:
                   Map.merge(without_notes.files, %{
                     "/course/101-command-line/tutor-#{digest("# Notes of 101\n")}.md" =>
                       "# Notes of 101\n",
                     "/course/202-git-branching/tutor-#{digest("# Notes of 202\n")}.md" =>
                       "# Notes of 202\n",
                     "/course/205-php-todolist/tutor-#{digest(todolist_notes)}.md" =>
                       todolist_notes,
                     "/llms.txt" =>
                       llms_txt("""
                       ## 100 Introduction

                       - [101 Command Line](https://archidep.ch/course/101-command-line/): subject.
                         - Slides: https://archidep.ch/course/101-command-line/slides/
                         - Tutor notes: https://archidep.ch/course/101-command-line/tutor-#{digest("# Notes of 101\n")}.md

                       ## 200 Version Control

                       - [202 Git Branching](https://archidep.ch/course/202-git-branching/slides/): slides.
                         - Tutor notes: https://archidep.ch/course/202-git-branching/tutor-#{digest("# Notes of 202\n")}.md
                       - [205 PHP Todolist](https://archidep.ch/course/205-php-todolist/): exercise.
                         Deploy the PHP todolist.
                         - Tutor notes: https://archidep.ch/course/205-php-todolist/tutor-#{digest(todolist_notes)}.md
                       """)
                   })
             }
    end

    test "reports tutor notes it cannot publish" do
      tutor_notes = %{"205-php-todolist" => "# Notes\n\n## Troubleshooting on the page\n"}

      assert Site.plan(inputs(tutor_notes: tutor_notes), options()) ==
               {:error,
                [
                  {:invalid_tutor_notes, "chapters/205-php-todolist/tutor.md",
                   {:reserved_tutor_notes_heading, "## Troubleshooting on the page"}}
                ]}
    end

    test "hands the link check a deck as the Markdown it stays and as what was written" do
      assert {:ok, site} = Site.plan(inputs(), options())

      assert site.pages == [
               {:home, :html,
                "/|index.md|Architecture & Deployment · ArchiDep|||Session|page:::<p>Welcome.</p>"},
               {{:document, @cli_subject}, :html,
                "/course/101-command-line/|chapters/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|Session|page::what:<h2 id=\"what\">What<a href=\"#what\" aria-label=\"Link to heading 'What'\" data-heading-content=\"What\" class=\"anchor\"></a></h2>"},
               {{:document, @cli_slides}, :markdown, "# Command Line\n"},
               {{:document, @cli_slides}, :html,
                "/course/101-command-line/slides/|chapters/101-command-line/slides.md|Command Line Slides · ArchiDep|Command Line|Introduction|Session|deck:# Command Line\n"},
               {{:document, @branching}, :markdown, "# Branching\n"},
               {{:document, @branching}, :html,
                "/course/202-git-branching/slides/|chapters/202-git-branching/slides.md|Git Branching · ArchiDep|Git Branching|Version Control|Session|deck:# Branching\n"},
               {{:document, @todolist}, :html,
                "/course/205-php-todolist/|chapters/205-php-todolist/exercise.md|PHP Todolist · ArchiDep|PHP Todolist|Version Control|Session|page:::<p>Build it.</p>"},
               {{:cheatsheet, "git"}, :html,
                "/cheatsheets/git/|cheatsheets/git/cheatsheet.md|Git Cheatsheet · ArchiDep|Git Cheatsheet||Session|page:::<p>Commit.</p>"}
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
                  {:unrenderable_document, "chapters/101-command-line/subject.md",
                   %RenderError{
                     reason: {:invalid_page, "nope"},
                     source_path: "chapters/101-command-line/subject.md",
                     loc: %{line: 5, column: 1}
                   }},
                  {:unrenderable_document, "chapters/205-php-todolist/exercise.md",
                   %RenderError{
                     reason: {:invalid_page, "nope"},
                     source_path: "chapters/205-php-todolist/exercise.md",
                     loc: %{line: 5, column: 1}
                   }}
                ]}
    end
  end

  describe "format_error/1" do
    test "describes a document that could not be rendered" do
      error = %RenderError{
        reason: {:invalid_page, "nope"},
        source_path: "chapters/507-dns/subject.md",
        loc: %{line: 5, column: 1}
      }

      assert Site.format_error({:unrenderable_document, "chapters/507-dns/subject.md", error}) ==
               "Document chapters/507-dns/subject.md could not be rendered: " <>
                 RenderError.message(error)
    end

    test "describes tutor notes that could not be published" do
      assert Site.format_error(
               {:invalid_tutor_notes, "chapters/506-systemd-deployment/tutor.md",
                {:reserved_tutor_notes_heading, "## Troubleshooting on the page"}}
             ) ==
               ~s{Tutor notes chapters/506-systemd-deployment/tutor.md could not be published: Tutor notes must not write the heading "## Troubleshooting on the page", which the build adds}
    end

    test "describes a page that could not be laid out" do
      assert Site.format_error(
               {:unlayoutable_page, {:cheatsheet, "git"}, {:unknown_asset, "/assets/missing.css"}}
             ) ==
               ~s{Page /cheatsheets/git/ could not be laid out: Global asset "/assets/missing.css" is not in the asset manifest}
    end
  end

  defp digest(text), do: :md5 |> :crypto.hash(text) |> Base.encode16(case: :lower)

  defp inputs(overrides \\ []) do
    tutor_notes = Keyword.get(overrides, :tutor_notes, %{})

    %Site.Inputs{
      tree: %ContentTree{
        tree()
        | tutor_notes:
            Map.new(tutor_notes, fn {dir, _text} -> {dir, "chapters/#{dir}/tutor.md"} end)
      },
      sources: Keyword.get(overrides, :sources, sources()),
      home_source_path: "index.md",
      structure: Keyword.get(overrides, :structure, structure()),
      progress: Progress.new([Session.new(~D[2026-02-02], "Session", [100, 101], [200], [202])]),
      includes: %{},
      root_files: Keyword.get(overrides, :root_files, %{}),
      assets: AssetManifest.new(%{}),
      page_assets: PageAssetManifest.new(%{}),
      tutor_notes: tutor_notes
    }
  end

  defp options(overrides \\ []) do
    Site.Options.new(
      urls:
        build(:url_context,
          mode: Keyword.get(overrides, :mode, :live),
          base_path: "",
          version: nil,
          build_id: "abc123",
          live_site_url: Keyword.get(overrides, :live_site_url),
          absolute_base_url: Keyword.get(overrides, :absolute_base_url),
          pdfs: Keyword.get(overrides, :pdfs, PdfManifest.new(:site, %{}))
        ),
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
        @cli_subject => "chapters/101-command-line/subject.md",
        @cli_slides => "chapters/101-command-line/slides.md",
        @branching => "chapters/202-git-branching/slides.md",
        @todolist => "chapters/205-php-todolist/exercise.md"
      },
      cheatsheets: %{"git" => "cheatsheets/git/cheatsheet.md"},
      page_assets: %{},
      tutor_notes: %{},
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
      {:document, @todolist} =>
        source(
          "---\ntitle: PHP Todolist\ndescription: Deploy the PHP todolist.\n---\n\nBuild it.\n"
        ),
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

  # The keys are stated in the order the file is expected to write them, so that
  # a build reordering them fails here.
  defp archidep_json do
    json(
      object(
        home: object(url: "/", pdf: "archidep-000-course.pdf"),
        sections: [
          object(
            title: "Introduction",
            slug: "introduction",
            num: 100,
            progress: "done",
            open: false,
            docs: [
              object(
                title: "Command Line",
                num: 101,
                course_type: "subject",
                graded: false,
                course_slug: "command-line",
                section: 1,
                section_chapter: 1,
                progress: "done",
                slides: true,
                url: "/course/101-command-line/",
                pdf: "archidep-101-command-line-subject.pdf",
                slides_pdf: "archidep-101-command-line-slides.pdf"
              )
            ]
          ),
          object(
            title: "Version Control",
            slug: "version-control",
            num: 200,
            progress: "due",
            open: true,
            docs: [
              object(
                title: "Git Branching",
                num: 202,
                course_type: "slides",
                graded: false,
                course_slug: "git-branching",
                section: 2,
                section_chapter: 2,
                progress: "next",
                slides: false,
                url: "/course/202-git-branching/slides/",
                pdf: "archidep-202-git-branching-slides.pdf",
                slides_pdf: nil
              ),
              object(
                title: "PHP Todolist",
                num: 205,
                course_type: "exercise",
                graded: false,
                course_slug: "php-todolist",
                section: 2,
                section_chapter: 5,
                progress: "future",
                slides: false,
                url: "/course/205-php-todolist/",
                pdf: "archidep-205-php-todolist-exercise.pdf",
                slides_pdf: nil
              )
            ]
          )
        ],
        cheatsheets: [
          object(
            title: "Git Cheatsheet",
            sidebar_title: "Git Cheatsheet",
            slug: "git",
            url: "/cheatsheets/git/",
            pdf: "archidep-999-git.pdf"
          )
        ]
      )
    )
  end

  defp search_json(opts \\ []) do
    pages = [
      object(
        id: "/",
        type: "home",
        url: "/",
        title: "Architecture & Deployment",
        subtitle: "Architecture & Deployment",
        text: "Welcome.",
        extraText: ""
      ),
      object(
        id: "/course/101-command-line/",
        type: "subject",
        url: "/course/101-command-line/",
        title: "Command Line",
        subtitle: "Command Line",
        text: "What",
        extraText: ""
      ),
      object(
        id: "/course/101-command-line/slides/",
        type: "slides",
        url: "/course/101-command-line/slides/",
        title: "Command Line Slides",
        subtitle: "Command Line Slides",
        text: "Command Line",
        extraText: ""
      ),
      object(
        id: "/course/202-git-branching/slides/",
        type: "slides",
        url: "/course/202-git-branching/slides/",
        title: "Git Branching",
        subtitle: "Git Branching",
        text: "Branching",
        extraText: ""
      ),
      object(
        id: "/course/205-php-todolist/",
        type: "exercise",
        url: "/course/205-php-todolist/",
        title: "PHP Todolist",
        subtitle: "PHP Todolist",
        text: "Build it.",
        extraText: ""
      ),
      object(
        id: "/cheatsheets/git/",
        type: "cheatsheet",
        url: "/cheatsheets/git/",
        title: "Git Cheatsheet",
        subtitle: "Git Cheatsheet",
        text: "Commit.",
        extraText: ""
      )
    ]

    dashboard = [
      object(
        id: "/app",
        type: "dashboard",
        url: "/app",
        title: "Dashboard",
        subtitle: "User & server dashboard",
        text: "Manage your user account for the course and register a server for the exercises.",
        extraText: ""
      )
    ]

    json(if Keyword.get(opts, :dashboard, true), do: pages ++ dashboard, else: pages)
  end

  defp llms_txt(chapters \\ nil) do
    chapters =
      chapters ||
        """
        ## 100 Introduction

        - [101 Command Line](https://archidep.ch/course/101-command-line/): subject.
          - Slides: https://archidep.ch/course/101-command-line/slides/

        ## 200 Version Control

        - [202 Git Branching](https://archidep.ch/course/202-git-branching/slides/): slides.
        - [205 PHP Todolist](https://archidep.ch/course/205-php-todolist/): exercise.
          Deploy the PHP todolist.
        """

    """
    # ArchiDep

    > The course material of ArchiDep, the media engineering architecture and
    > deployment course, 2025-2026 edition.

    Home page: https://archidep.ch/

    This index lists the chapters of the edition being taught. Past editions stay
    published under their own year and are not listed here.

    A chapter is identified by its number: the number of its section, a multiple of
    100, plus its place in that section (402 is the second chapter of section 400).
    How far the class has got is published at https://archidep.ch/api/progress as a
    list of sessions, each recording the section and chapter numbers it finished
    (`done`), set work on (`due`) and announced for next time (`next`). A number's
    state is the furthest any session gives it: `done` if any session lists it as
    done, otherwise `due`, otherwise `next`; a number no session lists has not been
    reached yet. A session is recorded on the day it is taught, but what it covered
    may only be filled in at the end of that day. Chapters not reached yet are still
    being written: they may be renumbered, renamed, rewritten or removed before they
    are taught, so only what has been taught is final.

    In the course pages, `jde` stands for the student's own username and `W.X.Y.Z`
    for the IP address of their server. An exercise's headings are marked with a
    picture: ❗ a step the student must do, ❓ an optional one, 👾 a challenge to go
    further, 🏁 the end of the exercise, 🏛️ the architecture of what it deployed, and
    💥 troubleshooting. An exercise's "Requirements" section, when it has one, names
    the earlier exercises whose results it builds on, and its "Troubleshooting"
    section, when it has one, the problems students are known to run into and how to
    fix them. An exercise's solutions are left out of its page until the class has
    finished its chapter (`done`). Some values, such as the details of a student's
    server, are only shown in the browser of a logged-in student.

    Some chapters have tutor notes, written for an AI tutor helping a student
    through the chapter: what it teaches, where students usually get stuck, hints,
    and the questions worth asking at its key steps. They are linked from the
    chapter's entry.

    Built from revision abc123.

    #{chapters}
    ## Cheatsheets

    - [Git Cheatsheet](https://archidep.ch/cheatsheets/git/)
    """
  end

  defp version_json do
    json(object(version: "1.2.3", git: object(branch: "main", revision: "abc123")))
  end

  defp object(pairs), do: Jason.OrderedObject.new(pairs)

  defp json(term), do: Jason.encode!(term) <> "\n"

  defp not_found_html(home_url \\ "/") do
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
    <p><a href="#{home_url}">Back to the course</a></p>
    </main>
    </body>
    </html>
    """
  end
end
