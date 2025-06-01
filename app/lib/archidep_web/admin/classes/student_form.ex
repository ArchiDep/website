defmodule ArchiDepWeb.Admin.Classes.StudentForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:email, :string, default: "")
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :email])
    |> validate_required([:name, :email])
  end

  @spec update_changeset(Student.t(), map) :: Changeset.t(t())
  def update_changeset(student, params \\ %{}) when is_map(params) do
    %__MODULE__{
      name: student.name,
      email: student.email
    }
    |> cast(params, [:name, :email])
    |> validate_required([:name, :email])
  end

  @spec to_create_student_data(t(), Class.t()) :: Types.create_student_data()
  def to_create_student_data(%__MODULE__{} = form, class) do
    %{
      name: form.name,
      email: form.email,
      class_id: class.id
    }
  end

  @spec to_existing_student_data(t()) :: Types.existing_student_data()
  def to_existing_student_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      email: form.email
    }
  end
end
