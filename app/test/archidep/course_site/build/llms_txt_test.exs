defmodule ArchiDep.CourseSite.Build.LlmsTxtTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.LlmsTxt
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  describe "text/5" do
    test "lists every chapter with what it is, its slides and its tutor notes, then the cheatsheets" do
      cli = DocumentRef.new(101, "command-line", :subject)
      cli_slides = DocumentRef.new(101, "command-line", :slides)
      hello_shell = DocumentRef.new(102, "hello-shell", :exercise)
      branching = DocumentRef.new(202, "git-branching", :slides)
      todolist = DocumentRef.new(205, "php-todolist", :exercise)

      structure = %Structure{
        sections: [
          Section.new(1, "Introduction", [
            Chapter.new(cli, "Command Line", slides: cli_slides),
            Chapter.new(hello_shell, "Hello Shell")
          ]),
          Section.new(2, "Version Control", [
            Chapter.new(branching, "Git Branching"),
            Chapter.new(todolist, "PHP Todolist", graded?: true)
          ])
        ],
        cheatsheets: [Cheatsheet.new("git", "Git Cheatsheet")]
      }

      summaries = %{
        {:document, cli} => "Learn to use the command line.",
        {:document, cli_slides} => nil,
        {:document, hello_shell} => "Find a treasure hidden in the file system.",
        {:document, branching} => nil,
        {:document, todolist} => "Deploy the PHP todolist on your server.",
        {:cheatsheet, "git"} => "Commit, branch and merge."
      }

      urls =
        build(:url_context,
          mode: :live,
          base_path: "",
          version: "2026",
          page_assets:
            PageAssetManifest.new(%{
              "/course/102-hello-shell/tutor.md" => "tutor-0123abcd.md",
              "/course/101-command-line/images/cli.png" => "cli-4567ef01.png"
            })
        )

      site =
        SiteInfo.new(
          version: "1.2.3",
          git_revision: "f00dcafe",
          years: "2026-2027",
          years_short: "26-27"
        )

      assert LlmsTxt.text(structure, summaries, urls, "https://archidep.example.com", site) == """
             # ArchiDep

             > The course material of ArchiDep, the media engineering architecture and deployment course, 2026-2027 edition.

             Home page: https://archidep.example.com/

             This index lists the chapters of the edition being taught. Past editions stay published under their own year and are not listed here.

             A chapter is identified by its number: the number of its section, a multiple of 100, plus its place in that section (402 is the second chapter of section 400). How far the class has got is published at https://archidep.example.com/api/progress as a list of sessions, each recording the section and chapter numbers it finished (`done`), set work on (`due`) and announced for next time (`next`). A number is the first of done, due and next that any session lists it as; a number no session lists has not been reached yet. A session is recorded on the day it is taught, but what it covered may only be filled in at the end of that day. Chapters not reached yet are still being written: they may be renumbered, renamed, rewritten or removed before they are taught, so only what has been taught is final.

             In the course pages, `jde` stands for the student's own username and `W.X.Y.Z` for the IP address of their server. An exercise's "Requirements" section, when it has one, names the earlier exercises whose results it builds on. Some values, such as the details of a student's server, are only shown in the browser of a logged-in student.

             Some chapters have tutor notes, written for an AI tutor helping a student through the chapter: what it teaches, where students usually get stuck, hints, and the questions worth asking at its key steps. They are linked from the chapter's entry.

             Built from revision f00dcafe.

             ## 100 Introduction

             - [101 Command Line](https://archidep.example.com/2026/course/101-command-line/): subject. Learn to use the command line.
               - Slides: https://archidep.example.com/2026/course/101-command-line/slides/
             - [102 Hello Shell](https://archidep.example.com/2026/course/102-hello-shell/): exercise. Find a treasure hidden in the file system.
               - Tutor notes: https://archidep.example.com/2026/course/102-hello-shell/tutor-0123abcd.md

             ## 200 Version Control

             - [202 Git Branching](https://archidep.example.com/2026/course/202-git-branching/slides/): slides.
             - [205 PHP Todolist](https://archidep.example.com/2026/course/205-php-todolist/): graded exercise. Deploy the PHP todolist on your server.

             ## Cheatsheets

             - [Git Cheatsheet](https://archidep.example.com/2026/cheatsheets/git/)
             """
    end

    test "links to the site it is given wherever the build is mounted and whatever its own links say" do
      ssh = DocumentRef.new(104, "hello-ssh", :exercise)

      structure = %Structure{
        sections: [Section.new(1, "Introduction", [Chapter.new(ssh, "Hello SSH")])],
        cheatsheets: [Cheatsheet.new("sysadmin", "System Administration Cheatsheet")]
      }

      urls =
        build(:url_context,
          mode: :live,
          base_path: "/website",
          version: "2027",
          absolute_base_url: "https://print.example.com",
          page_assets:
            PageAssetManifest.new(%{"/course/104-hello-ssh/tutor.md" => "tutor-89abcdef.md"})
        )

      site = SiteInfo.new(version: "4.5.6", years: "2027-2028", years_short: "27-28")

      assert LlmsTxt.text(
               structure,
               %{{:document, ssh} => "Connect to a server.", {:cheatsheet, "sysadmin"} => nil},
               urls,
               "https://main.example.org",
               site
             ) == """
             # ArchiDep

             > The course material of ArchiDep, the media engineering architecture and deployment course, 2027-2028 edition.

             Home page: https://main.example.org/website/

             This index lists the chapters of the edition being taught. Past editions stay published under their own year and are not listed here.

             A chapter is identified by its number: the number of its section, a multiple of 100, plus its place in that section (402 is the second chapter of section 400). How far the class has got is published at https://main.example.org/website/api/progress as a list of sessions, each recording the section and chapter numbers it finished (`done`), set work on (`due`) and announced for next time (`next`). A number is the first of done, due and next that any session lists it as; a number no session lists has not been reached yet. A session is recorded on the day it is taught, but what it covered may only be filled in at the end of that day. Chapters not reached yet are still being written: they may be renumbered, renamed, rewritten or removed before they are taught, so only what has been taught is final.

             In the course pages, `jde` stands for the student's own username and `W.X.Y.Z` for the IP address of their server. An exercise's "Requirements" section, when it has one, names the earlier exercises whose results it builds on. Some values, such as the details of a student's server, are only shown in the browser of a logged-in student.

             Some chapters have tutor notes, written for an AI tutor helping a student through the chapter: what it teaches, where students usually get stuck, hints, and the questions worth asking at its key steps. They are linked from the chapter's entry.

             ## 100 Introduction

             - [104 Hello SSH](https://main.example.org/website/2027/course/104-hello-ssh/): exercise. Connect to a server.
               - Tutor notes: https://main.example.org/website/2027/course/104-hello-ssh/tutor-89abcdef.md

             ## Cheatsheets

             - [System Administration Cheatsheet](https://main.example.org/website/2027/cheatsheets/sysadmin/)
             """
    end

    test "has no cheatsheets section for a course that has none" do
      subject = DocumentRef.new(301, "security", :subject)

      structure = %Structure{
        sections: [Section.new(3, "Security", [Chapter.new(subject, "Security")])],
        cheatsheets: []
      }

      urls = build(:url_context, mode: :live, base_path: "", version: "2030")

      site =
        SiteInfo.new(
          version: "7.8.9",
          git_revision: "beefbeef",
          years: "2030-2031",
          years_short: "30-31"
        )

      assert LlmsTxt.text(
               structure,
               %{{:document, subject} => nil},
               urls,
               "https://archidep.example.net",
               site
             ) == """
             # ArchiDep

             > The course material of ArchiDep, the media engineering architecture and deployment course, 2030-2031 edition.

             Home page: https://archidep.example.net/

             This index lists the chapters of the edition being taught. Past editions stay published under their own year and are not listed here.

             A chapter is identified by its number: the number of its section, a multiple of 100, plus its place in that section (402 is the second chapter of section 400). How far the class has got is published at https://archidep.example.net/api/progress as a list of sessions, each recording the section and chapter numbers it finished (`done`), set work on (`due`) and announced for next time (`next`). A number is the first of done, due and next that any session lists it as; a number no session lists has not been reached yet. A session is recorded on the day it is taught, but what it covered may only be filled in at the end of that day. Chapters not reached yet are still being written: they may be renumbered, renamed, rewritten or removed before they are taught, so only what has been taught is final.

             In the course pages, `jde` stands for the student's own username and `W.X.Y.Z` for the IP address of their server. An exercise's "Requirements" section, when it has one, names the earlier exercises whose results it builds on. Some values, such as the details of a student's server, are only shown in the browser of a logged-in student.

             Some chapters have tutor notes, written for an AI tutor helping a student through the chapter: what it teaches, where students usually get stuck, hints, and the questions worth asking at its key steps. They are linked from the chapter's entry.

             Built from revision beefbeef.

             ## 300 Security

             - [301 Security](https://archidep.example.net/2030/course/301-security/): subject.
             """
    end
  end
end
