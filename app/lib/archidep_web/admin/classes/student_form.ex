defmodule ArchiDepWeb.Admin.Classes.StudentForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:email, :string, default: "")
    field(:academic_class, :string, default: nil)
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :email, :academic_class])
    |> validate_required([:name, :email])
  end

  @spec update_changeset(Student.t(), map) :: Changeset.t(t())
  def update_changeset(student, params \\ %{}) when is_map(params) do
    %__MODULE__{
      name: student.name,
      email: student.email,
      academic_class: student.academic_class
    }
    |> cast(params, [:name, :email, :academic_class])
    |> validate_required([:name, :email])
  end

  @spec to_create_student_data(t(), Class.t()) :: Types.create_student_data()
  def to_create_student_data(%__MODULE__{} = form, class) do
    %{
      name: form.name,
      email: form.email,
      academic_class: form.academic_class,
      class_id: class.id
    }
  end

  @spec to_existing_student_data(t()) :: Types.existing_student_data()
  def to_existing_student_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      email: form.email,
      academic_class: form.academic_class
    }
  end
end
