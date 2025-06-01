defmodule ArchiDepWeb.Admin.Classes.ClassForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean, default: true)
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :start_date, :end_date, :active])
    |> validate_required([:name, :active])
  end

  @spec update_changeset(Class.t(), map) :: Changeset.t(t())
  def update_changeset(class, params \\ %{}) when is_struct(class, Class) and is_map(params) do
    %__MODULE__{
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active
    }
    |> cast(params, [:name, :start_date, :end_date, :active])
    |> validate_required([:name, :active])
  end

  @spec to_class_data(t()) :: Types.class_data()
  def to_class_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      start_date: form.start_date,
      end_date: form.end_date,
      active: form.active
    }
  end
end
