defmodule ArchiDep.Course do
  @moduledoc """
  Course context to manage classes and students and all related configuration.
  """

  @behaviour ArchiDep.Course.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Course.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  delegate(&Behaviour.validate_class/2)
  delegate(&Behaviour.create_class/2)
  delegate(&Behaviour.list_classes/1)
  delegate(&Behaviour.fetch_class/2)
  delegate(&Behaviour.validate_existing_class/3)
  delegate(&Behaviour.update_class/3)
  delegate(&Behaviour.validate_expected_server_properties_for_class/3)
  delegate(&Behaviour.update_expected_server_properties_for_class/3)
  delegate(&Behaviour.delete_class/2)
  delegate(&Behaviour.validate_student/2)
  delegate(&Behaviour.create_student/2)
  delegate(&Behaviour.import_students/3)
  delegate(&Behaviour.list_students/2)
  delegate(&Behaviour.fetch_authenticated_student/1)
  delegate(&Behaviour.fetch_student_in_class/3)
  delegate(&Behaviour.validate_existing_student/3)
  delegate(&Behaviour.update_student/3)
  delegate(&Behaviour.validate_student_config/3)
  delegate(&Behaviour.configure_student/3)
  delegate(&Behaviour.delete_student/2)
end
