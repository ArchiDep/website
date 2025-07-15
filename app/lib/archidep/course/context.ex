defmodule ArchiDep.Course.Context do
  use ArchiDep, :context

  @behaviour ArchiDep.Course.Behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [implement: 2]
  alias ArchiDep.Course.Behaviour

  implement(&Behaviour.validate_class/2, ArchiDep.Course.CreateClass)
  implement(&Behaviour.create_class/2, ArchiDep.Course.CreateClass)
  implement(&Behaviour.list_classes/1, ArchiDep.Course.ReadClasses)
  implement(&Behaviour.fetch_class/2, ArchiDep.Course.ReadClasses)
  implement(&Behaviour.validate_existing_class/3, ArchiDep.Course.UpdateClass)
  implement(&Behaviour.update_class/3, ArchiDep.Course.UpdateClass)
  implement(&Behaviour.delete_class/2, ArchiDep.Course.DeleteClass)
  implement(&Behaviour.validate_student/2, ArchiDep.Course.CreateStudent)
  implement(&Behaviour.create_student/2, ArchiDep.Course.CreateStudent)
  implement(&Behaviour.import_students/3, ArchiDep.Course.ImportStudents)
  implement(&Behaviour.list_students/2, ArchiDep.Course.ReadStudents)
  implement(&Behaviour.fetch_authenticated_student/1, ArchiDep.Course.ReadStudents)
  implement(&Behaviour.fetch_student_in_class/3, ArchiDep.Course.ReadStudents)
  implement(&Behaviour.validate_existing_student/3, ArchiDep.Course.UpdateStudent)
  implement(&Behaviour.update_student/3, ArchiDep.Course.UpdateStudent)
  implement(&Behaviour.validate_student_config/3, ArchiDep.Course.ConfigureStudent)
  implement(&Behaviour.configure_student/3, ArchiDep.Course.ConfigureStudent)
  implement(&Behaviour.delete_student/2, ArchiDep.Course.DeleteStudent)
end
