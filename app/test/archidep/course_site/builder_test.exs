defmodule ArchiDep.CourseSite.BuilderTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Support.CourseSiteTestLayout

  @moduletag :tmp_dir

  # The files a build publishes at its mount point, which the course fixture
  # below writes with their own path as their content.
  @root_files [
    "favicon.ico",
    "favicons/archidep-512-flat.png",
    "favicons/archidep-coffee.png",
    "favicons/archidep-rocket-16.png",
    "favicons/archidep-rocket-180.png",
    "favicons/archidep-rocket-192.png",
    "favicons/archidep-rocket-32.png",
    "favicons/archidep-rocket-48.png",
    "favicons/archidep-rocket-96.png",
    "favicons/heig.png"
  ]

  describe "course_inputs/1" do
    test "says where each input a build reads is, given the course" do
      assert Builder.course_inputs("/archidep/course") == [
               content_dir: "/archidep/course",
               home_file: "/archidep/course/index.md",
               includes_dir: "/archidep/course",
               declarations_file: "/archidep/course/course.yml",
               root_files_dir: "/archidep/course"
             ]
    end
  end

  describe "build/1" do
    test "writes the whole site and says what it was made of", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      assert Builder.build(opts(dirs)) == {:ok, expected_report(dirs)}
      assert written(dirs.output_dir) == expected_build()
    end

    test "writes an edition under its own prefix", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      urls = UrlContext.new(mode: :live, build_id: "test", version: "2026")

      assert Builder.build(opts(dirs, urls: urls)) == {:ok, expected_report(dirs, files: 17)}
      assert written(dirs.output_dir) == expected_build("/2026")
    end

    test "says where things are in this build, whatever its pages say they link to",
         %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      urls =
        UrlContext.new(
          mode: :live,
          build_id: "test",
          version: "2026",
          absolute_base_url: "https://archidep.example.com"
        )

      assert Builder.build(opts(dirs, urls: urls)) == {:ok, expected_report(dirs, files: 17)}

      assert written(dirs.output_dir) == %{
               expected_build("/2026")
               | "/404.html" => not_found_html("https://archidep.example.com/")
             }
    end

    test "keeps an archived edition's home page under its prefix", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      urls =
        UrlContext.new(
          mode: :archive,
          build_id: "test",
          version: "2025",
          live_site_url: "https://archidep.example.com"
        )

      assert Builder.build(opts(dirs, urls: urls)) == {:ok, expected_report(dirs)}
      assert written(dirs.output_dir) == expected_build("/2025", false, :archive)
    end

    test "offers every page the PDF of it the build publishes", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      opts =
        opts(dirs,
          layout: CourseSiteTestLayout.Downloads,
          pdf_base: {:external, "https://example.com/pdf/2026"}
        )

      assert Builder.build(opts) == {:ok, expected_report(dirs)}

      assert written(dirs.output_dir) ==
               expected_build()
               |> Map.put(
                 "/index.html",
                 "/|https://example.com/pdf/2026/archidep-000-course.pdf"
               )
               |> Map.put(
                 "/course/101-command-line/index.html",
                 "/course/101-command-line/|https://example.com/pdf/2026/archidep-101-command-line-subject.pdf"
               )
    end

    test "offers no PDF at all when the build does not say where they are",
         %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      assert Builder.build(opts(dirs, layout: CourseSiteTestLayout.Downloads)) ==
               {:ok, expected_report(dirs)}

      assert written(dirs.output_dir) ==
               expected_build()
               |> Map.put("/index.html", "/|")
               |> Map.put("/course/101-command-line/index.html", "/course/101-command-line/|")
    end

    test "leaves the global assets out when something else serves them", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      assert Builder.build(opts(dirs, carry_assets: false)) == {:ok, expected_report(dirs)}

      assert written(dirs.output_dir) ==
               Map.delete(expected_build(), "/assets/theme/theme.css")
    end

    test "publishes a build rendered beside the one being served", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      write!(dirs.output_dir, "index.html", "an earlier build")

      write!(
        dirs.output_dir,
        "course/507-dns/index.html",
        "a chapter that has since been renamed"
      )

      assert Builder.build(opts(dirs, output: :swap)) == {:ok, expected_report(dirs)}

      assert written(dirs.output_dir) == expected_build()
      assert File.exists?(dirs.output_dir <> ".staging") == false
    end

    test "leaves the build being served alone when the new one fails", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      write!(dirs.output_dir, "index.html", "the build being served")

      write!(
        dirs.course_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\n{% link nope %}\n"
      )

      assert Builder.build(opts(dirs, output: :swap)) ==
               {:error, "The site could not be rendered",
                [
                  ~s{Document chapters/101-command-line/subject.md could not be rendered: } <>
                    ~s{"nope" is not the path of a course document in } <>
                    ~s{chapters/101-command-line/subject.md at line 5, column 1}
                ]}

      assert written(dirs.output_dir) == %{"/index.html" => "the build being served"}
    end

    test "says what it could not read", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      File.rm!(dirs.declarations_file)
      File.rm!(Path.join(dirs.course_dir, "favicon.ico"))

      assert Builder.build(opts(dirs)) ==
               {:error, "The build could not be read",
                [
                  ~s{Course declarations "#{dirs.declarations_file}" do not exist},
                  ~s{File "#{Path.join(dirs.course_dir, "favicon.ico")}", published at "/favicon.ico", could not be read: no such file or directory}
                ]}

      assert File.exists?(dirs.output_dir) == false
    end

    test "says what it could not render", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      write!(
        dirs.course_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\n{% link nope %}\n"
      )

      assert Builder.build(opts(dirs)) ==
               {:error, "The site could not be rendered",
                [
                  ~s{Document chapters/101-command-line/subject.md could not be rendered: } <>
                    ~s{"nope" is not the path of a course document in } <>
                    ~s{chapters/101-command-line/subject.md at line 5, column 1}
                ]}

      assert File.exists?(dirs.output_dir) == false
    end

    test "says what it could not write into", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      write!(dirs.output_dir, "index.html", "an earlier build")

      assert Builder.build(opts(dirs)) ==
               {:error, "The output directory could not be made ready",
                [
                  ~s{Output directory "#{dirs.output_dir}" is not empty; a build owns its output and must start from nothing, but it holds: index.html}
                ]}

      assert written(dirs.output_dir) == %{"/index.html" => "an earlier build"}
    end

    test "says which of the links it wrote lead nowhere", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)

      write!(
        dirs.course_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\n[Nowhere](nowhere/)\n"
      )

      assert Builder.build(opts(dirs)) ==
               {:error, "1 links lead nowhere",
                [
                  ~s{Page /course/101-command-line/ links to "nowhere/", and the build wrote } <>
                    ~s{nothing at "/course/101-command-line/nowhere/index.html"}
                ]}
    end

    # A relative link is written from one page of an edition to another, so an
    # edition's own directory is what its links resolve against; checking them
    # against the whole output would report every one of them as broken.
    test "resolves the links of an edition within it", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      urls = UrlContext.new(mode: :live, build_id: "test", version: "2026")

      write!(
        dirs.course_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\n![CLI](images/cli.jpg)\n"
      )

      assert Builder.build(opts(dirs, urls: urls)) == {:ok, expected_report(dirs, files: 17)}
    end

    test "says which of an edition's links lead nowhere", %{tmp_dir: tmp_dir} do
      dirs = course_fixture(tmp_dir)
      urls = UrlContext.new(mode: :live, build_id: "test", version: "2026")

      write!(
        dirs.course_dir,
        "chapters/101-command-line/subject.md",
        "---\ntitle: Command Line\n---\n\n[Nowhere](nowhere/)\n"
      )

      assert Builder.build(opts(dirs, urls: urls)) ==
               {:error, "1 links lead nowhere",
                [
                  ~s{Page /course/101-command-line/ links to "nowhere/", and the build wrote } <>
                    ~s{nothing at "/course/101-command-line/nowhere/index.html"}
                ]}
    end
  end

  # The smallest course a build can be run over: one chapter with a picture
  # beside it, the home page, the two files the course declares itself with, the
  # files anchored at the mount point and one asset.
  defp course_fixture(tmp_dir) do
    dirs = %{
      course_dir: Path.join(tmp_dir, "course"),
      static_dir: Path.join(tmp_dir, "static"),
      declarations_file: Path.join(tmp_dir, "course/course.yml"),
      progress: [Session.new(~D[2026-02-02], "CLI", [100], [101], [])],
      output_dir: Path.join(tmp_dir, "build")
    }

    Enum.each(@root_files, &write!(dirs.course_dir, &1, &1))

    write!(
      dirs.course_dir,
      "index.md",
      "---\ntitle: Architecture & Deployment\n---\n\nWelcome.\n"
    )

    write!(
      dirs.course_dir,
      "chapters/101-command-line/subject.md",
      "---\ntitle: Command Line\n---\n\nType.\n"
    )

    write!(dirs.course_dir, "chapters/101-command-line/images/cli.jpg", "a picture")

    write!(
      dirs.course_dir,
      "course.yml",
      "---\nsections:\n  - title: Introduction\ncheatsheets: []\n"
    )

    File.mkdir_p!(Path.join(dirs.course_dir, "icons"))
    write!(dirs.static_dir, "assets/theme/theme.css", "body {}")

    dirs
  end

  defp opts(dirs, overrides \\ []) do
    {urls, without_urls} =
      Keyword.pop_lazy(overrides, :urls, fn -> UrlContext.new(mode: :live, build_id: "test") end)

    {layout, build_opts} = Keyword.pop(without_urls, :layout, CourseSiteTestLayout.Wrapper)

    Builder.course_inputs(dirs.course_dir) ++
      [
        progress: dirs.progress,
        static_dir: dirs.static_dir,
        digested: false,
        output_dir: dirs.output_dir,
        options:
          Site.Options.new(
            urls: urls,
            site:
              SiteInfo.new(
                version: "1.2.3",
                git_branch: "main",
                git_revision: "abc123",
                years: "2025-2026",
                years_short: "25-26"
              ),
            layout: layout
          )
      ] ++ build_opts
  end

  # A build that writes the home page twice writes one file more, which is the
  # only thing an edition changes about what a build reports of itself.
  defp expected_report(dirs, overrides \\ []),
    do: %Report{
      output_dir: dirs.output_dir,
      pages: 2,
      chapters: 1,
      files: Keyword.get(overrides, :files, 16),
      page_assets: 1,
      assets: 1
    }

  # The whole of what a build leaves behind: the two pages as the test layout
  # writes them down, the three files a build makes of itself, the ten anchored
  # at its mount point, the picture beside a page and the asset the build
  # carries. An edition holds all of its own under its prefix; what is anchored
  # at the mount point sits beside it, and so does a second copy of the home
  # page for as long as that edition is the one being taught.
  defp expected_build(edition \\ "", home_at_base? \\ true, mode \\ :live) do
    home = "/|index.md|Architecture & Deployment · ArchiDep|||CLI|page:::<p>Welcome.</p>"
    home_url = if home_at_base?, do: "/", else: edition <> "/"

    edition_files = %{
      (edition <> "/index.html") => home,
      (edition <> "/course/101-command-line/index.html") =>
        "/course/101-command-line/|chapters/101-command-line/subject.md|Command Line · ArchiDep|Command Line|Introduction|CLI|page:::<p>Type.</p>",
      (edition <> "/course/101-command-line/images/cli-#{digest("a picture")}.jpg") =>
        "a picture",
      (edition <> "/assets/theme/theme.css") => "body {}",
      (edition <> "/archidep.json") => archidep_json(edition, home_url),
      (edition <> "/search-test.json") => search_json(edition, home_url, mode),
      (edition <> "/version.json") => version_json()
    }

    mount_point =
      @root_files
      |> Map.new(&{"/" <> &1, &1})
      |> Map.put("/404.html", not_found_html(home_url))
      |> then(&if home_at_base?, do: Map.put(&1, "/index.html", home), else: &1)

    Map.merge(edition_files, mount_point)
  end

  defp search_json(edition, home_url, mode) do
    pages = [
      object(
        id: "/",
        type: "home",
        url: home_url,
        title: "Architecture & Deployment",
        subtitle: "Architecture & Deployment",
        text: "Welcome.",
        extraText: ""
      ),
      object(
        id: "/course/101-command-line/",
        type: "subject",
        url: "#{edition}/course/101-command-line/",
        title: "Command Line",
        subtitle: "Command Line",
        text: "Type.",
        extraText: ""
      )
    ]

    json(pages ++ application(mode))
  end

  # Only a live site is served beside the application, so only a live build holds
  # an entry for it.
  defp application(:live),
    do: [
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

  defp application(_mode), do: []

  # The keys are stated in the order the file is expected to write them, so that
  # a build reordering them fails here.
  defp archidep_json(edition, home_url) do
    json(
      object(
        home: object(url: home_url, pdf: "archidep-000-course.pdf"),
        sections: [
          object(
            title: "Introduction",
            slug: "introduction",
            num: 100,
            progress: "done",
            open: true,
            docs: [
              object(
                title: "Command Line",
                num: 101,
                course_type: "subject",
                graded: false,
                course_slug: "command-line",
                section: 1,
                section_chapter: 1,
                progress: "due",
                slides: false,
                url: "#{edition}/course/101-command-line/",
                pdf: "archidep-101-command-line-subject.pdf",
                slides_pdf: nil
              )
            ]
          )
        ],
        cheatsheets: []
      )
    )
  end

  defp version_json do
    json(object(version: "1.2.3", git: object(branch: "main", revision: "abc123")))
  end

  defp object(pairs), do: Jason.OrderedObject.new(pairs)

  defp json(term), do: Jason.encode!(term) <> "\n"

  defp not_found_html(home_url) do
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

  defp digest(contents), do: Base.encode16(:erlang.md5(contents), case: :lower)

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end

  defp written(output_dir) do
    output_dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Map.new(&{"/" <> Path.relative_to(&1, output_dir), File.read!(&1)})
  end
end
