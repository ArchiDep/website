defmodule ArchiDep.Course.Material do
  @moduledoc """
  Provides access to the course material data, compiled by the Jekyll build
  process.
  """

  alias ArchiDep.Course.Helpers.MaterialHelpers

  @course_sections MaterialHelpers.course_sections()
  @run_virtual_server_exercise MaterialHelpers.course_document(402, "run-virtual-server")

  @spec course_sections() :: list(map())
  def course_sections, do: @course_sections

  @spec run_virtual_server_exercise() :: %{title: String.t(), url: String.t()}
  def run_virtual_server_exercise, do: @run_virtual_server_exercise
end
