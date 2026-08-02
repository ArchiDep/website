defmodule ArchiDepWeb.Components.CourseComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Components.CourseComponents

  @no_properties %{
    cpus: nil,
    cores: nil,
    vcpus: nil,
    memory: nil,
    swap: nil,
    system: nil,
    architecture: nil,
    os_family: nil,
    distribution: nil,
    distribution_version: nil,
    distribution_release: nil
  }

  describe "course_material_menu/1" do
    test "lists every section, the chapters under it and the cheatsheets after them" do
      structure = %Structure{
        sections: [
          Section.new(1, "Introduction", [
            Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line",
              slides: DocumentRef.new(101, "command-line", :slides)
            ),
            Chapter.new(DocumentRef.new(102, "hello-shell", :exercise), "Hello Shell",
              graded?: true
            )
          ]),
          Section.new(2, "Version Control", [
            Chapter.new(DocumentRef.new(201, "git-branching", :slides), "Git Branching"),
            Chapter.new(DocumentRef.new(202, "git-collaborating", :exercise), "Collaborating"),
            Chapter.new(DocumentRef.new(203, "git-rebasing", :subject), "Rebasing")
          ])
        ],
        cheatsheets: [
          Cheatsheet.new("git", "Git Cheatsheet", "Git"),
          Cheatsheet.new("sysadmin", "System Administration Cheatsheet")
        ]
      }

      progress = %{
        100 => :done,
        101 => :done,
        102 => :done,
        200 => :next,
        201 => :next,
        202 => :due,
        203 => :future
      }

      assert course_material_menu_entries(structure, progress) == [
               {:section,
                %{
                  title: "Introduction",
                  toggle: "section-introduction-toggle",
                  status: :done,
                  open?: false,
                  locked?: false,
                  chevrons?: true
                }},
               {:chapter,
                %{
                  title: "Command Line",
                  href: "/1955/course/101-command-line/",
                  target: "_self",
                  icons: [:subject, :slides],
                  external_link?: false,
                  status: :done
                }},
               {:chapter,
                %{
                  title: "Hello Shell",
                  href: "/1955/course/102-hello-shell/",
                  target: "_self",
                  icons: [:graded_exercise],
                  external_link?: false,
                  status: :done
                }},
               {:section,
                %{
                  title: "Version Control",
                  toggle: "section-version-control-toggle",
                  status: :next,
                  open?: true,
                  locked?: true,
                  chevrons?: false
                }},
               {:chapter,
                %{
                  title: "Git Branching",
                  href: "/1955/course/201-git-branching/slides/",
                  target: "_blank",
                  icons: [:slides],
                  external_link?: true,
                  status: :next
                }},
               {:chapter,
                %{
                  title: "Collaborating",
                  href: "/1955/course/202-git-collaborating/",
                  target: "_self",
                  icons: [:exercise],
                  external_link?: false,
                  status: :due
                }},
               {:chapter,
                %{
                  title: "Rebasing",
                  href: "/1955/course/203-git-rebasing/",
                  target: "_self",
                  icons: [:subject],
                  external_link?: false,
                  status: :future
                }},
               {:heading, "Cheatsheets"},
               {:cheatsheet, %{name: "Git", href: "/1955/cheatsheets/git/"}},
               {:cheatsheet,
                %{name: "System Administration Cheatsheet", href: "/1955/cheatsheets/sysadmin/"}}
             ]
    end
  end

  describe "student_username/1" do
    test "renders the username of a confirmed student without a suggestion" do
      student = CourseFactory.build(:student_view, username: "alice", username_confirmed: true)

      assert student_username_projection(student) == %{username: "alice", suggested: nil}
    end

    test "marks the username of an unconfirmed student as suggested" do
      student = CourseFactory.build(:student_view, username: "bob", username_confirmed: false)

      assert student_username_projection(student) == %{username: "bob", suggested: "(suggested)"}
    end
  end

  describe "expected_server_properties/1" do
    test "reports no restrictions when every property is unset" do
      properties = CourseFactory.build(:expected_server_properties, @no_properties)

      assert expected_properties_lines(properties) == ["No restrictions placed on any property"]
    end

    test "renders the singular CPU, core and vCPU labels for a count of one" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | cpus: 1,
            cores: 1,
            vcpus: 1
        })

      assert expected_properties_lines(properties) == ["1 CPU, 1 core, 1 vCPU"]
    end

    test "renders the plural CPU, core and vCPU labels for counts above one" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | cpus: 2,
            cores: 4,
            vcpus: 8
        })

      assert expected_properties_lines(properties) == ["2 CPUs, 4 cores, 8 vCPUs"]
    end

    test "omits the unset members of the CPU group" do
      properties = CourseFactory.build(:expected_server_properties, %{@no_properties | cores: 4})

      assert expected_properties_lines(properties) == ["4 cores"]
    end

    test "renders the RAM and swap amounts in megabytes" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | memory: 512,
            swap: 256
        })

      assert expected_properties_lines(properties) == ["512 MB RAM, 256 MB Swap"]
    end

    test "omits the unset members of the memory group" do
      properties = CourseFactory.build(:expected_server_properties, %{@no_properties | swap: 256})

      assert expected_properties_lines(properties) == ["256 MB Swap"]
    end

    test "renders the system, architecture and OS family" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | system: "Linux",
            architecture: "x86_64",
            os_family: "Debian"
        })

      assert expected_properties_lines(properties) == ["Linux x86_64, Debian family"]
    end

    test "renders only the system when the architecture and OS family are unset" do
      properties =
        CourseFactory.build(:expected_server_properties, %{@no_properties | system: "Linux"})

      assert expected_properties_lines(properties) == ["Linux"]
    end

    test "renders only the OS family when the system and architecture are unset" do
      properties =
        CourseFactory.build(:expected_server_properties, %{@no_properties | os_family: "Debian"})

      assert expected_properties_lines(properties) == ["Debian family"]
    end

    test "renders the distribution, version and release" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | distribution: "Ubuntu",
            distribution_version: "22.04",
            distribution_release: "jammy"
        })

      assert expected_properties_lines(properties) == ["Ubuntu 22.04 jammy"]
    end

    test "omits the unset members of the distribution group" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | distribution_release: "jammy"
        })

      assert expected_properties_lines(properties) == ["jammy"]
    end

    test "renders one line per non-empty property group in order" do
      properties =
        CourseFactory.build(:expected_server_properties, %{
          @no_properties
          | cpus: 2,
            memory: 512,
            system: "Linux",
            distribution: "Ubuntu"
        })

      assert expected_properties_lines(properties) == ["2 CPUs", "512 MB RAM", "Linux", "Ubuntu"]
    end
  end

  # Every entry of the menu, in the order it is listed. An emoji is read as the
  # name it is announced under, a status as the name in the class that colours
  # it, and a fold as the state of the checkbox that folds it — the menu's
  # meaning rather than the markup carrying it.
  defp course_material_menu_entries(structure, progress) do
    html =
      render_component(&CourseComponents.course_material_menu/1,
        structure: structure,
        progress: progress
      )

    html |> find_html_elements("#course-material-menu li") |> Enum.map(&menu_entry/1)
  end

  defp menu_entry(entry) do
    class = html_element_attribute(entry, "class") || ""

    cond do
      status = status_shown(class, "course-section-") -> {:section, section_entry(entry, status)}
      status = status_shown(class, "course-item-") -> {:chapter, chapter_entry(entry, status)}
      find_html_elements(entry, "a") != [] -> {:cheatsheet, cheatsheet_entry(entry)}
      true -> {:heading, html_element_text(entry)}
    end
  end

  defp section_entry(entry, status) do
    [label] = find_html_elements(entry, "label")
    [input] = find_html_elements(entry, "input")

    %{
      title: entry |> find_html_elements("label > span") |> hd() |> html_element_text(),
      toggle: toggle_shown(label, input),
      status: status,
      open?: html_element_attribute(input, "checked") != nil,
      locked?: html_element_attribute(input, "disabled") != nil,
      chevrons?: find_html_elements(entry, "svg") != []
    }
  end

  defp chapter_entry(entry, status) do
    [link] = find_html_elements(entry, "a")

    %{
      title:
        entry |> find_html_elements("a > span > span:last-child") |> hd() |> html_element_text(),
      href: html_element_attribute(link, "href"),
      target: html_element_attribute(link, "target"),
      icons: entry |> find_html_elements("img") |> Enum.map(&icon_shown/1),
      external_link?: find_html_elements(entry, "svg") != [],
      status: status
    }
  end

  defp cheatsheet_entry(entry) do
    [link] = find_html_elements(entry, "a")

    %{
      name:
        entry |> find_html_elements("a > span > span:last-child") |> hd() |> html_element_text(),
      href: html_element_attribute(link, "href")
    }
  end

  defp status_shown(class, prefix) do
    case Regex.run(~r/#{prefix}(\w+)/, class) do
      [_whole, status] -> String.to_existing_atom(status)
      nil -> nil
    end
  end

  # A label and the checkbox it folds find each other by name, so a menu whose
  # two halves disagree is a section that cannot be unfolded at all.
  defp toggle_shown(label, input) do
    case {html_element_attribute(label, "for"), html_element_attribute(input, "id")} do
      {same, same} -> same
      mismatched -> mismatched
    end
  end

  defp icon_shown(image) do
    case html_element_attribute(image, "alt") do
      "Subject" -> :subject
      "Exercise" -> :exercise
      "Graded exercise" -> :graded_exercise
      "Slides" -> :slides
      "Cheatsheet" -> :cheatsheet
    end
  end

  defp student_username_projection(student) do
    html = render_component(&CourseComponents.student_username/1, student: student)
    [username | rest] = find_html_elements(html, "span")

    %{username: html_element_text(username), suggested: first_text(rest)}
  end

  defp expected_properties_lines(properties) do
    html =
      render_component(&CourseComponents.expected_server_properties/1, properties: properties)

    html |> find_html_elements("li") |> Enum.map(&html_element_text/1)
  end

  defp first_text([]), do: nil
  defp first_text([element | _rest]), do: html_element_text(element)
end
