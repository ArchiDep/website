defmodule ArchiDepWeb.Helpers.StudentHelpers do
  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Schemas.User

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
