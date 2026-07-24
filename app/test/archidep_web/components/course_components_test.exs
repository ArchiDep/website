defmodule ArchiDepWeb.Components.CourseComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
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
