defmodule ArchiDep.Course.Context do
  @moduledoc false

  @behaviour ArchiDep.Course.Behaviour

  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.UseCases

  # Classes

  @doc false
  @impl Behaviour
  defdelegate validate_class(auth, data), to: UseCases.CreateClass

  @doc false
  @impl Behaviour
  defdelegate create_class(auth, data), to: UseCases.CreateClass

  @doc false
  @impl Behaviour
  defdelegate list_classes(auth), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate list_active_classes(auth), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate subscribe_classes(), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate refresh_classes(classes, message), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate fetch_class(auth, class_id), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate subscribe_class(class), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate refresh_class(class, message), to: UseCases.ReadClasses

  @doc false
  @impl Behaviour
  defdelegate validate_existing_class(auth, class_id, data), to: UseCases.UpdateClass

  @doc false
  @impl Behaviour
  defdelegate update_class(auth, class_id, data), to: UseCases.UpdateClass

  @doc false
  @impl Behaviour
  defdelegate validate_expected_server_properties_for_class(auth, class_id, data),
    to: UseCases.UpdateExpectedServerPropertiesForClass

  @doc false
  @impl Behaviour
  defdelegate update_expected_server_properties_for_class(auth, class_id, data),
    to: UseCases.UpdateExpectedServerPropertiesForClass

  @doc false
  @impl Behaviour
  defdelegate delete_class(auth, class_id), to: UseCases.DeleteClass

  # Students

  @doc false
  @impl Behaviour
  defdelegate validate_student(auth, class_id, data), to: UseCases.CreateStudent

  @doc false
  @impl Behaviour
  defdelegate create_student(auth, class_id, data), to: UseCases.CreateStudent

  @doc false
  @impl Behaviour
  defdelegate import_students(auth, class_id, data), to: UseCases.ImportStudents

  @doc false
  @impl Behaviour
  defdelegate list_students(auth, class), to: UseCases.ReadStudents

  @doc false
  @impl Behaviour
  defdelegate subscribe_class_students(class), to: UseCases.ReadStudents

  @doc false
  @impl Behaviour
  defdelegate refresh_class_students(auth, class, students, message), to: UseCases.ReadStudents

  @doc false
  @impl Behaviour
  defdelegate fetch_authenticated_student(auth), to: UseCases.ReadStudents

  @doc false
  @impl Behaviour
  defdelegate fetch_student_in_class(auth, class_id, student_id), to: UseCases.ReadStudents

  @doc false
  @impl Behaviour
  defdelegate validate_existing_student(auth, student_id, data), to: UseCases.UpdateStudent

  @doc false
  @impl Behaviour
  defdelegate update_student(auth, student_id, data), to: UseCases.UpdateStudent

  @doc false
  @impl Behaviour
  defdelegate validate_student_config(auth, student_id, data), to: UseCases.ConfigureStudent

  @doc false
  @impl Behaviour
  defdelegate configure_student(auth, student_id, data), to: UseCases.ConfigureStudent

  @doc false
  @impl Behaviour
  defdelegate delete_student(auth, student_id), to: UseCases.DeleteStudent

  @doc false
  @impl Behaviour
  defdelegate subscribe_student(student), to: UseCases.ReadStudents

  @doc false
  @impl Behaviour
  defdelegate refresh_student(student, message), to: UseCases.ReadStudents
end
