defmodule ArchiDepWeb.Components.CourseComponents do
  @moduledoc false

  use ArchiDepWeb, :component

  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.StudentView
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section

  attr :structure, Structure,
    required: true,
    doc: "the course to list, in reading order"

  attr :progress, :map,
    required: true,
    doc:
      "what has become of the course, by section and chapter number, as ArchiDep.CourseSite.Progress.statuses/2 gives it"

  @doc """
  The navigation of the course material: every section of the course, the
  chapters under it and the cheatsheets after them.

  A section folds through a checkbox its own label toggles, which is why each
  one is numbered — the entries under a section are shown by the `peer` of its
  index rather than by anything the server decides.
  """
  @spec course_material_menu(map()) :: Rendered.t()
  def course_material_menu(assigns) do
    ~H"""
    <ul id="course-material-menu" class="w-full menu px-4 pt-0 pb-4">
      <%= for {section, i} <- Enum.with_index(@structure.sections) do %>
        <li class={[
          "peer/section-#{i}",
          "group/section-#{i}",
          "course-section-#{@progress[Section.num(section)]}"
        ]}>
          <label
            for={"section-#{Section.slug(section)}-toggle"}
            class="flex justify-between items-center"
          >
            <span class="text-base-content/50 cursor-default">
              {section.title}
            </span>
            <%= if not Progress.section_open?(@progress, section) do %>
              <span class={"group-has-checked/section-#{i}:hidden"}>
                <Heroicons.chevron_down class="size-4 text-base-content/50" />
              </span>
              <span class={"hidden group-has-checked/section-#{i}:inline"}>
                <Heroicons.chevron_up class="size-4 text-base-content/50" />
              </span>
            <% end %>
            <input
              type="checkbox"
              id={"section-#{Section.slug(section)}-toggle"}
              class="hidden"
              checked={Progress.section_open?(@progress, section)}
              disabled={Progress.section_open?(@progress, section)}
            />
          </label>
        </li>
        <%= for chapter <- section.chapters do %>
          <li class={[
            "group",
            "hidden peer-has-checked/section-#{i}:flex",
            "course-item-#{@progress[Chapter.num(chapter)]}"
          ]}>
            <.link
              href={course_url(chapter)}
              target={if chapter.page.type == :slides, do: "_blank", else: "_self"}
              class="flex items-center gap-2"
            >
              <span class="flex items-center gap-x-2">
                <span class="size-4">
                  <%= case chapter.page.type do %>
                    <% :slides -> %>
                      <.emoji name="clapper" alt="Slides" class="size-4" />
                    <% :exercise -> %>
                      <%= if chapter.graded? do %>
                        <.emoji name="trophy" alt="Graded exercise" class="size-4" />
                      <% else %>
                        <.emoji name="hammer_and_wrench" alt="Exercise" class="size-4" />
                      <% end %>
                    <% :subject -> %>
                      <.emoji name="book" alt="Subject" class="size-4" />
                  <% end %>
                </span>
                <span>
                  {chapter.title}
                </span>
              </span>
              <span :if={Chapter.slides?(chapter)}>
                <.emoji name="clapper" alt="Slides" class="size-4" />
              </span>
              <Heroicons.arrow_top_right_on_square
                :if={chapter.page.type == :slides}
                class="size-4 text-base-content/25 group-hover:text-base-content/75"
              />
            </.link>
          </li>
        <% end %>
      <% end %>
      <li>
        <span class="text-base-content/50 cursor-default">
          Cheatsheets
        </span>
      </li>
      <li :for={cheatsheet <- @structure.cheatsheets}>
        <a href={course_url(cheatsheet)} class="flex items-center gap-2">
          <span class="flex items-center gap-x-2">
            <span class="size-4">
              <.emoji name="memo" alt="Cheatsheet" class="size-4" />
            </span>
            <span>
              {Cheatsheet.sidebar_title(cheatsheet)}
            </span>
          </span>
        </a>
      </li>
    </ul>
    """
  end

  attr :student, StudentView,
    required: true,
    doc: "the student whose username to display"

  @spec student_username(map()) :: Rendered.t()
  def student_username(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center gap-x-2">
      <span class="font-mono">
        {@student.username}
      </span>
      <span :if={not @student.username_confirmed} class="text-xs italic text-base-content/50">
        ({gettext("suggested")})
      </span>
    </div>
    """
  end

  attr :properties, ExpectedServerProperties,
    required: true,
    doc: "the expected server properties to display"

  @spec expected_server_properties(map()) :: Rendered.t()
  def expected_server_properties(assigns) do
    properties = assigns.properties

    assigns =
      assigns
      |> assign(:expected_cpu, expected_cpu(properties))
      |> assign(:expected_memory, expected_memory(properties))
      |> assign(:expected_os, expected_os(properties))
      |> assign(:expected_distribution, expected_distribution(properties))

    ~H"""
    <ul>
      <li
        :if={
          @expected_cpu == "" and @expected_memory == "" and @expected_os == "" and
            @expected_distribution == ""
        }
        class="italic text-base-content/50"
      >
        {gettext("No restrictions placed on any property")}
      </li>
      <li :if={@expected_cpu != ""}>
        {@expected_cpu}
      </li>
      <li :if={@expected_memory != ""}>
        {@expected_memory}
      </li>
      <li :if={@expected_os != ""}>
        {@expected_os}
      </li>
      <li :if={@expected_distribution != ""}>
        {@expected_distribution}
      </li>
    </ul>
    """
  end

  defp expected_cpu(properties) do
    [
      if(properties.cpus != nil,
        do:
          gettext("{count} {count, plural, =1 {CPU} other {CPUs}}",
            count: properties.cpus
          ),
        else: nil
      ),
      if(properties.cores != nil,
        do:
          gettext("{count} {count, plural, =1 {core} other {cores}}",
            count: properties.cores
          ),
        else: nil
      ),
      if(properties.vcpus != nil,
        do:
          gettext("{count} {count, plural, =1 {vCPU} other {vCPUs}}",
            count: properties.vcpus
          ),
        else: nil
      )
    ]
    |> Enum.reject(&Kernel.is_nil/1)
    |> Enum.join(", ")
  end

  defp expected_memory(properties) do
    [
      {gettext("RAM"), properties.memory},
      {gettext("Swap"), properties.swap}
    ]
    |> Enum.filter(fn {_text, value} -> value != nil end)
    |> Enum.map_join(", ", fn {label, value} -> "#{value} MB #{label}" end)
  end

  defp expected_os(properties) do
    system_and_arch =
      [
        properties.system,
        properties.architecture
      ]
      |> Enum.filter(&(&1 != nil))
      |> Enum.join(" ")

    os_family =
      case properties.os_family do
        nil -> nil
        os_family -> gettext("{os_family} family", os_family: os_family)
      end

    [system_and_arch, os_family]
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.join(", ")
  end

  defp expected_distribution(properties) do
    [
      properties.distribution,
      properties.distribution_version,
      properties.distribution_release
    ]
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(" ")
  end
end
