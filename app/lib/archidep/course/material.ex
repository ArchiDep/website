defmodule ArchiDep.Course.Material do
  @moduledoc """
  Provides access to the course material data, compiled by the Jekyll build
  process.
  """

  @course_material_dir Path.expand("../../../priv/static", __DIR__)
  @course_material_file Path.join(@course_material_dir, "archidep.json")
  @course_material_file_contents File.read!(@course_material_file)
  @course_material_data JSON.decode!(@course_material_file_contents)
  @course_material_file_digest :crypto.hash(
                                 :sha256,
                                 @course_material_file_contents
                               )

  %{"sections" => [_section | _rest] = sections} = @course_material_data

  %{"title" => "Basic Deployment", "num" => 400, "docs" => docs} =
    Enum.find(sections, &match?(%{"num" => 400}, &1))

  %{
    "num" => 402,
    "title" => run_virtual_server_exercise_title,
    "url" => run_virtual_server_exercise_url = "/course/402-run-virtual-server/"
  } =
    Enum.find(docs, &match?(%{"num" => 402}, &1))

  @course_sections sections
  @run_virtual_server_exercise_title run_virtual_server_exercise_title
  @run_virtual_server_exercise_url run_virtual_server_exercise_url

  @spec course_sections() :: list(map())
  def course_sections, do: @course_sections

  @spec run_virtual_server_exercise() :: %{title: String.t(), url: String.t()}
  def run_virtual_server_exercise,
    do: %{title: @run_virtual_server_exercise_title, url: @run_virtual_server_exercise_url}

  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: @course_material_file_digest != course_material_file_digest()

  defp course_material_file_digest,
    do:
      :crypto.hash(
        :sha256,
        File.read!(@course_material_file)
      )
end
