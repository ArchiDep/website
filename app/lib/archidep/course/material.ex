defmodule ArchiDep.Course.Material do
  @moduledoc """
  Provides access to the course material data, compiled by the Jekyll build
  process.
  """

  alias ArchiDep.Course.Helpers.MaterialHelpers

  @course_cheatsheets MaterialHelpers.course_cheatsheets()
  @course_sections MaterialHelpers.course_sections()
  @run_virtual_server_exercise MaterialHelpers.course_document(402, "run-virtual-server")
  @sysadmin_cheatsheet MaterialHelpers.course_cheatsheet("sysadmin")

  @spec course_cheatsheets() :: list(map())
  def course_cheatsheets, do: @course_cheatsheets

  @spec course_sections() :: list(map())
  def course_sections, do: @course_sections

  @spec run_virtual_server_exercise() :: %{title: String.t(), url: String.t()}
  def run_virtual_server_exercise, do: @run_virtual_server_exercise

  @spec sysadmin_cheatsheet() :: %{title: String.t(), url: String.t()}
  def sysadmin_cheatsheet, do: @sysadmin_cheatsheet
end
