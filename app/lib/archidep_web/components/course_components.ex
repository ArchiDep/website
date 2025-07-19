defmodule ArchiDepWeb.Components.CourseComponents do
  @moduledoc false

  use ArchiDepWeb, :component

  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student

  attr :student, Student,
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
