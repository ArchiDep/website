defmodule ArchiDep.Course.Context do
  @moduledoc false

  @behaviour ArchiDep.Course.Behaviour

  use ArchiDep, :context_impl

  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.UseCases

  # Classes
  implement(&Behaviour.validate_class/2, UseCases.CreateClass)
  implement(&Behaviour.create_class/2, UseCases.CreateClass)
  implement(&Behaviour.list_classes/1, UseCases.ReadClasses)
  implement(&Behaviour.list_active_classes/1, UseCases.ReadClasses)
  implement(&Behaviour.fetch_class/2, UseCases.ReadClasses)
  implement(&Behaviour.validate_existing_class/3, UseCases.UpdateClass)
  implement(&Behaviour.update_class/3, UseCases.UpdateClass)

  implement(
    &Behaviour.validate_expected_server_properties_for_class/3,
    UseCases.UpdateExpectedServerPropertiesForClass
  )

  implement(
    &Behaviour.update_expected_server_properties_for_class/3,
    UseCases.UpdateExpectedServerPropertiesForClass
  )

  implement(&Behaviour.delete_class/2, UseCases.DeleteClass)

  # Students
  implement(&Behaviour.validate_student/3, UseCases.CreateStudent)
  implement(&Behaviour.create_student/3, UseCases.CreateStudent)
  implement(&Behaviour.import_students/3, UseCases.ImportStudents)
  implement(&Behaviour.list_students/2, UseCases.ReadStudents)
  implement(&Behaviour.fetch_authenticated_student/1, UseCases.ReadStudents)
  implement(&Behaviour.fetch_student_in_class/3, UseCases.ReadStudents)
  implement(&Behaviour.validate_existing_student/3, UseCases.UpdateStudent)
  implement(&Behaviour.update_student/3, UseCases.UpdateStudent)
  implement(&Behaviour.validate_student_config/3, UseCases.ConfigureStudent)
  implement(&Behaviour.configure_student/3, UseCases.ConfigureStudent)
  implement(&Behaviour.delete_student/2, UseCases.DeleteStudent)
end
