defmodule ArchiDep.Students.Schemas.StudentImportList do
  use ArchiDep, :schema

  alias ArchiDep.Students.Schemas.Class
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

  @spec changeset(list(Types.existing_student_data())) :: Ecto.Changeset.t(t())
  def changeset(students) do
    %__MODULE__{}
    |> change(%{students: students})
    |> cast_embed(:students, required: true, with: &student_changeset/2)
  end

  @spec student_changeset(__MODULE__.Student.t(), map) :: Ecto.Changeset.t(__MODULE__.Student.t())
  def student_changeset(student, params) do
    student
    |> cast(params, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/\A.+@.+\..+\z/)
  end

  @spec to_insert_data(t(), Class.t()) :: list(map())
  def to_insert_data(%__MODULE__{students: students}, %Class{id: class_id}),
    do:
      students
      |> Enum.map(&Map.from_struct/1)
      |> Enum.uniq_by(& &1.email)
      |> Enum.map(
        &(&1
          |> Map.merge(%{
            id: UUID.generate(),
            class_id: class_id,
            version: 1,
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }))
      )
end
