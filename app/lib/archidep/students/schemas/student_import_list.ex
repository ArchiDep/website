defmodule ArchiDep.Students.Schemas.StudentImportList do
  use ArchiDep, :schema

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @type t :: %__MODULE__{
          academic_class: String.t() | nil,
          students: list(Types.existing_student_data())
        }

  @primary_key false
  embedded_schema do
    field :academic_class, :string

    embeds_many :students, Student, primary_key: false do
      field :name, :string
      field :email, :string
    end
  end

  @spec changeset(Types.import_students_data()) :: Ecto.Changeset.t(t())
  def changeset(data) do
    %__MODULE__{}
    |> cast(data, [:academic_class])
    |> change(%{students: data.students})
    |> cast_embed(:students, required: true, with: &student_changeset/2)
  end

  @spec student_changeset(struct, map) :: Ecto.Changeset.t()
  def student_changeset(student, params) do
    student
    |> cast(params, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/\A.+@.+\..+\z/)
  end

  @spec to_insert_data(t(), Class.t(), DateTime.t()) :: list(map())
  def to_insert_data(
        %__MODULE__{academic_class: academic_class, students: students},
        %Class{
          id: class_id
        },
        now
      ),
      do:
        students
        |> Enum.map(&Map.from_struct/1)
        |> Enum.uniq_by(& &1.email)
        |> Enum.map(
          &(&1
            |> Map.merge(%{
              id: UUID.generate(),
              academic_class: academic_class,
              class_id: class_id,
              version: 1,
              created_at: now,
              updated_at: now
            }))
        )
end
