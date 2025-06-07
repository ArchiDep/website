defmodule ArchiDep.Students.Schemas.StudentImportList do
  use ArchiDep, :schema

  alias ArchiDep.Students.Types

  @type t :: %__MODULE__{
          students: list(Types.existing_student_data())
        }

  @primary_key false
  embedded_schema do
    embeds_many :students, Student, primary_key: false do
      field :name, :string
      field :email, :string
    end
  end

  @doc false
  def changeset(students) do
    %__MODULE__{}
    |> cast(%{students: students}, [:students])
    |> validate_required([:students])
  end
end
