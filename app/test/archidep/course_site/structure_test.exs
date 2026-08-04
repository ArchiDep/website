defmodule ArchiDep.CourseSite.StructureTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.Support.CourseSiteFactory

  describe "plan/3" do
    test "works out what the course is" do
      {:ok, tree} =
        ContentTree.plan([
          "_course/101-command-line/subject.md",
          "_course/101-command-line/slides.md",
          "_course/102-hello-shell/exercise.md",
          "_course/103-ssh/subject.md",
          "_course/103-ssh/slides/slides.md",
          "_course/201-git/slides.md",
          "_course/202-php-todolist/exercise.md",
          "_cheatsheets/command-line/cheatsheet.md",
          "_cheatsheets/git/cheatsheet.md"
        ])

      front_matter = %{
        {:document, DocumentRef.new(101, "command-line", :subject)} => %{
          "title" => "Command Line"
        },
        {:document, DocumentRef.new(101, "command-line", :slides)} => %{
          "title" => "Command Line Slides"
        },
        {:document, DocumentRef.new(102, "hello-shell", :exercise)} => %{
          "title" => "Hello Shell"
        },
        {:document, DocumentRef.new(103, "ssh", :subject)} => %{"title" => "Secure Shell"},
        {:document, DocumentRef.new(103, "ssh", :slides)} => %{"title" => "Secure Shell Slides"},
        {:document, DocumentRef.new(201, "git", :slides)} => %{"title" => "Git Branching"},
        {:document, DocumentRef.new(202, "php-todolist", :exercise)} => %{
          "title" => "PHP Todolist",
          "graded" => true
        },
        {:cheatsheet, "command-line"} => %{
          "title" => "Command Line Cheatsheet",
          "sidebar_title" => "Command Line"
        },
        {:cheatsheet, "git"} => %{"title" => "Git Cheatsheet"}
      }

      declarations = %{
        "sections" => [%{"title" => "Introduction"}, %{"title" => "Version Control"}],
        "cheatsheets" => ["git", "command-line"]
      }

      assert Structure.plan(tree, front_matter, declarations) ==
               {:ok,
                %Structure{
                  sections: [
                    Section.new(1, "Introduction", [
                      Chapter.new(
                        DocumentRef.new(101, "command-line", :subject),
                        "Command Line",
                        slides: DocumentRef.new(101, "command-line", :slides)
                      ),
                      Chapter.new(
                        DocumentRef.new(102, "hello-shell", :exercise),
                        "Hello Shell"
                      ),
                      Chapter.new(DocumentRef.new(103, "ssh", :subject), "Secure Shell",
                        slides: DocumentRef.new(103, "ssh", :slides)
                      )
                    ]),
                    Section.new(2, "Version Control", [
                      Chapter.new(DocumentRef.new(201, "git", :slides), "Git Branching"),
                      Chapter.new(
                        DocumentRef.new(202, "php-todolist", :exercise),
                        "PHP Todolist",
                        graded?: true
                      )
                    ])
                  ],
                  cheatsheets: [
                    Cheatsheet.new("git", "Git Cheatsheet"),
                    Cheatsheet.new("command-line", "Command Line Cheatsheet", "Command Line")
                  ]
                }}
    end

    test "ignores the front matter a chapter's deck carries of its own" do
      # A chapter is named after its page, so the title of the deck beside it is
      # the deck's own business: it is what the deck is called where the deck is
      # shown, never what the chapter is called in a list.
      {:ok, tree} =
        ContentTree.plan([
          "_course/107-dns/subject.md",
          "_course/107-dns/slides/slides.md"
        ])

      front_matter = %{
        {:document, DocumentRef.new(107, "dns", :subject)} => %{
          "title" => "Domain Name System"
        },
        {:document, DocumentRef.new(107, "dns", :slides)} => %{"title" => "DNS, presented"}
      }

      declarations = %{"sections" => [%{"title" => "Introduction"}], "cheatsheets" => []}

      assert Structure.plan(tree, front_matter, declarations) ==
               {:ok,
                %Structure{
                  sections: [
                    Section.new(1, "Introduction", [
                      Chapter.new(
                        DocumentRef.new(107, "dns", :subject),
                        "Domain Name System",
                        slides: DocumentRef.new(107, "dns", :slides)
                      )
                    ])
                  ],
                  cheatsheets: []
                }}
    end

    test "refuses declarations that are not a mapping" do
      {:ok, tree} = ContentTree.plan([])

      assert Structure.plan(tree, %{}, ["Introduction"]) ==
               {:error,
                [{:malformed_declarations, ~s{expected a mapping, got: ["Introduction"]}}]}
    end

    test "refuses declarations that say neither what the sections nor the cheatsheets are" do
      {:ok, tree} = ContentTree.plan([])

      assert Structure.plan(tree, %{}, %{}) ==
               {:error,
                [
                  {:malformed_declarations, ~s{the "sections" key is missing}},
                  {:malformed_declarations, ~s{the "cheatsheets" key is missing}}
                ]}
    end

    test "refuses a section that is not a mapping with a title" do
      {:ok, tree} = ContentTree.plan([])

      assert Structure.plan(tree, %{}, %{
               "sections" => [%{"title" => "Introduction"}, %{"name" => "Security"}],
               "cheatsheets" => []
             }) ==
               {:error,
                [
                  {:malformed_declarations,
                   ~s|expected "sections" to be a list of mappings each with a non-empty title, got: [%{"title" => "Introduction"}, %{"name" => "Security"}]|}
                ]}
    end

    test "refuses a cheatsheet that is not a slug" do
      {:ok, tree} = ContentTree.plan([])

      assert Structure.plan(tree, %{}, %{
               "sections" => [%{"title" => "Introduction"}],
               "cheatsheets" => ["git", 42]
             }) ==
               {:error,
                [
                  {:malformed_declarations,
                   ~s{expected "cheatsheets" to be a list of non-empty slugs, got: ["git", 42]}}
                ]}
    end

    test "refuses the same cheatsheet declared twice" do
      {:ok, tree} = ContentTree.plan([])

      assert Structure.plan(tree, %{}, %{
               "sections" => [%{"title" => "Introduction"}],
               "cheatsheets" => ["docker", "git", "docker"]
             }) ==
               {:error,
                [
                  {:malformed_declarations,
                   ~s{the "cheatsheets" key lists the same cheatsheet more than once}}
                ]}
    end

    test "refuses two sections that would fold each other in the navigation" do
      {:ok, tree} = ContentTree.plan(["_course/101-command-line/subject.md"])

      front_matter = %{
        {:document, DocumentRef.new(101, "command-line", :subject)} => %{
          "title" => "Command Line"
        }
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [
                 %{"title" => "Docker Deployment"},
                 %{"title" => "Docker: deployment"}
               ],
               "cheatsheets" => []
             }) ==
               {:error,
                [
                  {:duplicate_section_slug, "docker-deployment",
                   ["Docker Deployment", "Docker: deployment"]},
                  {:empty_section, 2, "Docker: deployment"}
                ]}
    end

    test "refuses a chapter numbered for a section nobody declared" do
      {:ok, tree} =
        ContentTree.plan([
          "_course/101-command-line/subject.md",
          "_course/901-quantum-deployment/exercise.md",
          "_course/902-quantum-scaling/exercise.md"
        ])

      front_matter = %{
        {:document, DocumentRef.new(101, "command-line", :subject)} => %{
          "title" => "Command Line"
        },
        {:document, DocumentRef.new(901, "quantum-deployment", :exercise)} => %{
          "title" => "Quantum Deployment"
        },
        {:document, DocumentRef.new(902, "quantum-scaling", :exercise)} => %{
          "title" => "Quantum Scaling"
        }
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [%{"title" => "Introduction"}],
               "cheatsheets" => []
             }) ==
               {:error,
                [
                  {:unknown_section, "901-quantum-deployment", 9},
                  {:unknown_section, "902-quantum-scaling", 9}
                ]}
    end

    test "refuses a declared section no chapter is numbered for" do
      {:ok, tree} = ContentTree.plan(["_course/201-git/subject.md"])

      front_matter = %{
        {:document, DocumentRef.new(201, "git", :subject)} => %{"title" => "Version Control"}
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [%{"title" => "Introduction"}, %{"title" => "Version Control"}],
               "cheatsheets" => []
             }) ==
               {:error, [{:empty_section, 1, "Introduction"}]}
    end

    test "refuses a page with no title, or with something else in its place" do
      {:ok, tree} =
        ContentTree.plan([
          "_course/101-command-line/subject.md",
          "_course/102-shell-scripting/subject.md",
          "_course/103-hello-shell/exercise.md",
          "_cheatsheets/git/cheatsheet.md"
        ])

      front_matter = %{
        {:document, DocumentRef.new(101, "command-line", :subject)} => %{},
        {:document, DocumentRef.new(102, "shell-scripting", :subject)} => %{"title" => 42},
        {:document, DocumentRef.new(103, "hello-shell", :exercise)} => %{"title" => "  "},
        {:cheatsheet, "git"} => %{"title" => nil}
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [%{"title" => "Introduction"}],
               "cheatsheets" => ["git"]
             }) ==
               {:error,
                [
                  {:invalid_title, "_cheatsheets/git/cheatsheet.md", nil},
                  {:missing_title, "_course/101-command-line/subject.md"},
                  {:invalid_title, "_course/102-shell-scripting/subject.md", 42},
                  {:invalid_title, "_course/103-hello-shell/exercise.md", "  "}
                ]}
    end

    test "refuses a document that is graded as something other than yes or no" do
      {:ok, tree} = ContentTree.plan(["_course/103-hello-shell/exercise.md"])

      front_matter = %{
        {:document, DocumentRef.new(103, "hello-shell", :exercise)} => %{
          "title" => "Hello Shell",
          "graded" => "yes"
        }
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [%{"title" => "Introduction"}],
               "cheatsheets" => []
             }) ==
               {:error, [{:invalid_graded, "_course/103-hello-shell/exercise.md", "yes"}]}
    end

    test "refuses a document that is graded and is not an exercise" do
      {:ok, tree} =
        ContentTree.plan([
          "_course/101-command-line/subject.md",
          "_course/101-command-line/slides.md",
          "_cheatsheets/git/cheatsheet.md"
        ])

      front_matter = %{
        {:document, DocumentRef.new(101, "command-line", :subject)} => %{
          "title" => "Command Line",
          "graded" => true
        },
        {:document, DocumentRef.new(101, "command-line", :slides)} => %{
          "title" => "Command Line Slides",
          "graded" => true
        },
        {:cheatsheet, "git"} => %{"title" => "Git Cheatsheet", "graded" => true}
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [%{"title" => "Introduction"}],
               "cheatsheets" => ["git"]
             }) ==
               {:error,
                [
                  {:graded_non_exercise, "_cheatsheets/git/cheatsheet.md"},
                  {:graded_non_exercise, "_course/101-command-line/slides.md"},
                  {:graded_non_exercise, "_course/101-command-line/subject.md"}
                ]}
    end

    test "refuses a cheatsheet whose sidebar title is not a name" do
      {:ok, tree} = ContentTree.plan(["_cheatsheets/git/cheatsheet.md"])

      front_matter = %{
        {:cheatsheet, "git"} => %{"title" => "Git Cheatsheet", "sidebar_title" => ""}
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [],
               "cheatsheets" => ["git"]
             }) ==
               {:error, [{:invalid_sidebar_title, "_cheatsheets/git/cheatsheet.md", ""}]}
    end

    test "refuses a cheatsheet nobody declared, and a declared cheatsheet nobody wrote" do
      {:ok, tree} =
        ContentTree.plan([
          "_cheatsheets/docker/cheatsheet.md",
          "_cheatsheets/git/cheatsheet.md"
        ])

      front_matter = %{
        {:cheatsheet, "docker"} => %{"title" => "Docker"},
        {:cheatsheet, "git"} => %{"title" => "Git Cheatsheet"}
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [],
               "cheatsheets" => ["git", "sysadmin"]
             }) ==
               {:error,
                [
                  {:unlisted_cheatsheet, "docker"},
                  {:missing_cheatsheet, "sysadmin"}
                ]}
    end

    test "reports every offending document rather than the first" do
      {:ok, tree} =
        ContentTree.plan([
          "_course/101-command-line/subject.md",
          "_course/902-quantum-scaling/exercise.md",
          "_cheatsheets/git/cheatsheet.md"
        ])

      front_matter = %{
        {:document, DocumentRef.new(101, "command-line", :subject)} => %{"graded" => true},
        {:document, DocumentRef.new(902, "quantum-scaling", :exercise)} => %{
          "title" => "Quantum Scaling"
        },
        {:cheatsheet, "git"} => %{"title" => "Git Cheatsheet"}
      }

      assert Structure.plan(tree, front_matter, %{
               "sections" => [%{"title" => "Introduction"}, %{"title" => "Version Control"}],
               "cheatsheets" => []
             }) ==
               {:error,
                [
                  {:unknown_section, "902-quantum-scaling", 9},
                  {:empty_section, 2, "Version Control"},
                  {:missing_title, "_course/101-command-line/subject.md"},
                  {:graded_non_exercise, "_course/101-command-line/subject.md"},
                  {:unlisted_cheatsheet, "git"}
                ]}
    end

    test "raises when it is handed a page the front matter says nothing about" do
      {:ok, tree} = ContentTree.plan(["_course/101-command-line/subject.md"])

      assert_raise ArgumentError,
                   ~s{No front matter was given for "_course/101-command-line/subject.md"},
                   fn ->
                     Structure.plan(tree, %{}, %{
                       "sections" => [%{"title" => "Introduction"}],
                       "cheatsheets" => []
                     })
                   end
    end
  end

  describe "chapters/1" do
    test "reads every chapter of the course in reading order" do
      structure = %Structure{
        sections: [
          Section.new(1, "Introduction", [
            Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line"),
            Chapter.new(DocumentRef.new(102, "hello-shell", :exercise), "Hello Shell")
          ]),
          Section.new(2, "Version Control", [
            Chapter.new(DocumentRef.new(201, "git", :slides), "Git")
          ])
        ],
        cheatsheets: []
      }

      assert Structure.chapters(structure) == [
               Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line"),
               Chapter.new(DocumentRef.new(102, "hello-shell", :exercise), "Hello Shell"),
               Chapter.new(DocumentRef.new(201, "git", :slides), "Git")
             ]
    end
  end

  describe "pages/1" do
    test "reads every page of the course in reading order, deck included" do
      structure = %Structure{
        sections: [
          Section.new(1, "Introduction", [
            Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line",
              slides: DocumentRef.new(101, "command-line", :slides)
            ),
            Chapter.new(DocumentRef.new(102, "hello-shell", :exercise), "Hello Shell")
          ]),
          Section.new(2, "Version Control", [
            Chapter.new(DocumentRef.new(201, "git", :slides), "Git")
          ])
        ],
        cheatsheets: [
          Cheatsheet.new("git", "Git Cheatsheet"),
          Cheatsheet.new("command-line", "Command Line Cheatsheet")
        ]
      }

      assert Structure.pages(structure) == [
               {:document, DocumentRef.new(101, "command-line", :subject)},
               {:document, DocumentRef.new(101, "command-line", :slides)},
               {:document, DocumentRef.new(102, "hello-shell", :exercise)},
               {:document, DocumentRef.new(201, "git", :slides)},
               {:cheatsheet, "git"},
               {:cheatsheet, "command-line"}
             ]
    end

    test "reads no page at all of a course with no chapter and no cheatsheet" do
      assert Structure.pages(%Structure{sections: [], cheatsheets: []}) == []
    end
  end

  describe "fetch_section/2, fetch_chapter/2 and fetch_cheatsheet/2" do
    test "look up what the course holds, and say when it holds no such thing" do
      section =
        Section.new(3, "Security", [
          Chapter.new(DocumentRef.new(301, "security", :subject), "Security")
        ])

      cheatsheet = Cheatsheet.new("sysadmin", "System Administration Cheatsheet")
      structure = %Structure{sections: [section], cheatsheets: [cheatsheet]}

      assert {
               Structure.fetch_section(structure, 300),
               Structure.fetch_section(structure, 3),
               Structure.fetch_chapter(structure, 301),
               Structure.fetch_chapter(structure, 302),
               Structure.fetch_cheatsheet(structure, "sysadmin"),
               Structure.fetch_cheatsheet(structure, "git")
             } == {
               {:ok, section},
               :error,
               {:ok, Chapter.new(DocumentRef.new(301, "security", :subject), "Security")},
               :error,
               {:ok, cheatsheet},
               :error
             }
    end
  end

  describe "fetch_chapter/3" do
    test "looks a chapter up by its number and its slug, whatever its page is" do
      structure = %Structure{
        sections: [
          Section.new(4, "Basic Deployment", [
            Chapter.new(DocumentRef.new(402, "run-virtual-server", :exercise), "Run a Server"),
            Chapter.new(DocumentRef.new(403, "linux", :slides), "Linux")
          ])
        ],
        cheatsheets: []
      }

      assert {
               Structure.fetch_chapter(structure, 402, "run-virtual-server"),
               Structure.fetch_chapter(structure, 403, "linux"),
               Structure.fetch_chapter(structure, 402, "run-your-own-server"),
               Structure.fetch_chapter(structure, 404, "run-virtual-server")
             } == {
               {:ok,
                Chapter.new(DocumentRef.new(402, "run-virtual-server", :exercise), "Run a Server")},
               {:ok, Chapter.new(DocumentRef.new(403, "linux", :slides), "Linux")},
               :error,
               :error
             }
    end
  end

  describe "chapter!/3" do
    test "looks a chapter up by its number and its slug" do
      chapter = Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System")
      structure = %Structure{sections: [Section.new(5, "Advanced", [chapter])], cheatsheets: []}

      assert Structure.chapter!(structure, 507, "dns") == chapter
    end

    test "refuses a chapter the course does not have" do
      structure = %Structure{
        sections: [
          Section.new(5, "Advanced", [
            Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System")
          ])
        ],
        cheatsheets: []
      }

      assert_raise ArgumentError, "The course has no chapter 507-domain-name-system", fn ->
        Structure.chapter!(structure, 507, "domain-name-system")
      end
    end
  end

  describe "cheatsheet!/2" do
    test "looks a cheatsheet up by its slug" do
      cheatsheet = Cheatsheet.new("sysadmin", "System Administration Cheatsheet")
      structure = %Structure{sections: [], cheatsheets: [cheatsheet]}

      assert Structure.cheatsheet!(structure, "sysadmin") == cheatsheet
    end

    test "refuses a cheatsheet the course does not have" do
      structure = %Structure{
        sections: [],
        cheatsheets: [Cheatsheet.new("sysadmin", "System Administration Cheatsheet")]
      }

      assert_raise ArgumentError, "The course has no system-administration cheatsheet", fn ->
        Structure.cheatsheet!(structure, "system-administration")
      end
    end
  end

  describe "format_error/1" do
    test "describes declarations that cannot be read" do
      assert Structure.format_error({:malformed_declarations, ~s{the "sections" key is missing}}) ==
               ~s{The course declarations are invalid: the "sections" key is missing}
    end

    test "describes two sections that would fold each other" do
      assert Structure.format_error(
               {:duplicate_section_slug, "docker-deployment",
                ["Docker Deployment", "Docker: deployment"]}
             ) ==
               ~s{Sections "Docker Deployment" and "Docker: deployment" are both named "docker-deployment" in the navigation}
    end

    test "describes a chapter numbered for a section nobody declared" do
      assert Structure.format_error({:unknown_section, "901-quantum-deployment", 9}) ==
               ~s{Chapter "901-quantum-deployment" is in section 9, which is not declared}
    end

    test "describes a declared section with nothing in it" do
      assert Structure.format_error({:empty_section, 6, "Automated Deployment"}) ==
               ~s{Section 6 ("Automated Deployment") has no chapters}
    end

    test "describes a page with no title" do
      assert Structure.format_error({:missing_title, "_course/507-dns/subject.md"}) ==
               ~s{Document "_course/507-dns/subject.md" has no title}
    end

    test "describes a page whose title is not one" do
      assert Structure.format_error({:invalid_title, "_course/507-dns/subject.md", 42}) ==
               ~s{Document "_course/507-dns/subject.md" has 42 as its title}
    end

    test "describes a document graded as something other than yes or no" do
      assert Structure.format_error(
               {:invalid_graded, "_course/205-php-todolist/exercise.md", "yes"}
             ) ==
               ~s{Document "_course/205-php-todolist/exercise.md" declares "yes" as graded rather than true or false}
    end

    test "describes a document that is graded and is not an exercise" do
      assert Structure.format_error({:graded_non_exercise, "_course/301-security/subject.md"}) ==
               ~s{Document "_course/301-security/subject.md" is graded, which only an exercise can be}
    end

    test "describes a cheatsheet whose name in a list is not a name" do
      assert Structure.format_error(
               {:invalid_sidebar_title, "_cheatsheets/git/cheatsheet.md", ""}
             ) ==
               ~s{Document "_cheatsheets/git/cheatsheet.md" has "" as its title in a list}
    end

    test "describes a cheatsheet nobody declared" do
      assert Structure.format_error({:unlisted_cheatsheet, "docker"}) ==
               ~s{Cheatsheet "docker" is not one of the declared cheatsheets}
    end

    test "describes a declared cheatsheet nobody wrote" do
      assert Structure.format_error({:missing_cheatsheet, "sysadmin"}) ==
               ~s{Cheatsheet "sysadmin" is declared but the content directory holds no such cheatsheet}
    end
  end

  describe "plan/3 invariants" do
    property "every document of the content directory is part of exactly one chapter" do
      check all {tree, front_matter, declarations} <- CourseSiteFactory.course_generator() do
        {:ok, structure} = Structure.plan(tree, front_matter, declarations)

        assert structure
               |> Structure.chapters()
               |> Enum.flat_map(&[&1.page | List.wrap(&1.slides)])
               |> Enum.sort() == tree.documents |> Map.keys() |> Enum.sort()
      end
    end

    property "every chapter of the course is found by its number" do
      check all {tree, front_matter, declarations} <- CourseSiteFactory.course_generator() do
        {:ok, structure} = Structure.plan(tree, front_matter, declarations)
        chapters = Structure.chapters(structure)

        assert Enum.map(chapters, &Structure.fetch_chapter(structure, Chapter.num(&1))) ==
                 Enum.map(chapters, &{:ok, &1})
      end
    end

    property "a chapter is listed under the section its number names" do
      check all {tree, front_matter, declarations} <- CourseSiteFactory.course_generator() do
        {:ok, structure} = Structure.plan(tree, front_matter, declarations)

        assert Map.new(structure.sections, &{&1.index, &1.chapters}) ==
                 structure |> Structure.chapters() |> Enum.group_by(&Chapter.section/1)
      end
    end
  end
end
