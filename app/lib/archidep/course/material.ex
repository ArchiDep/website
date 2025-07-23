defmodule ArchiDep.Course.Material do
  @course_material_dir Path.expand("../../../priv/static", __DIR__)
  @course_material_file Path.join(@course_material_dir, "archidep.json")
  @course_material_file_contents File.read!(@course_material_file)
  @course_material_data JSON.decode!(@course_material_file_contents)
  @course_material_file_digest :crypto.hash(
                                 :sha256,
                                 @course_material_file_contents
                               )

  %{"sections" => [_section | _rest] = sections} = @course_material_data
  @course_sections sections

  @spec course_sections() :: list(map())
  def course_sections, do: @course_sections

  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: @course_material_file_digest != course_material_file_digest()

  defp course_material_file_digest,
    do:
      :crypto.hash(
        :sha256,
        File.read!(@course_material_file)
      )
end
