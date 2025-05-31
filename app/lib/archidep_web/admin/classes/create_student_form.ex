defmodule ArchiDepWeb.Admin.Classes.CreateStudentForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Students.Types
  alias Ecto.Changeset
  alias Ecto.UUID

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t(),
          class_id: UUID.t()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:email, :string, default: "")
    field(:class_id, :binary_id)
  end

  @spec changeset(map) :: Changeset.t(t())
  def changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :email, :class_id])
    |> validate_required([:name, :email, :class_id])
  end

  @spec to_student_data(t()) :: Types.student_data()
  def to_student_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      email: form.email,
      class_id: form.class_id
    }
  end
end
