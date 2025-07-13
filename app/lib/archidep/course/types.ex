defmodule ArchiDep.Course.Types do
  alias Ecto.UUID

  @type class_data :: %{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean()
        }

  @type create_student_data :: %{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          suggested_username: String.t(),
          username: String.t() | nil,
          active: boolean(),
          class_id: UUID.t()
        }

  @type existing_student_data :: %{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          suggested_username: String.t(),
          username: String.t() | nil,
          active: boolean()
        }

  @type import_students_data :: %{
          academic_class: String.t() | nil,
          students: list(import_student_data())
        }

  @type import_student_data :: %{
          name: String.t(),
          email: String.t(),
          suggested_username: String.t()
        }
end
