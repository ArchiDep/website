defmodule ArchiDepWeb.Admin.Classes.StudentForm do
  use Ecto.Schema

  import ArchiDep.Helpers.ChangesetHelpers, only: [validate_not_nil: 2]
  import Ecto.Changeset
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          suggested_username: String.t(),
          username: String.t() | nil,
          active: boolean()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:email, :string, default: "")
    field(:academic_class, :string)
    field(:suggested_username, :string, default: "")
    field(:username, :string)
    field(:active, :boolean, default: true)
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :email, :academic_class, :suggested_username, :username, :active])
    |> validate_not_nil([:name, :email, :suggested_username, :active])
  end

  @spec update_changeset(Student.t(), map) :: Changeset.t(t())
  def update_changeset(student, params \\ %{}) when is_map(params) do
    %__MODULE__{
      name: student.name,
      email: student.email,
      academic_class: student.academic_class,
      suggested_username: student.suggested_username,
      username: student.username,
      active: student.active
    }
    |> cast(params, [:name, :email, :academic_class, :suggested_username, :username, :active])
    |> validate_required([:name, :email, :suggested_username, :active])
  end

  @spec to_create_student_data(t(), Class.t()) :: Types.create_student_data()
  def to_create_student_data(%__MODULE__{} = form, class) do
    %{
      name: form.name,
      email: form.email,
      academic_class: form.academic_class,
      suggested_username: form.suggested_username,
      username: form.username,
      active: form.active,
      class_id: class.id
    }
  end

  @spec to_existing_student_data(t()) :: Types.existing_student_data()
  def to_existing_student_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      email: form.email,
      academic_class: form.academic_class,
      suggested_username: form.suggested_username,
      username: form.username,
      active: form.active
    }
  end
end
