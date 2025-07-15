defmodule ArchiDep.Course do
  @moduledoc """
  Course context, which manages classes and students.
  """

  use ArchiDep, :context

  @behaviour ArchiDep.Course.Behaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  alias ArchiDep.Course.Behaviour

  delegate(&Behaviour.validate_class/2)
  delegate(&Behaviour.create_class/2)
  delegate(&Behaviour.list_classes/1)
  delegate(&Behaviour.fetch_class/2)
  delegate(&Behaviour.validate_existing_class/3)
  delegate(&Behaviour.update_class/3)
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
