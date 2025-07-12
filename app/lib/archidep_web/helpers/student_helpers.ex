defmodule ArchiDepWeb.Helpers.StudentHelpers do
  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User

  @spec student_not_in_class_tooltip(Student.t()) :: String.t() | nil

  def student_not_in_class_tooltip(%Student{
        id: student_id,
        user: %User{student: %Student{id: new_student_id, class: %Class{name: new_class_name}}}
      })
      when student_id != new_student_id,
      do: gettext("Student now in class {class}", class: new_class_name)

  def student_not_in_class_tooltip(%Student{user: %User{student_id: nil}}),
    do: gettext("Student no longer in this class")

  def student_not_in_class_tooltip(%Student{}), do: nil
end
