defmodule ArchiDep.Students.Types do
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
          class_id: UUID.t()
        }
end
